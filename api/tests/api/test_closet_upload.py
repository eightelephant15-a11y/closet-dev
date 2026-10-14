import io
import time
import uuid

import pytest
from PIL import Image
from sqlalchemy import select

from app.core.config import get_settings
from app.core.redis import get_redis
from app.models import Garment, GarmentImage
from app.queue.core import DLQ_KEY
from app.services.flags import set_flag
from tests.closet_helpers import add_garment, complete, create, signin, upload
from tests.conftest import Env
from tests.imagegen import garment_image


@pytest.fixture(autouse=True)
def _restore_settings():  # type: ignore[no-untyped-def]
    s = get_settings()
    saved = {
        k: getattr(s, k) for k in ("upload_rate_per_hour", "upload_max_bytes", "queue_max_tries")
    }
    yield
    for k, v in saved.items():
        setattr(s, k, v)


def webp(data: bytes) -> Image.Image:
    return Image.open(io.BytesIO(data))


# ---- happy path ---------------------------------------------------------------------------------


async def test_photo_goes_phone_to_storage_and_comes_back_as_three_thumbnails(env: Env) -> None:
    h = await signin(env)
    g = await create(env, h)
    assert g["upload"]["method"] == "PUT" and g["images"][0]["status"] == "awaiting_upload"
    assert g["analysis"]["status"] == "pending" and g["images"][0]["urls"]["m"] is None

    assert await upload(env, g["upload"], garment_image((600, 900))) == 200
    r = await complete(env, h, g)
    assert r.status_code == 202

    done = (await env.client.get(f"/v1/garments/{g['id']}", headers=h)).json()
    img = done["images"][0]
    assert img["status"] == "ready" and (img["width"], img["height"]) == (600, 900)
    assert done["cover_image_id"] == img["id"]
    sizes = {}
    for variant in ("s", "m", "l"):
        got = await env.client.get(img["urls"][variant])
        assert got.status_code == 200 and got.headers["content-type"] == "image/webp"
        sizes[variant] = webp(got.content).size
    assert sizes == {"s": (200, 200), "m": (600, 600), "l": (1200, 1200)}
    full = await env.client.get(img["urls"]["full"])
    assert webp(full.content).size == (600, 900)


async def test_raw_upload_is_deleted_and_only_processed_files_remain(env: Env) -> None:
    h = await signin(env)
    g = await add_garment(env, h)
    files = sorted(p.name for p in env.storage.root.rglob("*") if p.is_file())
    assert files == ["full.webp", "thumb_l.webp", "thumb_m.webp", "thumb_s.webp"]
    async with env.maker() as s:
        row = (await s.execute(select(GarmentImage))).scalar_one()
        assert row.raw_key is None and row.full_key.startswith(f"g/{g['id']}/")
        assert str(row.user_id) not in row.full_key  # keys carry no user id


async def test_stored_images_have_no_gps_or_exif_and_are_rotated(env: Env) -> None:
    h = await signin(env)
    raw = garment_image((320, 480), gps=True, exif_orientation=6)
    assert b"SecretPhoneMaker" in raw
    g = await add_garment(env, h, data=raw)
    assert (g["images"][0]["width"], g["images"][0]["height"]) == (480, 320)  # orientation applied
    for p in env.storage.root.rglob("*.webp"):
        blob = p.read_bytes()
        assert b"SecretPhoneMaker" not in blob and b"GPS" not in blob
        assert not webp(blob).getexif()


async def test_heic_photos_are_accepted_and_converted(env: Env) -> None:
    h = await signin(env)
    g = await create(env, h, content_type="image/heic", filename="IMG_0042.HEIC")
    assert await upload(env, g["upload"], garment_image(fmt="HEIF")) == 200
    assert (await complete(env, h, g)).status_code == 202
    done = (await env.client.get(f"/v1/garments/{g['id']}", headers=h)).json()
    assert done["images"][0]["status"] == "ready"
    full = await env.client.get(done["images"][0]["urls"]["full"])
    assert webp(full.content).format == "WEBP"


# ---- idempotency --------------------------------------------------------------------------------


async def test_create_is_idempotent_on_client_id(env: Env) -> None:
    h = await signin(env)
    first = await env.client.post("/v1/garments", headers=h, json={"client_id": "abcdefgh-1"})
    again = await env.client.post("/v1/garments", headers=h, json={"client_id": "abcdefgh-1"})
    assert first.status_code == 201 and again.status_code == 200
    a, b = first.json(), again.json()
    assert a["id"] == b["id"] and a["images"][0]["id"] == b["images"][0]["id"]
    assert b["upload"] is not None  # still waiting for the photo: a fresh ticket
    async with env.maker() as s:
        assert len((await s.execute(select(Garment))).scalars().all()) == 1


async def test_client_ids_are_scoped_per_user(env: Env) -> None:
    a, b = await signin(env, "a", "a@x.com"), await signin(env, "b", "b@x.com")
    ga = await create(env, a, "same-client-id")
    gb = await create(env, b, "same-client-id")
    assert ga["id"] != gb["id"]


async def test_complete_twice_processes_once(env: Env) -> None:
    h = await signin(env)
    g = await create(env, h)
    await upload(env, g["upload"], garment_image())
    assert (await complete(env, h, g)).status_code == 202
    assert (await complete(env, h, g)).status_code == 202
    assert [n for n, _, _ in env.queue.log].count("process_image") == 1
    assert [n for n, _, _ in env.queue.log].count("analyse_garment") == 1


async def test_no_ticket_after_the_photo_arrived(env: Env) -> None:
    h = await signin(env)
    g = await add_garment(env, h, "client-0002")
    again = await create(env, h, "client-0002")
    assert again["id"] == g["id"] and again["upload"] is None


async def test_fresh_upload_url_only_while_waiting(env: Env) -> None:
    h = await signin(env)
    g = await create(env, h)
    iid = g["images"][0]["id"]
    r = await env.client.post(f"/v1/garments/{g['id']}/images/{iid}/upload-url", headers=h)
    assert r.status_code == 200 and r.json()["image_id"] == iid
    await upload(env, r.json(), garment_image())
    await complete(env, h, g)
    late = await env.client.post(f"/v1/garments/{g['id']}/images/{iid}/upload-url", headers=h)
    assert late.status_code == 409 and late.json()["error"]["code"] == "upload_already_completed"


# ---- validation by content ----------------------------------------------------------------------


async def test_complete_before_upload_is_a_retryable_conflict(env: Env) -> None:
    h = await signin(env)
    g = await create(env, h)
    r = await complete(env, h, g)
    assert r.status_code == 409 and r.json()["error"]["code"] == "upload_missing"
    assert await upload(env, g["upload"], garment_image()) == 200
    assert (await complete(env, h, g)).status_code == 202  # works after the retry


async def test_a_web_page_renamed_to_jpg_is_rejected_and_deleted(env: Env) -> None:
    h = await signin(env)
    g = await create(env, h, filename="photo.jpg")
    await upload(env, g["upload"], b"<html><script>alert(1)</script></html>" * 5)
    r = await complete(env, h, g)
    assert r.status_code == 415 and r.json()["error"]["code"] == "unsupported_media"
    assert not list(env.storage.root.rglob("raw"))
    detail = (await env.client.get(f"/v1/garments/{g['id']}", headers=h)).json()
    assert detail["images"][0]["status"] == "failed"
    assert detail["analysis"]["status"] == "needs_manual"


async def test_declared_size_over_the_limit_is_refused_before_uploading(env: Env) -> None:
    h = await signin(env)
    r = await env.client.post(
        "/v1/garments", headers=h, json={"client_id": "big-file-1", "size_bytes": 50 * 1024 * 1024}
    )
    assert r.status_code == 413 and r.json()["error"]["code"] == "file_too_large"


async def test_oversize_object_is_rejected_at_completion_even_if_it_got_through(env: Env) -> None:
    get_settings().upload_max_bytes = 1000
    h = await signin(env)
    g = await create(env, h)
    # simulate a storage layer that did not enforce the size (e.g. a misconfigured bucket)
    await env.storage.put(
        f"g/{g['id']}/{g['images'][0]['id']}/raw", garment_image((400, 400)), "image/jpeg"
    )
    r = await complete(env, h, g)
    assert r.status_code == 413 and r.json()["error"]["code"] == "file_too_large"
    assert await env.storage.head(f"g/{g['id']}/{g['images'][0]['id']}/raw") is None


async def test_corrupt_image_with_valid_magic_bytes_fails_in_the_worker(env: Env) -> None:
    h = await signin(env)
    g = await create(env, h)
    good = garment_image()
    await upload(env, g["upload"], good[:200] + b"\x00" * 300)
    assert (await complete(env, h, g)).status_code == 202
    detail = (await env.client.get(f"/v1/garments/{g['id']}", headers=h)).json()
    assert (
        detail["images"][0]["status"] == "failed"
        and "image_invalid" in detail["images"][0]["error"]
    )
    assert detail["analysis"]["status"] == "needs_manual"


async def test_huge_dimensions_are_rejected_by_the_worker(env: Env) -> None:
    h = await signin(env)
    g = await create(env, h, content_type="image/png", filename="x.png")
    await upload(env, g["upload"], garment_image((9000, 64), fmt="PNG"))
    assert (await complete(env, h, g)).status_code == 202
    detail = (await env.client.get(f"/v1/garments/{g['id']}", headers=h)).json()
    assert detail["images"][0]["status"] == "failed" and "too large" in detail["images"][0]["error"]


# ---- abuse limits and entitlements --------------------------------------------------------------


async def test_creation_is_rate_limited_per_user(env: Env) -> None:
    get_settings().upload_rate_per_hour = 3
    h, other = await signin(env), await signin(env, "u2", "u2@x.com")
    for i in range(3):
        await create(env, h, f"rate-limit-{i}")
    r = await env.client.post("/v1/garments", headers=h, json={"client_id": "rate-limit-9"})
    assert r.status_code == 429 and r.json()["error"]["code"] == "rate_limited"
    assert int(r.headers["Retry-After"]) >= 1
    assert (
        await env.client.post("/v1/garments", headers=other, json={"client_id": "other-user-1"})
    ).status_code == 201


async def test_free_item_limit_is_enforced_by_the_server_and_comes_from_remote_config(
    env: Env,
) -> None:
    async with env.maker() as s:
        await set_flag(s, get_redis(), "closet_item_limit_free", 2)
    h = await signin(env)
    await create(env, h, "limit-item-1")
    await create(env, h, "limit-item-2")
    r = await env.client.post("/v1/garments", headers=h, json={"client_id": "limit-item-3"})
    assert r.status_code == 403
    err = r.json()["error"]
    assert err["code"] == "item_limit_reached"
    assert err["details"] == {"limit": 2, "used": 2, "remaining": 0, "requested": 1, "plan": "free"}
    # a retry of an existing item is not a new item
    assert (
        await env.client.post("/v1/garments", headers=h, json={"client_id": "limit-item-2"})
    ).status_code == 200

    async with env.maker() as s:
        await set_flag(s, get_redis(), "closet_item_limit_free", 5)  # no release needed
    assert (
        await env.client.post("/v1/garments", headers=h, json={"client_id": "limit-item-3"})
    ).status_code == 201


async def test_entitlements_endpoint(env: Env) -> None:
    h = await signin(env)
    await create(env, h, "ent-item-01")
    e = (await env.client.get("/v1/entitlements", headers=h)).json()
    assert e == {
        "plan": "free", "closet_item_limit": 30, "closet_items_used": 1,
        "closet_items_remaining": 29, "bulk_add_enabled": True, "bulk_max": 20,
    }  # fmt: skip


# ---- privacy between users ----------------------------------------------------------------------


async def test_other_users_cannot_see_touch_or_complete_my_garments(env: Env) -> None:
    a, b = await signin(env, "a", "a@x.com"), await signin(env, "b", "b@x.com")
    g = await add_garment(env, a, "mine-0001")
    iid = g["images"][0]["id"]
    for method, path in (
        ("GET", f"/v1/garments/{g['id']}"),
        ("POST", f"/v1/garments/{g['id']}/images/{iid}/upload-url"),
        ("POST", f"/v1/garments/{g['id']}/images/{iid}/complete"),
    ):
        r = await env.client.request(method, path, headers=b)
        assert r.status_code == 404 and r.json()["error"]["code"] == "garment_not_found", path
    # same answer for an id that never existed: no existence leak
    ghost = await env.client.get(f"/v1/garments/{uuid.uuid4()}", headers=b)
    assert (
        ghost.status_code == 404
        and ghost.json()["error"]
        == (await env.client.get(f"/v1/garments/{g['id']}", headers=b)).json()["error"]
    )


async def test_signed_urls_are_short_lived(env: Env) -> None:
    h = await signin(env)
    g = await add_garment(env, h)
    url = g["images"][0]["urls"]["m"]
    token = url.split("/storage/read/")[1]
    claims = env.storage.verify(token, method="GET")
    ttl = claims["e"] - time.time()
    assert 0 < ttl <= get_settings().read_url_ttl_seconds + 2
    assert (await env.client.get(url)).status_code == 200
    with pytest.raises(Exception, match="expired"):
        env.storage.verify(
            token, method="GET", now=time.time() + get_settings().read_url_ttl_seconds + 5
        )


# ---- the worker: retries, dead letters, idempotency --------------------------------------------


async def test_transient_storage_failure_is_retried_then_succeeds(
    env: Env, monkeypatch: pytest.MonkeyPatch
) -> None:
    h = await signin(env)
    g = await create(env, h)
    await upload(env, g["upload"], garment_image())
    real_put, calls = env.storage.put, {"n": 0}

    async def flaky_put(key: str, data: bytes, content_type: str | None = None) -> None:
        calls["n"] += 1
        if calls["n"] <= 1:
            raise OSError("disk hiccup")
        await real_put(key, data, content_type)

    monkeypatch.setattr(env.storage, "put", flaky_put)
    assert (await complete(env, h, g)).status_code == 202
    detail = (await env.client.get(f"/v1/garments/{g['id']}", headers=h)).json()
    assert detail["images"][0]["status"] == "ready"
    assert ("process_image", (g["images"][0]["id"],), "ok") in env.queue.log


async def test_exhausted_retries_dead_letter_the_job_and_mark_manual_entry(
    env: Env, monkeypatch: pytest.MonkeyPatch
) -> None:
    h = await signin(env)
    g = await create(env, h)
    await upload(env, g["upload"], garment_image())

    async def broken_put(key: str, data: bytes, content_type: str | None = None) -> None:
        raise OSError("storage down")

    monkeypatch.setattr(env.storage, "put", broken_put)
    assert (await complete(env, h, g)).status_code == 202
    detail = (await env.client.get(f"/v1/garments/{g['id']}", headers=h)).json()
    assert detail["images"][0]["status"] == "failed"
    assert detail["analysis"]["status"] == "needs_manual"
    assert env.queue.log[-1][2] == "dead"
    entries = await get_redis().lrange(DLQ_KEY, 0, -1)
    assert len(entries) == 1 and "process_image" in entries[0] and "retries exhausted" in entries[0]


async def test_running_the_job_again_changes_nothing(env: Env) -> None:
    h = await signin(env)
    g = await add_garment(env, h)
    from app.queue.core import execute

    before = [p.read_bytes() for p in sorted(env.storage.root.rglob("*.webp"))]
    out = await execute(
        "process_image", (g["images"][0]["id"],), env.deps, try_number=1, max_tries=3
    )
    assert out.kind == "ok"
    assert [p.read_bytes() for p in sorted(env.storage.root.rglob("*.webp"))] == before


async def test_deleted_garment_while_queued_is_a_noop(env: Env) -> None:
    from app.queue.core import execute

    out = await execute("process_image", (str(uuid.uuid4()),), env.deps, try_number=1, max_tries=3)
    assert out.kind == "ok"
