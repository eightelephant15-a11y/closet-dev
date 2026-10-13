import uuid

from sqlalchemy import ForeignKey, select
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base
from app.models import DeviceSession, User
from app.services.accounts import register_mergeable
from tests.conftest import Env, auth

DEVICE = {"device_id": "dev1", "platform": "ios", "app_version": "1.0.0"}


class _Note(Base):
    """Stand-in for later per-user tables (preferences, onboarding_state...)."""

    __tablename__ = "test_notes"
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), primary_key=True)
    text: Mapped[str]


register_mergeable(_Note)


async def test_requires_auth(env: Env) -> None:
    r = await env.client.get("/v1/me")
    assert r.status_code == 401 and r.json()["error"]["code"] == "missing_token"
    r = await env.client.get("/v1/me", headers={"Authorization": "Bearer junk"})
    assert r.json()["error"]["code"] == "invalid_token"


async def test_no_session_yet(env: Env) -> None:
    r = await env.client.get("/v1/me", headers=auth("u1"))
    assert r.json()["error"]["code"] == "no_session"


async def test_guest_session_then_me(env: Env) -> None:
    r = await env.client.post("/v1/auth/session", json=DEVICE, headers=auth("g1"))
    assert r.status_code == 200
    body = r.json()
    assert body["is_new_user"] and body["user"]["is_anonymous"]
    again = await env.client.post("/v1/auth/session", json=DEVICE, headers=auth("g1"))
    assert not again.json()["is_new_user"]
    assert again.json()["user"]["id"] == body["user"]["id"]
    me = await env.client.get("/v1/me", headers=auth("g1"))
    assert me.json()["id"] == body["user"]["id"]


async def test_upgrade_preserves_user_id_and_data(env: Env) -> None:
    """Linking credentials keeps the Firebase UID, so the internal user and its data stay."""
    r = await env.client.post("/v1/auth/session", json=DEVICE, headers=auth("g1"))
    uid = r.json()["user"]["id"]
    await env.client.patch("/v1/me", json={"city": "Austin", "units": "metric"}, headers=auth("g1"))
    async with env.maker() as s:
        s.add(_Note(user_id=uuid.UUID(uid), text="kept"))
        await s.commit()

    # same uid, now with a Google identity
    h = auth("g1", "ada@example.com", "Ada")
    up = await env.client.post("/v1/auth/upgrade", json={}, headers=h)
    assert up.status_code == 200
    u = up.json()
    assert u["id"] == uid
    assert not u["is_anonymous"] and u["email"] == "ada@example.com"
    assert u["display_name"] == "Ada" and u["city"] == "Austin" and u["units"] == "metric"
    async with env.maker() as s:
        assert (await s.get(_Note, uuid.UUID(uid))).text == "kept"  # type: ignore[union-attr]


async def test_upgrade_requires_non_anonymous_token(env: Env) -> None:
    await env.client.post("/v1/auth/session", json=DEVICE, headers=auth("g1"))
    r = await env.client.post("/v1/auth/upgrade", json={}, headers=auth("g1"))
    assert r.status_code == 400 and r.json()["error"]["code"] == "not_upgraded"


async def test_merge_guest_into_existing_account(env: Env) -> None:
    existing = auth("real", "ada@example.com", "Ada")
    r = await env.client.post("/v1/auth/session", json=DEVICE, headers=existing)
    real_id = r.json()["user"]["id"]
    g = await env.client.post(
        "/v1/auth/session", json={**DEVICE, "device_id": "d2"}, headers=auth("g1")
    )
    gid = g.json()["user"]["id"]
    await env.client.patch("/v1/me", json={"city": "Austin"}, headers=auth("g1"))
    async with env.maker() as s:
        s.add(_Note(user_id=uuid.UUID(gid), text="guest data"))
        await s.commit()

    r = await env.client.post(
        "/v1/auth/upgrade", json={"merge_from_token": "fake:g1:"}, headers=existing
    )
    assert r.status_code == 200 and r.json()["id"] == real_id
    assert r.json()["city"] == "Austin"
    async with env.maker() as s:
        assert (await s.get(_Note, uuid.UUID(real_id))).text == "guest data"  # type: ignore[union-attr]
        assert await s.get(User, uuid.UUID(gid)) is None


async def test_merge_does_not_overwrite_existing_data(env: Env) -> None:
    existing = auth("real", "ada@example.com")
    real_id = (await env.client.post("/v1/auth/session", json=DEVICE, headers=existing)).json()[
        "user"
    ]["id"]
    gid = (
        await env.client.post(
            "/v1/auth/session", json={**DEVICE, "device_id": "d2"}, headers=auth("g1")
        )
    ).json()["user"]["id"]
    async with env.maker() as s:
        s.add(_Note(user_id=uuid.UUID(real_id), text="mine"))
        s.add(_Note(user_id=uuid.UUID(gid), text="guest"))
        await s.commit()
    await env.client.post(
        "/v1/auth/upgrade", json={"merge_from_token": "fake:g1:"}, headers=existing
    )
    async with env.maker() as s:
        notes = (await s.execute(select(_Note))).scalars().all()
        assert [n.text for n in notes] == ["mine"]


async def test_cannot_merge_a_real_account(env: Env) -> None:
    a = auth("a", "a@example.com")
    b = auth("b", "b@example.com")
    await env.client.post("/v1/auth/session", json=DEVICE, headers=a)
    await env.client.post("/v1/auth/session", json=DEVICE, headers=b)
    r = await env.client.post(
        "/v1/auth/upgrade", json={"merge_from_token": "fake:b:b@example.com"}, headers=a
    )
    assert r.status_code == 400 and r.json()["error"]["code"] == "merge_not_allowed"


async def test_multi_device_sessions_and_revocation(env: Env) -> None:
    h1 = auth("u", "u@example.com", device="phone")
    h2 = auth("u", "u@example.com", device="tablet")
    await env.client.post("/v1/auth/session", json={**DEVICE, "device_id": "phone"}, headers=h1)
    await env.client.post(
        "/v1/auth/session",
        json={**DEVICE, "device_id": "tablet", "platform": "android"},
        headers=h2,
    )
    sessions = (await env.client.get("/v1/auth/sessions", headers=h1)).json()["items"]
    assert {s["device_id"] for s in sessions} == {"phone", "tablet"}

    tablet = next(s for s in sessions if s["device_id"] == "tablet")
    assert (
        await env.client.delete(f"/v1/auth/sessions/{tablet['id']}", headers=h1)
    ).status_code == 204
    r = await env.client.get("/v1/me", headers=h2)
    assert r.status_code == 401 and r.json()["error"]["code"] == "session_revoked"
    assert (await env.client.get("/v1/me", headers=h1)).status_code == 200

    # signing in again on that device re-opens it
    await env.client.post("/v1/auth/session", json={**DEVICE, "device_id": "tablet"}, headers=h2)
    assert (await env.client.get("/v1/me", headers=h2)).status_code == 200


async def test_sign_out_revokes_current_device(env: Env) -> None:
    h = auth("u", "u@example.com")
    await env.client.post("/v1/auth/session", json=DEVICE, headers=h)
    assert (await env.client.post("/v1/auth/sign-out", headers=h)).status_code == 204
    assert (await env.client.get("/v1/me", headers=h)).json()["error"]["code"] == "session_revoked"
    async with env.maker() as s:
        ds = (await s.execute(select(DeviceSession))).scalar_one()
        assert ds.revoked_at is not None


async def test_cannot_revoke_other_users_session(env: Env) -> None:
    a, b = auth("a", "a@x.com"), auth("b", "b@x.com")
    await env.client.post("/v1/auth/session", json=DEVICE, headers=a)
    await env.client.post("/v1/auth/session", json=DEVICE, headers=b)
    sid = (await env.client.get("/v1/auth/sessions", headers=a)).json()["items"][0]["id"]
    r = await env.client.delete(f"/v1/auth/sessions/{sid}", headers=b)
    assert r.status_code == 404


async def test_sessions_are_paginated(env: Env) -> None:
    h = auth("u", "u@example.com", device="d0")
    for i in range(5):
        await env.client.post(
            "/v1/auth/session",
            json={**DEVICE, "device_id": f"d{i}"},
            headers=auth("u", "u@example.com", device=f"d{i}"),
        )
    first = (await env.client.get("/v1/auth/sessions?limit=2", headers=h)).json()
    assert len(first["items"]) == 2 and first["next_cursor"]
    second = (
        await env.client.get(f"/v1/auth/sessions?limit=2&cursor={first['next_cursor']}", headers=h)
    ).json()
    last = (
        await env.client.get(f"/v1/auth/sessions?limit=2&cursor={second['next_cursor']}", headers=h)
    ).json()
    ids = [s["id"] for page in (first, second, last) for s in page["items"]]
    assert len(ids) == len(set(ids)) == 5 and last["next_cursor"] is None
    bad = await env.client.get("/v1/auth/sessions?cursor=%25%25", headers=h)
    assert bad.status_code == 422 and bad.json()["error"]["code"] == "invalid_cursor"
    assert (await env.client.get("/v1/auth/sessions?limit=1000", headers=h)).status_code == 422
