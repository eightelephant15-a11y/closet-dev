"""Scheduled jobs (run by an ECS scheduled task): ``python -m app.jobs purge|exports``."""

import asyncio
import sys

import structlog

from app.core.auth import get_verifier
from app.core.config import get_settings
from app.core.db import get_sessionmaker
from app.core.logging import configure_logging
from app.services import privacy
from app.services.storage import get_storage

log = structlog.get_logger()


async def run(command: str) -> int:
    maker = get_sessionmaker()
    async with maker() as session:
        if command == "purge":
            n = await privacy.purge_due_users(session, get_storage(), get_verifier())
            log.info("purge_done", purged=n)
            return 0
        if command == "exports":
            n = await privacy.run_pending_exports(session, get_storage())
            log.info("exports_done", processed=n)
            return 0
    log.error("unknown_command", command=command)
    return 2


if __name__ == "__main__":
    configure_logging(get_settings().app_env)
    sys.exit(asyncio.run(run(sys.argv[1] if len(sys.argv) > 1 else "")))
