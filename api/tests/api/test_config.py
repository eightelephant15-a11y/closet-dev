from httpx import AsyncClient

from app.core.redis import get_redis
from app.services.flags import set_flag
from tests.conftest import Env


async def test_defaults(client: AsyncClient) -> None:
    r = await client.get("/v1/config")
    assert r.status_code == 200
    body = r.json()
    assert body["flags"] == {
        "guest_mode_enabled": True,
        "onboarding_variant": "quiz_first",
        "closet_bulk_add_enabled": True,
        "closet_item_limit_free": 30,
        "vision_provider": "fake",
    }
    assert body["min_age"] == 16
    assert body["privacy_policy_url"].startswith("https://")


async def test_db_override_and_cache_invalidation(env: Env) -> None:
    await env.client.get("/v1/config")  # warms cache
    async with env.maker() as s:
        await set_flag(s, get_redis(), "onboarding_variant", "closet_first")
        await set_flag(s, get_redis(), "guest_mode_enabled", False)
    flags = (await env.client.get("/v1/config")).json()["flags"]
    assert flags["guest_mode_enabled"] is False
    assert flags["onboarding_variant"] == "closet_first"


async def test_invalid_flag_rejected(env: Env) -> None:
    import pytest

    async with env.maker() as s:
        with pytest.raises(ValueError):
            await set_flag(s, get_redis(), "onboarding_variant", "bogus")
        with pytest.raises(ValueError):
            await set_flag(s, get_redis(), "unknown_flag", True)


async def test_new_closet_flags_are_validated(env: Env) -> None:
    import pytest

    async with env.maker() as s:
        await set_flag(s, get_redis(), "closet_item_limit_free", 50)
        await set_flag(s, get_redis(), "vision_provider", "claude")
        await set_flag(s, get_redis(), "closet_bulk_add_enabled", False)
        for key, bad in (
            ("closet_item_limit_free", "50"),
            ("closet_item_limit_free", True),
            ("vision_provider", "gpt"),
            ("closet_bulk_add_enabled", "yes"),
        ):
            with pytest.raises(ValueError):
                await set_flag(s, get_redis(), key, bad)  # type: ignore[arg-type]
    flags = (await env.client.get("/v1/config")).json()["flags"]
    assert flags["closet_item_limit_free"] == 50 and flags["vision_provider"] == "claude"
    assert flags["closet_bulk_add_enabled"] is False


async def test_taxonomy_endpoint_and_version_in_config(client: AsyncClient) -> None:
    doc = (await client.get("/v1/taxonomy")).json()
    cfg = (await client.get("/v1/config")).json()
    assert cfg["taxonomy_version"] == doc["version"] == 1
    assert {c["id"] for c in doc["categories"]} >= {"top", "footwear"}
