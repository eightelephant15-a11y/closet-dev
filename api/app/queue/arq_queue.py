"""arq (Redis) queue: the real thing. Producer side lives in the API, consumer side in ``app.worker``."""

import logging
from typing import Any

from arq import Retry, create_pool
from arq.connections import ArqRedis, RedisSettings
from arq.worker import func

from app.queue.core import JOBS, JobDeps, execute

log = logging.getLogger("app.queue")


class ArqJobQueue:
    def __init__(self, redis_dsn: str) -> None:
        self._settings = RedisSettings.from_dsn(redis_dsn)
        self._pool: ArqRedis | None = None

    async def _get_pool(self) -> ArqRedis:
        if self._pool is None:
            self._pool = await create_pool(self._settings)
        return self._pool

    async def enqueue(
        self, name: str, *args: Any, job_id: str | None = None, defer_by: float = 0
    ) -> bool:
        pool = await self._get_pool()
        queued = await pool.enqueue_job(name, *args, _job_id=job_id, _defer_by=defer_by or None)
        return queued is not None

    async def close(self) -> None:
        if self._pool is not None:
            await self._pool.aclose()


def arq_functions() -> list[Any]:
    """One arq function per registered job; translates our Outcome into arq's retry model."""
    funcs = []
    for name in JOBS:

        async def entry(ctx: dict[str, Any], *args: Any, _name: str = name) -> str:
            deps: JobDeps = ctx["deps"]
            max_tries = deps.settings.queue_max_tries
            outcome = await execute(
                _name, args, deps, try_number=ctx["job_try"], max_tries=max_tries
            )
            if outcome.kind == "retry":
                raise Retry(defer=outcome.defer)
            return (
                outcome.kind
            )  # "ok" | "dead": a dead job is *finished* as far as arq is concerned

        funcs.append(func(entry, name=name, max_tries=deps_max_tries() + 1))
    return funcs


def deps_max_tries() -> int:
    from app.core.config import get_settings

    return get_settings().queue_max_tries
