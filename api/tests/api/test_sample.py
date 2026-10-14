from app.data.places import autocomplete
from tests.conftest import Env, auth

DEV = {"device_id": "d", "platform": "ios", "app_version": "1"}


async def _in(env: Env) -> dict[str, str]:
    h = auth("u1", "a@x.com")
    await env.client.post("/v1/auth/session", json=DEV, headers=h)
    return h


def test_autocomplete_logic() -> None:
    assert autocomplete("aus") == ["Austin, TX"]
    assert autocomplete("a")[:0] == []
    assert "San Francisco, CA" in autocomplete("francisco")
    assert autocomplete("zzzz") == []


async def test_places_and_sample_endpoints_require_auth_and_work(env: Env) -> None:
    assert (await env.client.get("/v1/places/autocomplete?q=aus")).status_code == 401
    h = await _in(env)
    assert (await env.client.get("/v1/places/autocomplete?q=sea", headers=h)).json() == [
        "Seattle, WA"
    ]


async def test_daily_outfit_time_validation(env: Env) -> None:
    h = await _in(env)
    r = await env.client.patch("/v1/me", json={"daily_outfit_time": "07:30"}, headers=h)
    assert r.status_code == 200 and r.json()["daily_outfit_time"] == "07:30"
    bad = await env.client.patch("/v1/me", json={"daily_outfit_time": "25:99"}, headers=h)
    assert bad.status_code == 422
