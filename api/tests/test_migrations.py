"""Migrations apply, match the models (no drift), and roll back.

Runs on SQLite by default; set MIGRATION_TEST_DATABASE_URL to run against Postgres (CI does).
"""

import os
from pathlib import Path

import pytest
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from sqlalchemy import create_engine, inspect

import app.models  # noqa: F401
from alembic import command
from app.core.db import Base

ROOT = Path(__file__).resolve().parents[1]


def _async_url(tmp_path: Path) -> str:
    return os.environ.get("MIGRATION_TEST_DATABASE_URL") or f"sqlite+aiosqlite:///{tmp_path}/m.db"


def _sync_url(url: str) -> str:
    return url.replace("+aiosqlite", "").replace("+asyncpg", "+psycopg2")


@pytest.fixture
def cfg(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Config:
    monkeypatch.setenv("ALEMBIC_DATABASE_URL", _async_url(tmp_path))
    c = Config(str(ROOT / "alembic.ini"))
    c.set_main_option("script_location", str(ROOT / "alembic"))
    return c


def test_upgrade_matches_models_and_downgrades(cfg: Config, tmp_path: Path) -> None:
    command.downgrade(cfg, "base")
    command.upgrade(cfg, "head")
    engine = create_engine(_sync_url(_async_url(tmp_path)))
    with engine.connect() as conn:
        diff = compare_metadata(MigrationContext.configure(conn), Base.metadata)
        # test-only tables registered by other tests are not part of migrations
        diff = [d for d in diff if "test_" not in repr(d)]
        assert diff == []
        assert {
            "users",
            "device_sessions",
            "feature_flags",
            "onboarding_state",
            "preferences",
        } <= set(inspect(conn).get_table_names())
    command.downgrade(cfg, "base")
    with engine.connect() as conn:
        assert "users" not in inspect(conn).get_table_names()
