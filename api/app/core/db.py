from collections.abc import AsyncIterator
from datetime import UTC, datetime

from sqlalchemy import JSON, DateTime
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import get_settings

# JSONB on Postgres, plain JSON elsewhere (SQLite in unit tests).
JsonType = JSON().with_variant(JSONB(), "postgresql")


def utcnow() -> datetime:
    return datetime.now(UTC)


UtcDateTime = DateTime(timezone=True)


class Base(DeclarativeBase):
    pass


# Tables keyed by a unique user_id. They follow a user when a guest is merged into an existing
# account, and are removed on hard delete. Models register themselves with the decorator.
MERGEABLE: list[type[Base]] = []


def register_mergeable[M: type[Base]](model: M) -> M:
    if model not in MERGEABLE:
        MERGEABLE.append(model)
    return model


_engine: AsyncEngine | None = None
_sessionmaker: async_sessionmaker[AsyncSession] | None = None


def init_engine(url: str | None = None) -> AsyncEngine:
    global _engine, _sessionmaker
    _engine = create_async_engine(url or get_settings().database_url, pool_pre_ping=True)
    _sessionmaker = async_sessionmaker(_engine, expire_on_commit=False)
    return _engine


async def get_session() -> AsyncIterator[AsyncSession]:
    maker = _sessionmaker
    if maker is None:
        init_engine()
        maker = _sessionmaker
    if maker is None:  # pragma: no cover
        raise RuntimeError("engine not initialised")
    async with maker() as session:
        yield session
