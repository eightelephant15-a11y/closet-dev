"""Queue semantics: retries with backoff, dead-lettering, idempotency; and the real arq path.

The arq tests talk to Redis over the wire. Locally that is fakeredis' TCP server (no Redis install
needed); CI sets REDIS_TEST_URL to a real Redis service to run the same tests against it.
"""

import asyncio
import os
import socket
import threading
from collections.abc import AsyncIterator, Iterator
from typing import Any

import fakeredis
import pytest
from arq.connections import RedisSettings
from arq.worker import Worker
from fakeredis import TcpFakeServer
from redis.asyncio import Redis

import app.queue.core as qcore
from app.core.config import get_settings
from app.queue.arq_queue import ArqJobQueue, arq_functions
from app.queue.core import DLQ_KEY, JOBS, JobDeps, RetryJob, backoff_seconds, execute, job
from app.queue.eager import EagerQueue
from app.services.background import PassThroughRemover

CALLS: list[tuple[str, int]] = []
DEAD: list[tuple[tuple[Any, ...], str]] = []


@pytest.fixture(autouse=True)
def _clean_registry() -> Iterator[None]:
    before = dict(JOBS)
    CALLS.clear()
    DEAD.clear()
    yield
    JOBS.clear()
    JOBS.update(before)


async def _on_dead(deps: JobDeps, args: tuple[Any, ...], error: str) -> None:
    DEAD.append((args, error))


def register_jobs() -> None:
    @job("t_ok")
    async def t_ok(deps: JobDeps, x: str) -> None:
        CALLS.append(("t_ok", 1))

    @job("t_flaky", on_dead=_on_dead)
    async def t_flaky(deps: JobDeps, fail_times: int, tag: str) -> None:
        n = sum(1 for name, _ in CALLS if name == f"t_flaky:{tag}") + 1
        CALLS.append((f"t_flaky:{tag}", n))
        if n <= fail_times:
            raise RetryJob(f"transient #{n}", defer=0.05)

    @job("t_boom", on_dead=_on_dead)
    async def t_boom(deps: JobDeps) -> None:
        CALLS.append(("t_boom", 1))
        raise ValueError("bad input")


def make_deps(redis: Redis, queue: Any = None) -> JobDeps:
    return JobDeps(
        maker=None,  # type: ignore[arg-type]
        storage=None,  # type: ignore[arg-type]
        queue=queue or EagerQueue(),
        redis=lambda: redis,
        settings=get_settings(),
        remover=PassThroughRemover(),
        vision=lambda name: None,
    )


@pytest.fixture
def fake_redis() -> Redis:
    return fakeredis.FakeAsyncRedis(decode_responses=True)


def test_backoff_grows_exponentially_and_is_capped() -> None:
    assert [backoff_seconds(n) for n in (1, 2, 3, 4)] == [5, 10, 20, 40]
    assert backoff_seconds(30) == 300


async def test_retry_then_success(fake_redis: Redis) -> None:
    register_jobs()
    deps = make_deps(fake_redis)
    first = await execute("t_flaky", (1, "a"), deps, try_number=1, max_tries=3)
    assert (first.kind, first.defer) == ("retry", 0.05)
    second = await execute("t_flaky", (1, "a"), deps, try_number=2, max_tries=3)
    assert second.kind == "ok" and not DEAD


async def test_exhausted_retries_are_dead_lettered_with_the_hook_and_a_redis_record(
    fake_redis: Redis,
) -> None:
    register_jobs()
    deps = make_deps(fake_redis)
    out = None
    for attempt in (1, 2, 3):
        out = await execute("t_flaky", (99, "b"), deps, try_number=attempt, max_tries=3)
    assert out is not None and out.kind == "dead"
    assert DEAD and "retries exhausted" in DEAD[0][1]
    records = await fake_redis.lrange(DLQ_KEY, 0, -1)
    assert len(records) == 1 and "t_flaky" in records[0]


async def test_permanent_errors_skip_retries(fake_redis: Redis) -> None:
    register_jobs()
    out = await execute("t_boom", (), make_deps(fake_redis), try_number=1, max_tries=3)
    assert out.kind == "dead" and "ValueError: bad input" in out.error
    assert CALLS == [("t_boom", 1)]
    assert len(await fake_redis.lrange(DLQ_KEY, 0, -1)) == 1


async def test_a_failing_dead_hook_never_loses_the_dead_letter_record(fake_redis: Redis) -> None:
    @job("t_hook_breaks", on_dead=lambda *_: (_ for _ in ()).throw(RuntimeError("hook")))  # type: ignore[arg-type,return-value]
    async def t_hook_breaks(deps: JobDeps) -> None:
        raise ValueError("x")

    async def broken_hook(deps: JobDeps, args: tuple[Any, ...], error: str) -> None:
        raise RuntimeError("hook failed")

    JOBS["t_hook_breaks"] = qcore.JobSpec("t_hook_breaks", t_hook_breaks, broken_hook)
    out = await execute("t_hook_breaks", (), make_deps(fake_redis), try_number=1, max_tries=1)
    assert out.kind == "dead"
    assert len(await fake_redis.lrange(DLQ_KEY, 0, -1)) == 1


async def test_eager_queue_dedupes_by_job_id_and_runs_retries(fake_redis: Redis) -> None:
    register_jobs()
    q = EagerQueue()
    q.deps = make_deps(fake_redis, q)
    assert await q.enqueue("t_flaky", 1, "c", job_id="same") is True
    assert await q.enqueue("t_flaky", 1, "c", job_id="same") is False
    assert [n for n, _ in CALLS] == ["t_flaky:c", "t_flaky:c"]  # failed once, retried once
    assert q.log == [("t_flaky", (1, "c"), "ok")]


# ---- real arq against a Redis server over TCP --------------------------------------------------


@pytest.fixture
async def redis_dsn() -> AsyncIterator[str]:
    real = os.environ.get("REDIS_TEST_URL")
    if real:
        r = Redis.from_url(real)
        await r.flushdb()
        await r.aclose()
        yield real
        return
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    server = TcpFakeServer(("127.0.0.1", port), server_type="redis")
    threading.Thread(target=server.serve_forever, daemon=True).start()
    await asyncio.sleep(0.2)
    yield f"redis://127.0.0.1:{port}/0"
    server.shutdown()
    server.server_close()


def run_worker(dsn: str, deps: JobDeps) -> Worker:
    import arq.worker as aw

    async def skip(*_: Any, **__: Any) -> None:  # fakeredis' TCP server has no INFO
        return None

    aw.log_redis_info = skip  # type: ignore[attr-defined]
    return Worker(
        functions=arq_functions(),
        redis_settings=RedisSettings.from_dsn(dsn),
        ctx={"deps": deps},
        burst=True,
        poll_delay=0.05,
        handle_signals=False,
        max_tries=5,
    )


async def test_arq_queue_dedupes_job_ids_and_runs_jobs(redis_dsn: str, fake_redis: Redis) -> None:
    register_jobs()
    queue = ArqJobQueue(redis_dsn)
    assert await queue.enqueue("t_ok", "x", job_id="job-1") is True
    assert await queue.enqueue("t_ok", "x", job_id="job-1") is False  # idempotent enqueue
    worker = run_worker(redis_dsn, make_deps(fake_redis, queue))
    await asyncio.wait_for(worker.async_run(), 20)
    await worker.close()
    await queue.close()
    assert CALLS == [("t_ok", 1)]


async def test_arq_retries_with_deferral_then_succeeds(redis_dsn: str, fake_redis: Redis) -> None:
    register_jobs()
    queue = ArqJobQueue(redis_dsn)
    await queue.enqueue("t_flaky", 2, "arq", job_id="job-flaky")
    worker = run_worker(redis_dsn, make_deps(fake_redis, queue))
    await asyncio.wait_for(worker.async_run(), 30)
    await worker.close()
    await queue.close()
    assert [n for name, n in CALLS if name == "t_flaky:arq"] == [1, 2, 3]
    assert not DEAD


async def test_arq_dead_jobs_finish_without_arq_retrying_them_forever(
    redis_dsn: str, fake_redis: Redis
) -> None:
    register_jobs()
    queue = ArqJobQueue(redis_dsn)
    await queue.enqueue("t_boom", job_id="job-boom")
    worker = run_worker(redis_dsn, make_deps(fake_redis, queue))
    await asyncio.wait_for(worker.async_run(), 20)
    await worker.close()
    await queue.close()
    assert CALLS == [("t_boom", 1)]  # exactly one attempt: permanent errors are not retried
    assert len(DEAD) == 1 and "bad input" in DEAD[0][1]
