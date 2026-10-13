"""Run the real API on a laptop: ``python -m app.local_server`` (or ``make api-local``).

* SQLite by default (``DATABASE_URL`` to use a local Postgres instead), migrations applied on start.
* An in-process fake Redis unless ``REDIS_URL`` is set.
* ``AUTH_MODE=dev``: no Firebase. Mint tokens with ``POST /dev/token`` (the Flutter app does this).
* Feature flags are seeded into the ``feature_flags`` table so they can be edited with SQL.
Never use this in a deployed environment: the settings validator refuses AUTH_MODE=dev there.
"""

import asyncio
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def prepare_environment() -> None:
    os.environ.setdefault("APP_ENV", "dev")
    # Default is dev auth. `AUTH_MODE=firebase make api-local` runs the same local stack against
    # real Firebase (needs GOOGLE_APPLICATION_CREDENTIALS or the Auth emulator) for go-live tests.
    os.environ.setdefault("AUTH_MODE", "dev")
    os.environ.setdefault("DEV_AUTH_SECRET", "local-dev-secret-not-for-production")
    os.environ.setdefault("DATABASE_URL", f"sqlite+aiosqlite:///{ROOT / 'local.db'}")
    os.environ.setdefault("EXPORT_DIR", str(ROOT / ".exports"))


def migrate(database_url: str) -> None:
    from alembic.config import Config

    from alembic import command

    os.environ["ALEMBIC_DATABASE_URL"] = database_url
    cfg = Config(str(ROOT / "alembic.ini"))
    cfg.set_main_option("script_location", str(ROOT / "alembic"))
    command.upgrade(cfg, "head")


async def seed_flags(database_url: str) -> list[str]:
    from sqlalchemy import select
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

    from app.models import FeatureFlag
    from app.services.flags import FLAG_DEFAULTS

    engine = create_async_engine(database_url)
    created: list[str] = []
    async with async_sessionmaker(engine)() as session:
        existing = set((await session.execute(select(FeatureFlag.key))).scalars())
        for key, value in FLAG_DEFAULTS.items():
            if key not in existing:
                session.add(FeatureFlag(key=key, value=value))
                created.append(key)
        await session.commit()
    await engine.dispose()
    return created


def main() -> int:
    prepare_environment()
    from app.core.config import get_settings

    settings = get_settings()  # raises if AUTH_MODE=dev is not allowed here
    migrate(settings.database_url)
    seeded = asyncio.run(seed_flags(settings.database_url))

    if "REDIS_URL" not in os.environ:
        import fakeredis

        from app.core.redis import set_redis

        set_redis(fakeredis.FakeAsyncRedis(decode_responses=True))
        redis_note = "in-process fake Redis"
    else:
        redis_note = settings.redis_url

    auth_note = (
        " (mint tokens: POST /dev/token)"
        if settings.auth_mode == "dev"
        else " (real Firebase tokens)"
    )
    host, port = os.environ.get("HOST", "127.0.0.1"), int(os.environ.get("PORT", "8000"))
    print(
        f"\nLocal API on http://{host}:{port}  (docs: /docs)\n"
        f"  database : {settings.database_url}\n  redis    : {redis_note}\n"
        f"  auth     : AUTH_MODE={settings.auth_mode}"
        f"{auth_note}\n"
        f"  flags    : seeded {seeded or 'nothing new'}\n"
        f"  smoke    : python -m app.smoke http://{host}:{port}\n",
        file=sys.stderr,
    )
    import uvicorn

    uvicorn.run("app.main:app", host=host, port=port, log_level="info")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
