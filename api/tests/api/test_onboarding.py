import uuid

from sqlalchemy import select

from app.core.redis import get_redis
from app.models import User
from app.services.flags import set_flag
from tests.conftest import Env, auth

DEV = {"device_id": "dev1", "platform": "ios", "app_version": "1.0.0"}


async def _signin(env: Env, uid: str = "u1", email: str | None = "a@x.com") -> dict[str, str]:
    h = auth(uid, email)
    await env.client.post("/v1/auth/session", json=DEV, headers=h)
    return h


async def test_onboarding_state_defaults_and_pins_variant(env: Env) -> None:
    h = await _signin(env)
    s = (await env.client.get("/v1/onboarding", headers=h)).json()
    assert s["variant"] == "quiz_first" and s["current_step"] == "welcome"
    async with env.maker() as db:
        await set_flag(db, get_redis(), "onboarding_variant", "closet_first")
    assert (await env.client.get("/v1/onboarding", headers=h)).json()["variant"] == "quiz_first"
    h2 = await _signin(env, "u2", "b@x.com")
    assert (await env.client.get("/v1/onboarding", headers=h2)).json()["variant"] == "closet_first"


async def test_put_onboarding_is_resumable_and_monotonic(env: Env) -> None:
    h = await _signin(env)
    r = await env.client.put(
        "/v1/onboarding",
        json={"current_step": "quiz", "completed_steps": ["welcome", "age"]},
        headers=h,
    )
    assert r.json()["current_step"] == "quiz"
    # a stale device must not un-complete steps
    r = await env.client.put("/v1/onboarding", json={"completed_steps": ["welcome"]}, headers=h)
    assert r.json()["completed_steps"] == ["age", "welcome"]
    r = await env.client.put(
        "/v1/onboarding", json={"completed": True, "time_to_first_outfit_ms": 90000}, headers=h
    )
    body = r.json()
    assert body["completed_at"] and body["current_step"] == "done"
    assert body["time_to_first_outfit_ms"] == 90000
    r = await env.client.put("/v1/onboarding", json={"time_to_first_outfit_ms": 5}, headers=h)
    assert r.json()["time_to_first_outfit_ms"] == 90000  # first measurement wins


async def test_invalid_step_rejected(env: Env) -> None:
    h = await _signin(env)
    r = await env.client.put("/v1/onboarding", json={"current_step": "nope"}, headers=h)
    assert r.status_code == 422 and r.json()["error"]["code"] == "validation_error"


async def test_age_confirmation_ok(env: Env) -> None:
    h = await _signin(env)
    assert (
        await env.client.post(
            "/v1/me/age-confirmation", json={"confirmed_16_plus": True}, headers=h
        )
    ).status_code == 204
    assert (await env.client.get("/v1/me", headers=h)).json()["age_confirmed_at"]


async def test_under_16_deletes_account_data(env: Env) -> None:
    h = await _signin(env)
    await env.client.get("/v1/onboarding", headers=h)
    await env.client.put("/v1/me/preferences", json={"answers": {"fit": "slim"}}, headers=h)
    r = await env.client.post(
        "/v1/me/age-confirmation", json={"confirmed_16_plus": False}, headers=h
    )
    assert r.status_code == 403 and r.json()["error"]["code"] == "age_under_minimum"
    async with env.maker() as db:
        assert (await db.execute(select(User))).first() is None
        from app.models import DeviceSession, OnboardingState, Preferences

        for model in (DeviceSession, OnboardingState, Preferences):
            assert (await db.execute(select(model))).first() is None
    assert "u1" in env.verifier.deleted


async def test_preferences_progressive_save_and_department_sync(env: Env) -> None:
    h = await _signin(env)
    empty = (await env.client.get("/v1/me/preferences", headers=h)).json()
    assert empty["answers"] == {} and empty["model_version"] == 1
    r = await env.client.put(
        "/v1/me/preferences", json={"answers": {"department": "menswear"}}, headers=h
    )
    assert r.json()["weights"]["department"] == "menswear"
    r = await env.client.put(
        "/v1/me/preferences", json={"answers": {"fit": "slim", "colors": ["navy"]}}, headers=h
    )
    body = r.json()
    assert body["answers"] == {"department": "menswear", "fit": "slim", "colors": ["navy"]}
    assert body["weights"]["fit"]["slim"] == 1.0
    assert (await env.client.get("/v1/me", headers=h)).json()["clothing_department"] == "menswear"


async def test_preferences_validation(env: Env) -> None:
    h = await _signin(env)
    r = await env.client.put("/v1/me/preferences", json={"answers": {"fit": "baggy"}}, headers=h)
    assert r.status_code == 422 and r.json()["error"]["code"] == "invalid_answers"
    # failed write must not persist anything
    assert (await env.client.get("/v1/me/preferences", headers=h)).json()["answers"] == {}


async def test_users_cannot_read_each_others_onboarding_or_preferences(env: Env) -> None:
    a = await _signin(env, "a", "a@x.com")
    b = await _signin(env, "b", "b@x.com")
    await env.client.put("/v1/me/preferences", json={"answers": {"fit": "slim"}}, headers=a)
    await env.client.put("/v1/onboarding", json={"current_step": "quiz"}, headers=a)
    assert (await env.client.get("/v1/me/preferences", headers=b)).json()["answers"] == {}
    assert (await env.client.get("/v1/onboarding", headers=b)).json()["current_step"] == "welcome"
    me_a = (await env.client.get("/v1/me", headers=a)).json()
    me_b = (await env.client.get("/v1/me", headers=b)).json()
    assert me_a["id"] != me_b["id"]
    # there is no endpoint addressing another user's id
    r = await env.client.get(f"/v1/users/{me_a['id']}", headers=b)
    assert r.status_code == 404
    r = await env.client.get(f"/v1/me/{uuid.UUID(me_a['id'])}/preferences", headers=b)
    assert r.status_code == 404
