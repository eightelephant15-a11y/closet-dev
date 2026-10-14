import io
import json
import uuid
import zipfile
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select

from app.models import (
    AuditLog,
    Consents,
    DeviceSession,
    ExportJob,
    OnboardingState,
    Preferences,
    User,
    UserStatus,
)
from app.services import privacy
from tests.conftest import Env, auth

DEV = {"device_id": "dev1", "platform": "ios", "app_version": "1.0.0"}


async def _signin(env: Env, uid: str = "u1", email: str = "a@x.com", device: str = "dev1"):
    h = auth(uid, email, "Ada", device=device)
    r = await env.client.post("/v1/auth/session", json={**DEV, "device_id": device}, headers=h)
    return h, r.json()["user"]["id"]


async def _populate(env: Env, h: dict[str, str]) -> None:
    await env.client.put("/v1/me/preferences", json={"answers": {"fit": "slim"}}, headers=h)
    await env.client.put("/v1/onboarding", json={"current_step": "quiz"}, headers=h)
    await env.client.patch("/v1/me", json={"city": "Austin"}, headers=h)


# ---- consents --------------------------------------------------------------------------


async def test_ai_training_opt_out_is_on_by_default_with_timestamp_and_policy(env: Env) -> None:
    h, _ = await _signin(env)
    c = (await env.client.get("/v1/me/consents", headers=h)).json()
    assert c["no_ai_training"] is True
    assert c["ai_training_updated_at"] and c["policy_version"] == "2026-01"
    assert c["analytics_opt_in"] is None  # undecided => no analytics


async def test_consent_updates_are_timestamped(env: Env) -> None:
    h, _ = await _signin(env)
    before = (await env.client.get("/v1/me/consents", headers=h)).json()
    r = await env.client.put(
        "/v1/me/consents",
        json={"analytics_opt_in": True, "no_ai_training": False, "location_explained": True},
        headers=h,
    )
    c = r.json()
    assert c["analytics_opt_in"] is True and c["analytics_updated_at"]
    assert c["no_ai_training"] is False
    assert c["ai_training_updated_at"] >= before["ai_training_updated_at"]
    assert c["location_explained_at"]
    # unchanged fields keep their original timestamps
    r2 = await env.client.put("/v1/me/consents", json={"analytics_opt_in": True}, headers=h)
    assert r2.json()["analytics_updated_at"] == c["analytics_updated_at"]


async def test_consents_are_private(env: Env) -> None:
    a, _ = await _signin(env, "a", "a@x.com")
    b, _ = await _signin(env, "b", "b@x.com")
    await env.client.put("/v1/me/consents", json={"analytics_opt_in": True}, headers=a)
    assert (await env.client.get("/v1/me/consents", headers=b)).json()["analytics_opt_in"] is None


# ---- export ----------------------------------------------------------------------------


async def test_export_job_produces_a_downloadable_zip(env: Env) -> None:
    h, uid = await _signin(env)
    await _populate(env, h)
    r = await env.client.post("/v1/me/export", headers=h)
    assert r.status_code == 202
    job = r.json()
    status = (await env.client.get(f"/v1/me/export/{job['id']}", headers=h)).json()
    assert status["status"] == "completed" and status["expires_at"]
    dl = await env.client.get(status["download_url"], headers=h)
    assert dl.status_code == 200
    assert "attachment" in dl.headers["content-disposition"]
    assert dl.headers["content-type"] == "application/zip"
    data = json.loads(zipfile.ZipFile(io.BytesIO(dl.content)).read("data.json"))
    assert data["profile"]["id"] == uid and data["profile"]["city"] == "Austin"
    assert data["preferences"]["answers"] == {"fit": "slim"}
    assert data["onboarding"]["current_step"] == "quiz"
    assert data["consents"]["no_ai_training"] is True
    assert data["devices"][0]["platform"] == "ios"


async def test_export_is_private_to_the_owner(env: Env) -> None:
    a, _ = await _signin(env, "a", "a@x.com")
    b, _ = await _signin(env, "b", "b@x.com")
    job = (await env.client.post("/v1/me/export", headers=a)).json()
    assert (await env.client.get(f"/v1/me/export/{job['id']}", headers=b)).status_code == 404
    assert (
        await env.client.get(f"/v1/me/export/{job['id']}/download", headers=b)
    ).status_code == 404
    assert (await env.client.get(f"/v1/me/export/{uuid.uuid4()}", headers=a)).status_code == 404


async def test_expired_export_cannot_be_downloaded(env: Env) -> None:
    h, _ = await _signin(env)
    job = (await env.client.post("/v1/me/export", headers=h)).json()
    async with env.maker() as s:
        row = await s.get(ExportJob, uuid.UUID(job["id"]))
        assert row is not None
        row.expires_at = datetime.now(UTC) - timedelta(minutes=1)
        await s.commit()
    r = await env.client.get(f"/v1/me/export/{job['id']}/download", headers=h)
    assert r.status_code == 410 and r.json()["error"]["code"] == "export_expired"


# ---- deletion --------------------------------------------------------------------------


async def test_delete_signs_out_everywhere_and_blocks_access(env: Env) -> None:
    h1, _ = await _signin(env, device="phone")
    h2, _ = await _signin(env, device="tablet")
    r = await env.client.delete("/v1/me", headers=h1)
    assert r.status_code == 200
    purge_after = datetime.fromisoformat(r.json()["purge_after"])
    assert (
        timedelta(days=29) < purge_after - datetime.now(UTC).replace(tzinfo=None)
        if purge_after.tzinfo is None
        else timedelta(days=29) < purge_after - datetime.now(UTC)
    )
    assert "u1" in env.verifier.revoked
    for h in (h1, h2):
        resp = await env.client.get("/v1/me", headers=h)
        assert resp.status_code in (401, 403)
    async with env.maker() as s:
        sessions = (await s.execute(select(DeviceSession))).scalars().all()
        assert sessions and all(x.revoked_at is not None for x in sessions)


async def test_restore_within_window(env: Env) -> None:
    h, _ = await _signin(env)
    await env.client.delete("/v1/me", headers=h)
    # signing in again is possible, but only restore works until restored
    resp = await env.client.post("/v1/auth/session", json=DEV, headers=h)
    assert resp.json()["user"]["status"] == "pending_deletion"
    assert (await env.client.get("/v1/me", headers=h)).json()["error"]["code"] == "account_inactive"
    assert (await env.client.post("/v1/me/restore", headers=h)).status_code == 204
    me = (await env.client.get("/v1/me", headers=h)).json()
    assert me["status"] == "active"


async def _count(env: Env, model: type) -> int:
    async with env.maker() as s:
        return (await s.execute(select(func.count()).select_from(model))).scalar_one()


async def test_purge_removes_all_user_data_after_30_days(env: Env) -> None:
    """Account deletion: nothing is left once the 30-day window passes."""
    h, uid = await _signin(env)
    other, other_id = await _signin(env, "keep", "k@x.com")
    await _populate(env, h)
    await _populate(env, other)
    await env.client.put("/v1/me/consents", json={"analytics_opt_in": True}, headers=h)
    job = (await env.client.post("/v1/me/export", headers=h)).json()
    file_key = (await env.client.get(f"/v1/me/export/{job['id']}", headers=h)).json()["id"]
    assert file_key
    assert list(env.storage.root.rglob("*.zip"))

    purged_images: list[uuid.UUID] = []

    async def hook(user_id: uuid.UUID) -> None:  # Phase 2 image deletion registers like this
        purged_images.append(user_id)

    privacy.register_purge_hook(hook)
    try:
        await env.client.delete("/v1/me", headers=h)

        # Not due yet: nothing happens.
        async with env.maker() as s:
            assert await privacy.purge_due_users(s, env.storage, env.verifier) == 0
        assert await _count(env, User) == 2

        # 31 days later:
        later = datetime.now(UTC) + timedelta(days=31)
        async with env.maker() as s:
            assert await privacy.purge_due_users(s, env.storage, env.verifier, now=later) == 1
        # Idempotent
        async with env.maker() as s:
            assert await privacy.purge_due_users(s, env.storage, env.verifier, now=later) == 0
    finally:
        privacy.PURGE_HOOKS.remove(hook)

    async with env.maker() as s:
        assert await s.get(User, uuid.UUID(uid)) is None
        for model in (Preferences, OnboardingState, Consents, DeviceSession, ExportJob):
            rows = (await s.execute(select(model))).scalars().all()
            assert all(getattr(r, "user_id", None) != uuid.UUID(uid) for r in rows), model
        # the other user is untouched
        assert await s.get(User, uuid.UUID(other_id)) is not None
        assert await s.get(Preferences, uuid.UUID(other_id)) is not None
    assert not list(env.storage.root.rglob("*.zip")), "export files must be deleted"
    assert purged_images == [uuid.UUID(uid)]
    assert "u1" in env.verifier.deleted

    # An audit trail exists but holds no personal data.
    async with env.maker() as s:
        events = (await s.execute(select(AuditLog))).scalars().all()
        assert {"deletion_requested", "account_purged"} <= {e.event for e in events}
        assert all(uid not in e.user_ref and "@" not in e.user_ref for e in events)


async def test_purge_ignores_active_and_restored_users(env: Env) -> None:
    h, uid = await _signin(env)
    await env.client.delete("/v1/me", headers=h)
    await env.client.post("/v1/auth/session", json=DEV, headers=h)
    await env.client.post("/v1/me/restore", headers=h)
    async with env.maker() as s:
        n = await privacy.purge_due_users(
            s, env.storage, env.verifier, now=datetime.now(UTC) + timedelta(days=90)
        )
        assert n == 0
        user = await s.get(User, uuid.UUID(uid))
        assert user is not None and user.status == UserStatus.active


async def test_deleted_user_data_is_not_readable_by_others(env: Env) -> None:
    a, _ = await _signin(env, "a", "a@x.com")
    b, _ = await _signin(env, "b", "b@x.com")
    await _populate(env, a)
    await env.client.delete("/v1/me", headers=a)
    assert (await env.client.get("/v1/me/preferences", headers=b)).json()["answers"] == {}


async def test_worker_processes_pending_exports(env: Env) -> None:
    h, _ = await _signin(env)
    async with env.maker() as s:
        user = (await s.execute(select(User))).scalar_one()
        job = await privacy.create_export_job(s, user)
        assert await privacy.run_pending_exports(s, env.storage) == 1
        await s.refresh(job)
        assert job.status.value == "completed"
        assert await privacy.run_pending_exports(s, env.storage) == 0
    assert h  # signed in


# ---- closet data: export, deletion, account merge --------------------------------------------------------------


async def _closet(env: Env, h: dict[str, str]) -> list[dict[str, object]]:
    from tests.closet_helpers import add_garment

    a = await add_garment(env, h, "closet-aaaa1", "navy_jeans.jpg")
    b = await add_garment(env, h, "closet-bbbb2", "white_tee.jpg")
    await env.client.patch(
        f"/v1/garments/{a['id']}", headers=h, json={"primary_color": "black"}
    )  # a correction
    return [a, b]


async def test_export_includes_garments_corrections_and_the_photos(env: Env) -> None:
    h, _ = await _signin(env)
    a, b = await _closet(env, h)
    other, _ = await _signin(env, "other", "o@x.com")
    await _closet_for(env, other)

    job = (await env.client.post("/v1/me/export", headers=h)).json()
    dl = await env.client.get(f"/v1/me/export/{job['id']}/download", headers=h)
    z = zipfile.ZipFile(io.BytesIO(dl.content))
    data = json.loads(z.read("data.json"))
    ids = {g["id"] for g in data["garments"]}
    assert ids == {a["id"], b["id"]}, "only my garments"
    mine = next(g for g in data["garments"] if g["id"] == a["id"])
    assert mine["primary_color"] == "black" and mine["subcategory"] == "jeans"
    assert mine["corrections"] == [
        {"field": "primary_color", "ai_value": "navy", "your_value": "black"}
    ]
    assert (
        mine["ai_analysis"]["provider"] == "fake"
        and mine["ai_analysis"]["fields"]["primary_color"]["value"] == "navy"
    )
    names = set(z.namelist())
    assert names == {"data.json", *{p for g in data["garments"] for p in g["images"]}}
    assert len(names) == 3, "data.json + one full-size photo per garment"
    for name in names - {"data.json"}:
        assert z.read(name)[:4] == b"RIFF"  # real WebP bytes
        assert name.split("/")[1] in ids


async def _closet_for(env: Env, h: dict[str, str]) -> None:
    from tests.closet_helpers import add_garment

    await add_garment(env, h, "other-closet-1", "red_dress.jpg")


async def test_deleting_the_account_removes_garments_and_every_stored_image(env: Env) -> None:
    h, uid = await _signin(env)
    other, other_id = await _signin(env, "keep", "k@x.com")
    mine = await _closet(env, h)
    await _closet_for(env, other)
    await env.client.post("/v1/garments/sample", headers=h)
    await env.client.delete("/v1/me", headers=h)

    files_before = {p for p in env.storage.root.rglob("*") if p.is_file()}
    assert any(
        g["id"] in str(p) for g in mine for p in files_before
    )  # photos exist before the purge

    async with env.maker() as s:
        later = datetime.now(UTC) + timedelta(days=31)
        assert await privacy.purge_due_users(s, env.storage, env.verifier, now=later) == 1
    remaining = {str(p) for p in env.storage.root.rglob("*") if p.is_file()}
    assert not any(str(g["id"]) in p for g in mine for p in remaining), (
        "photos of the deleted user are gone"
    )
    assert any("g/" in p or "/g/" in p for p in remaining), "the other user's photos stay"
    async with env.maker() as s:
        from app.models import AnalysisJob, Garment, GarmentCorrection, GarmentImage

        for model in (Garment, GarmentImage, GarmentCorrection, AnalysisJob):
            rows = (await s.execute(select(model))).scalars().all()
            assert all(r.user_id != uuid.UUID(uid) for r in rows), model
            assert any(r.user_id == uuid.UUID(other_id) for r in rows) or model is GarmentCorrection


async def test_under_16_rejection_also_removes_garments_and_photos(env: Env) -> None:
    h, _ = await _signin(env)
    from tests.closet_helpers import add_garment

    g = await add_garment(env, h, "kid-closet-1", "navy_jeans.jpg")
    assert list(env.storage.root.rglob("*.webp"))
    r = await env.client.post(
        "/v1/me/age-confirmation", json={"confirmed_16_plus": False}, headers=h
    )
    assert r.status_code == 403
    assert not list(env.storage.root.rglob("*.webp")), g["id"]
    async with env.maker() as s:
        from app.models import Garment

        assert (await s.execute(select(Garment))).scalars().all() == []


async def test_guest_closet_follows_the_guest_into_the_account(env: Env) -> None:
    guest = auth("guest1")
    await env.client.post("/v1/auth/session", json=DEV, headers=guest)
    from tests.closet_helpers import add_garment

    g = await add_garment(env, guest, "guest-item-01", "navy_jeans.jpg")
    await env.client.post("/v1/garments/sample", headers=guest)
    member = auth("member1", "m@x.com", "M")
    await env.client.post("/v1/auth/session", json=DEV, headers=member)
    await env.client.post(
        "/v1/garments/sample", headers=member
    )  # the account already has its own sample items
    r = await env.client.post(
        "/v1/auth/upgrade", json={"merge_from_token": "fake:guest1:"}, headers=member
    )
    assert r.status_code == 200
    page = (await env.client.get("/v1/garments?limit=100", headers=member)).json()
    ids = {i["id"] for i in page["items"]}
    assert g["id"] in ids, "the guest's real garment moved over"
    assert page["total"] == 1 + 16, "no duplicate sample closet"
    detail = (await env.client.get(f"/v1/garments/{g['id']}", headers=member)).json()
    assert detail["images"][0]["status"] == "ready"
    assert (
        await env.client.get(detail["images"][0]["urls"]["m"])
    ).status_code == 200  # photos still resolve
