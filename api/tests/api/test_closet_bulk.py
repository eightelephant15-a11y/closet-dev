"""POST /v1/garments/bulk: the multi-select "add up to 20" flow."""

import pytest

from app.core.redis import get_redis
from app.services.flags import set_flag
from tests.closet_helpers import complete, signin, upload
from tests.conftest import Env
from tests.imagegen import garment_image


async def flag(env: Env, key: str, value: object) -> None:
    async with env.maker() as s:
        await set_flag(s, get_redis(), key, value)  # type: ignore[arg-type]


def items(n: int, start: int = 0) -> list[dict[str, str]]:
    return [
        {"client_id": f"bulk-{i:04d}", "filename": f"shirt_{i}.jpg", "content_type": "image/jpeg"}
        for i in range(start, start + n)
    ]


async def post(env: Env, h: dict[str, str], body: list[dict[str, str]]):  # type: ignore[no-untyped-def]
    return await env.client.post("/v1/garments/bulk", headers=h, json={"items": body})


async def test_bulk_creates_every_item_with_its_own_upload_ticket(env: Env) -> None:
    h = await signin(env)
    r = await post(env, h, items(5))
    assert r.status_code == 201, r.text
    out = r.json()["items"]
    assert [g["client_id"] for g in out] == [f"bulk-{i:04d}" for i in range(5)]
    assert len({g["upload"]["image_id"] for g in out}) == 5
    assert all(g["upload"]["method"] == "PUT" for g in out)
    # every ticket works and every photo is analysed like a single add
    for g in out:
        assert await upload(env, g["upload"], garment_image()) == 200
        assert (await complete(env, h, g)).status_code == 202
    page = (await env.client.get("/v1/garments", headers=h)).json()
    assert page["total"] == 5
    assert {i["analysis_status"] for i in page["items"]} == {"done"}


async def test_bulk_is_capped_at_twenty(env: Env) -> None:
    h = await signin(env)
    assert (await post(env, h, items(20))).status_code == 201
    r = await post(env, h, items(21, start=100))
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "bulk_too_large"
    assert r.json()["error"]["details"]["max"] == 20
    assert (await env.client.get("/v1/garments/summary", headers=h)).json()["total"] == 20


async def test_bulk_is_all_or_nothing_against_the_item_limit(env: Env) -> None:
    h = await signin(env)
    await flag(env, "closet_item_limit_free", 7)
    assert (await post(env, h, items(5))).status_code == 201
    r = await post(env, h, items(3, start=50))  # 5 + 3 > 7
    assert r.status_code == 403
    err = r.json()["error"]
    assert err["code"] == "item_limit_reached"
    assert err["details"]["remaining"] == 2
    summary = (await env.client.get("/v1/garments/summary", headers=h)).json()
    assert summary["total"] == 5, "nothing from the refused batch was created"


async def test_a_retried_batch_does_not_duplicate_or_double_count(env: Env) -> None:
    h = await signin(env)
    await flag(env, "closet_item_limit_free", 4)
    first = await post(env, h, items(4))
    assert first.status_code == 201
    again = await post(env, h, items(4))  # the response was lost; the phone retries
    assert again.status_code == 201, again.text
    assert [g["id"] for g in again.json()["items"]] == [g["id"] for g in first.json()["items"]]
    assert (await env.client.get("/v1/garments/summary", headers=h)).json()["total"] == 4


async def test_duplicate_client_ids_in_one_batch_are_refused(env: Env) -> None:
    h = await signin(env)
    body = items(2)
    body[1]["client_id"] = body[0]["client_id"]
    r = await post(env, h, body)
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "duplicate_client_id"


async def test_bulk_can_be_switched_off_by_flag(env: Env) -> None:
    h = await signin(env)
    await flag(env, "closet_bulk_add_enabled", False)
    r = await post(env, h, items(2))
    assert r.status_code == 403
    assert r.json()["error"]["code"] == "bulk_disabled"
    # single add is unaffected
    one = await env.client.post(
        "/v1/garments", headers=h, json={"client_id": "single-0001", "content_type": "image/jpeg"}
    )
    assert one.status_code == 201
    ent = (await env.client.get("/v1/entitlements", headers=h)).json()
    assert ent["bulk_add_enabled"] is False


async def test_bulk_counts_against_the_upload_rate_limit(env: Env) -> None:
    from app.core.config import get_settings

    s = get_settings()
    saved = s.upload_rate_per_hour
    s.upload_rate_per_hour = 6
    try:
        h = await signin(env)
        assert (await post(env, h, items(5))).status_code == 201
        r = await post(env, h, items(5, start=10))
        assert r.status_code == 429
        assert r.headers.get("retry-after")
    finally:
        s.upload_rate_per_hour = saved


async def test_two_users_can_use_the_same_client_ids(env: Env) -> None:
    a = await signin(env, "a1", "a@example.com")
    b = await signin(env, "b1", "b@example.com")
    ra, rb = await post(env, a, items(3)), await post(env, b, items(3))
    assert ra.status_code == rb.status_code == 201
    assert not {g["id"] for g in ra.json()["items"]} & {g["id"] for g in rb.json()["items"]}
    for h in (a, b):
        assert (await env.client.get("/v1/garments/summary", headers=h)).json()["total"] == 3


@pytest.mark.parametrize("n", [0])
async def test_an_empty_batch_is_a_validation_error(env: Env, n: int) -> None:
    h = await signin(env)
    r = await post(env, h, items(n))
    assert r.status_code == 422
