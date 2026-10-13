from collections.abc import AsyncIterator

import fakeredis
import pytest
from httpx import ASGITransport, AsyncClient

from app.core import redis as redis_mod
from app.main import create_app


@pytest.fixture(autouse=True)
def _fake_redis() -> None:
    redis_mod.set_redis(fakeredis.FakeAsyncRedis(decode_responses=True))


@pytest.fixture
async def client() -> AsyncIterator[AsyncClient]:
    app = create_app()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
