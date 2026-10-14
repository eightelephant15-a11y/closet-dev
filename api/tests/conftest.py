import os
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from pathlib import Path

os.environ.setdefault("QUEUE_BACKEND", "eager")  # jobs run inline in tests

import fakeredis
import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

import app.models
import app.services.closet_jobs  # noqa: F401  (register job handlers)
from app.core import redis as redis_mod
from app.core.auth import FakeTokenVerifier, set_verifier
from app.core.config import get_settings
from app.core.db import Base, get_session, get_sessionmaker
from app.main import create_app
from app.queue.core import JobDeps
from app.queue.deps import set_queue, set_vision_factory
from app.queue.eager import EagerQueue
from app.services.background import PassThroughRemover
from app.services.storage import LocalStorage, set_storage
from app.vision import build_provider


@dataclass
class Env:
    app: FastAPI
    client: AsyncClient
    maker: async_sessionmaker[AsyncSession]
    verifier: FakeTokenVerifier
    storage: LocalStorage
    queue: EagerQueue
    deps: JobDeps


@pytest.fixture(autouse=True)
def _fake_redis() -> None:
    redis_mod.set_redis(fakeredis.FakeAsyncRedis(decode_responses=True))


@asynccontextmanager
async def make_env(tmp_path: Path, *, fake_auth: bool = True) -> AsyncIterator[Env]:
    """An in-process API: SQLite, fake Redis, disk storage, inline job queue, fake vision."""
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
    storage = LocalStorage(tmp_path / "storage", secret="t" * 32)
    set_storage(storage)
    queue = EagerQueue()
    deps = JobDeps(
        maker=maker,
        storage=storage,
        queue=queue,
        redis=redis_mod.get_redis,
        settings=get_settings(),
        remover=PassThroughRemover(),
        vision=build_provider,
    )
    queue.deps = deps
    set_queue(queue)
    set_vision_factory(None)
    verifier = FakeTokenVerifier()
    if fake_auth:
        set_verifier(verifier)
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            yield Env(app, c, maker, verifier, storage, queue, deps)
    finally:
        set_queue(None)
        set_vision_factory(None)
        set_storage(None)
        await engine.dispose()


@pytest.fixture
async def env(tmp_path: Path) -> AsyncIterator[Env]:
    async with make_env(tmp_path) as e:
        yield e


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
