from httpx import AsyncClient

from app.core.redis import get_redis
from app.services.flags import set_flag
from tests.conftest import Env


async def test_defaults(client: AsyncClient) -> None:
    r = await client.get("/v1/config")
    assert r.status_code == 200
    body = r.json()
    assert body["flags"] == {"guest_mode_enabled": True, "onboarding_variant": "quiz_first"}
    assert body["min_age"] == 16
    assert body["privacy_policy_url"].startswith("https://")


async def test_db_override_and_cache_invalidation(env: Env) -> None:
    await env.client.get("/v1/config")  # warms cache
    async with env.maker() as s:
        await set_flag(s, get_redis(), "onboarding_variant", "closet_first")
        await set_flag(s, get_redis(), "guest_mode_enabled", False)
    flags = (await env.client.get("/v1/config")).json()["flags"]
    assert flags == {"guest_mode_enabled": False, "onboarding_variant": "closet_first"}


async def test_invalid_flag_rejected(env: Env) -> None:
    import pytest

    async with env.maker() as s:
        with pytest.raises(ValueError):
            await set_flag(s, get_redis(), "onboarding_variant", "bogus")
        with pytest.raises(ValueError):
            await set_flag(s, get_redis(), "unknown_flag", True)
