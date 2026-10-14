"""Job runner shared by every queue implementation: retries with backoff, dead-lettering, idempotency.

Handlers are plain ``async def handler(deps, *args)`` functions registered with ``@job("name")``.
They must be **idempotent** (check state first): the queue may deliver a job twice.

* Raise ``RetryJob`` for transient trouble (storage hiccup, provider 5xx): retried with exponential
  backoff up to ``max_tries``, then dead-lettered.
* Raise anything else (or let it escape) for a permanent failure: dead-lettered immediately.
* Dead-lettering runs the job's ``on_dead`` hook (so the database shows "needs manual entry") and pushes
  a record on the Redis list ``dlq:closet`` for inspection.
"""

import json
import logging
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from typing import Any, Protocol

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.services.background import BackgroundRemover
from app.services.storage import ObjectStorage

log = logging.getLogger("app.jobs")
DLQ_KEY = "dlq:closet"


class RetryJob(Exception):
    def __init__(self, reason: str = "", defer: float | None = None) -> None:
        super().__init__(reason)
        self.reason = reason
        self.defer = defer


class JobQueue(Protocol):
    async def enqueue(
        self, name: str, *args: Any, job_id: str | None = None, defer_by: float = 0
    ) -> bool:
        """Queues a job. Returns False if a job with the same ``job_id`` already exists."""
        ...


@dataclass
class JobDeps:
    maker: async_sessionmaker[AsyncSession]
    storage: ObjectStorage
    queue: JobQueue
    redis: Callable[[], Redis]
    settings: Settings
    remover: BackgroundRemover
    # name -> provider, resolved per job so the `vision_provider` flag works without a restart
    vision: Callable[[str], Any]
    extras: dict[str, Any] = field(default_factory=dict)


Handler = Callable[..., Awaitable[None]]
OnDead = Callable[[JobDeps, tuple[Any, ...], str], Awaitable[None]]


@dataclass(frozen=True)
class JobSpec:
    name: str
    fn: Handler
    on_dead: OnDead | None = None


JOBS: dict[str, JobSpec] = {}


def job(name: str, on_dead: OnDead | None = None) -> Callable[[Handler], Handler]:
    def register(fn: Handler) -> Handler:
        JOBS[name] = JobSpec(name, fn, on_dead)
        return fn

    return register


def backoff_seconds(try_number: int) -> float:
    """5s, 10s, 20s, ... capped at 5 minutes."""
    return float(min(5 * 2 ** (try_number - 1), 300))


@dataclass(frozen=True)
class Outcome:
    kind: str  # "ok" | "retry" | "dead"
    defer: float = 0.0
    error: str = ""


async def execute(
    name: str, args: tuple[Any, ...], deps: JobDeps, *, try_number: int, max_tries: int
) -> Outcome:
    spec = JOBS[name]
    started = time.monotonic()
    try:
        await spec.fn(deps, *args)
    except RetryJob as exc:
        if try_number < max_tries:
            delay = exc.defer if exc.defer is not None else backoff_seconds(try_number)
            log.warning(
                "job_retry name=%s try=%d/%d in=%.0fs reason=%s",
                name,
                try_number,
                max_tries,
                delay,
                exc.reason,
            )
            return Outcome("retry", delay, exc.reason)
        error = f"retries exhausted: {exc.reason}"
    except Exception as exc:
        log.exception("job_failed name=%s try=%d", name, try_number)
        error = f"{type(exc).__name__}: {exc}"[:300]
    else:
        log.info(
            "job_ok name=%s try=%d ms=%d", name, try_number, (time.monotonic() - started) * 1000
        )
        return Outcome("ok")
    await _dead_letter(spec, args, deps, error)
    return Outcome("dead", error=error)


async def _dead_letter(spec: JobSpec, args: tuple[Any, ...], deps: JobDeps, error: str) -> None:
    log.error("job_dead name=%s args=%s error=%s", spec.name, args, error)
    if spec.on_dead:
        try:
            await spec.on_dead(deps, args, error)
        except Exception:
            log.exception("on_dead hook failed name=%s", spec.name)
    try:
        await deps.redis().rpush(  # type: ignore[misc]
            DLQ_KEY,
            json.dumps(
                {
                    "job": spec.name,
                    "args": [str(a) for a in args],
                    "error": error,
                    "at": time.time(),
                }
            ),
        )
    except Exception:
        log.exception("could not write to the dead-letter list")
