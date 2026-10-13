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
from sqlalchemy.types import TypeDecorator

from app.core.config import get_settings

# JSONB on Postgres, plain JSON elsewhere (SQLite in unit tests).
JsonType = JSON().with_variant(JSONB(), "postgresql")


def utcnow() -> datetime:
    return datetime.now(UTC)


class UtcDateTimeType(TypeDecorator[datetime]):
    """Timezone-aware UTC datetimes on every backend (SQLite drops tzinfo)."""

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect: object) -> datetime | None:
        if value is not None and value.tzinfo is not None:
            return value.astimezone(UTC)
        return value

    def process_result_value(self, value: datetime | None, dialect: object) -> datetime | None:
        if value is not None and value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value


UtcDateTime = UtcDateTimeType()


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


def get_sessionmaker() -> async_sessionmaker[AsyncSession]:
    if _sessionmaker is None:
        init_engine()
    if _sessionmaker is None:  # pragma: no cover
        raise RuntimeError("engine not initialised")
    return _sessionmaker


async def get_session() -> AsyncIterator[AsyncSession]:
    maker = _sessionmaker
    if maker is None:
        init_engine()
        maker = _sessionmaker
    if maker is None:  # pragma: no cover
        raise RuntimeError("engine not initialised")
    async with maker() as session:
        yield session
