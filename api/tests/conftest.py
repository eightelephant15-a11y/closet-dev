import uuid
from collections.abc import AsyncIterator
from dataclasses import dataclass
from pathlib import Path

import fakeredis
import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401  (register tables)
from app.core import redis as redis_mod
from app.core.auth import FakeTokenVerifier, set_verifier
from app.core.db import Base, get_session, get_sessionmaker
from app.main import create_app
from app.services.storage import LocalStorage, set_storage


@dataclass
class Env:
    app: FastAPI
    client: AsyncClient
    maker: async_sessionmaker[AsyncSession]
    verifier: FakeTokenVerifier
    storage: LocalStorage


@pytest.fixture(autouse=True)
def _fake_redis() -> None:
    redis_mod.set_redis(fakeredis.FakeAsyncRedis(decode_responses=True))


@pytest.fixture
async def env(tmp_path: Path) -> AsyncIterator[Env]:
    engine = create_async_engine(
        "sqlite+aiosqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)

    async def _session() -> AsyncIterator[AsyncSession]:
        async with maker() as s:
            yield s

    app = create_app()
    app.dependency_overrides[get_session] = _session
    app.dependency_overrides[get_sessionmaker] = lambda: maker
    storage = LocalStorage(tmp_path / "exports")
    set_storage(storage)
    verifier = FakeTokenVerifier()
    set_verifier(verifier)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield Env(app, c, maker, verifier, storage)
    await engine.dispose()


@pytest.fixture
async def client(env: Env) -> AsyncClient:
    return env.client


def auth(
    uid: str, email: str | None = None, name: str | None = None, device: str = "dev1"
) -> dict[str, str]:
    tok = f"fake:{uid}:{email or ''}" + (f":{name}" if name else "")
    return {"Authorization": f"Bearer {tok}", "X-Device-Id": device}


def new_id() -> str:
    return uuid.uuid4().hex
