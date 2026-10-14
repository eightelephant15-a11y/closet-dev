"""Worker entrypoint: ``python -m app.worker`` (``make worker-local`` for the local stack).

Consumes the arq queue and runs the closet jobs (image processing, garment analysis). Scale it by
running more copies; jobs are idempotent so redelivery is safe.
"""

import logging
import os
from typing import Any

from arq import run_worker
from arq.connections import RedisSettings

import app.services.closet_jobs  # noqa: F401  (registers the handlers)
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.queue.arq_queue import arq_functions
from app.queue.deps import build_deps


async def startup(ctx: dict[str, Any]) -> None:
    ctx["deps"] = build_deps()
    logging.getLogger("app.worker").info("worker_started")


async def shutdown(ctx: dict[str, Any]) -> None:
    logging.getLogger("app.worker").info("worker_stopped")


class WorkerSettings:
    functions = arq_functions()
    on_startup = startup
    on_shutdown = shutdown
    redis_settings = RedisSettings.from_dsn(get_settings().redis_url)
    max_jobs = int(os.environ.get("WORKER_CONCURRENCY", "4"))
    job_timeout = 180
    keep_result = 3600
    health_check_interval = 30
    poll_delay = 0.5


def main() -> None:
    configure_logging(get_settings().app_env)
    if os.environ.get("FAKE_REDIS") == "1":
        # fakeredis' TCP server does not implement INFO, which arq logs at start-up.
        import arq.worker as arq_worker

        async def _skip(*_: Any, **__: Any) -> None:
            return None

        arq_worker.log_redis_info = _skip  # type: ignore[attr-defined]
    run_worker(WorkerSettings)  # type: ignore[arg-type]


if __name__ == "__main__":
    main()
