import statistics
import time
import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from sqlalchemy import select

from app.core.config import get_settings
from app.core.redis import get_redis
from app.data.sample_closet import SAMPLE_GARMENTS
from app.domain import taxonomy as tx
from app.models import (
    AnalysisJob,
    AnalysisStatus,
    Availability,
    Garment,
    GarmentCorrection,
    GarmentImage,
    ImageStatus,
    User,
)
from app.services.flags import set_flag
from tests.closet_helpers import add_garment, signin
from tests.conftest import Env


async def user_id(env: Env, h: dict[str, str]) -> uuid.UUID:
    return uuid.UUID((await env.client.get("/v1/me", headers=h)).json()["id"])


async def seed(
    env: Env, uid: uuid.UUID, specs: list[dict[str, Any]], start: int = 0
) -> list[uuid.UUID]:
    """Inserts garments directly (fast) with deterministic, increasing created_at."""
    base = datetime(2026, 1, 1, tzinfo=UTC)
    ids: list[uuid.UUID] = []
    async with env.maker() as s:
        for n, spec in enumerate(specs, start):
            fields = {"seasons": ["spring"], "pattern": "solid", "formality": 2} | spec
            g = Garment(
                id=uuid.uuid4(),
                user_id=uid,
                client_id=f"seed-{uid.hex[:6]}-{n:05d}",
                analysis_status=AnalysisStatus.done,
                created_at=base + timedelta(minutes=n),
                updated_at=base + timedelta(minutes=n),
                **fields,
            )
            s.add(g)
            ids.append(g.id)
        await s.commit()
    return ids


def g(cat: str, sub: str, color: str, **kw: Any) -> dict[str, Any]:
    return {"category": cat, "subcategory": sub, "primary_color": color, **kw}


CLOSET = [
    g("top", "t_shirt", "white", formality=1, seasons=["summer"], brand="Acme"),
    g("top", "shirt", "navy", formality=3, seasons=["spring", "autumn"], secondary_color="white", pattern="striped"),
    g("top", "sweater", "grey", formality=2, seasons=["winter"], material="wool", favorite=True),
    g("bottom", "jeans", "navy", formality=2, seasons=["spring", "summer", "autumn", "winter"], notes="my favourite pair"),
    g("bottom", "trousers", "black", formality=4),
    g("footwear", "sneakers", "white", formality=2),
    g("outerwear", "blazer", "navy", formality=4, seasons=["spring", "autumn"]),
    g("dress", "casual_dress", "red", formality=3, seasons=["summer"]),
]  # fmt: skip


async def listing(env: Env, h: dict[str, str], **params: Any) -> dict[str, Any]:
    r = await env.client.get("/v1/garments", headers=h, params=params)
    assert r.status_code == 200, r.text
    return r.json()


def subs(page: dict[str, Any]) -> list[str]:
    return [i["subcategory"] for i in page["items"]]


@pytest.fixture
async def closet(env: Env) -> tuple[dict[str, str], uuid.UUID]:
    h = await signin(env)
    uid = await user_id(env, h)
    await seed(env, uid, CLOSET)
    return h, uid


# ---- filters ---------------------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("params", "expected"),
    [
        ({"category": "top"}, {"t_shirt", "shirt", "sweater"}),
        ({"subcategory": "jeans"}, {"jeans"}),
        ({"color": "navy"}, {"shirt", "jeans", "blazer"}),
        (
            {"color": "white"},
            {"t_shirt", "shirt", "sneakers"},
        ),  # the shirt's *secondary* colour counts
        ({"season": "summer"}, {"t_shirt", "jeans", "casual_dress"}),
        ({"season": "winter"}, {"sweater", "jeans"}),
        ({"formality_min": 4}, {"trousers", "blazer"}),
        ({"formality_max": 1}, {"t_shirt"}),
        (
            {"formality_min": 2, "formality_max": 3},
            {"shirt", "sweater", "jeans", "sneakers", "casual_dress"},
        ),
        ({"favorite": "true"}, {"sweater"}),
        ({"category": "top", "color": "navy"}, {"shirt"}),  # filters combine with AND
        ({"category": "top", "season": "winter", "favorite": "true"}, {"sweater"}),
    ],
)
async def test_filters(
    env: Env, closet: tuple[dict[str, str], uuid.UUID], params: dict[str, Any], expected: set[str]
) -> None:
    h, _ = closet
    page = await listing(env, h, **params)
    assert set(subs(page)) == expected and page["total"] == len(expected)


@pytest.mark.parametrize(
    ("q", "expected"),
    [
        ("navy", {"shirt", "jeans", "blazer"}),
        ("tee", {"t_shirt"}),
        ("shirt", {"t_shirt", "shirt"}),  # matches by label, so T-shirt too
        ("wool", {"sweater"}),
        ("acme", {"t_shirt"}),  # brand, case-insensitive
        ("favourite pair", {"jeans"}),  # notes, every word must match
        ("navy shirt", {"shirt"}),
        ("striped", {"shirt"}),
        ("summer", {"t_shirt", "jeans", "casual_dress"}),
        ("dress", {"casual_dress"}),
        ("nothing like this", set()),
        ("100%", set()),  # LIKE wildcards are escaped, not interpreted
        ("_", set()),
    ],
)
async def test_search(
    env: Env, closet: tuple[dict[str, str], uuid.UUID], q: str, expected: set[str]
) -> None:
    h, _ = closet
    assert set(subs(await listing(env, h, q=q))) == expected


async def test_invalid_filter_values_are_validation_errors(
    env: Env, closet: tuple[dict[str, str], uuid.UUID]
) -> None:
    h, _ = closet
    for params in (
        {"formality_min": 9},
        {"limit": 0},
        {"limit": 101},
        {"sort": "random"},
        {"thumb": "xl"},
        {"archived": "maybe"},
        {"availability": "gone"},
    ):
        r = await env.client.get("/v1/garments", headers=h, params=params)
        assert r.status_code == 422, params


# ---- sorting and cursor pagination ---------------------------------------------------------------


@pytest.mark.parametrize(
    "sort", ["created_desc", "created_asc", "updated_desc", "formality_asc", "formality_desc"]
)
async def test_every_sort_pages_without_gaps_or_repeats(env: Env, sort: str) -> None:
    h = await signin(env)
    uid = await user_id(env, h)
    await seed(env, uid, [g("top", "t_shirt", "white", formality=1 + n % 5) for n in range(53)])
    seen: list[dict[str, Any]] = []
    cursor = None
    pages = 0
    while True:
        page = await listing(env, h, sort=sort, limit=10, **({"cursor": cursor} if cursor else {}))
        seen += page["items"]
        pages += 1
        cursor = page["next_cursor"]
        assert page["total"] == 53
        if not cursor:
            break
    assert pages == 6 and len(seen) == 53 and len({i["id"] for i in seen}) == 53
    key = {
        "created_desc": lambda i: i["id"],  # checked below via timestamps
        "formality_asc": lambda i: i["formality"],
        "formality_desc": lambda i: -i["formality"],
    }.get(sort)
    if key and sort.startswith("formality"):
        values = [key(i) for i in seen]
        assert values == sorted(values)
    if sort in ("created_desc", "updated_desc"):
        stamps = [i["updated_at"] for i in seen]
        assert stamps == sorted(stamps, reverse=True)
    if sort == "created_asc":
        stamps = [i["updated_at"] for i in seen]
        assert stamps == sorted(stamps)


async def test_cursor_is_bound_to_its_sort_and_must_be_valid(
    env: Env, closet: tuple[dict[str, str], uuid.UUID]
) -> None:
    h, _ = closet
    first = await listing(env, h, limit=3)
    assert first["next_cursor"] and len(first["items"]) == 3
    wrong = await env.client.get(
        "/v1/garments", headers=h, params={"cursor": first["next_cursor"], "sort": "formality_asc"}
    )
    assert wrong.status_code == 422 and wrong.json()["error"]["code"] == "invalid_cursor"
    junk = await env.client.get("/v1/garments", headers=h, params={"cursor": "not-a-cursor"})
    assert junk.status_code == 422 and junk.json()["error"]["code"] == "invalid_cursor"


async def test_pagination_is_stable_when_items_are_added_meanwhile(env: Env) -> None:
    h = await signin(env)
    uid = await user_id(env, h)
    await seed(env, uid, [g("top", "t_shirt", "white") for _ in range(12)])
    first = await listing(env, h, limit=6)
    await seed(
        env, uid, [g("top", "shirt", "navy") for _ in range(3)], start=1000
    )  # newer items arrive
    second = await listing(env, h, limit=6, cursor=first["next_cursor"])
    assert not {i["id"] for i in first["items"]} & {i["id"] for i in second["items"]}


# ---- archived / availability / outfits exclusion -------------------------------------------------


async def test_archive_hides_items_and_flags_them_for_phase_3(
    env: Env, closet: tuple[dict[str, str], uuid.UUID]
) -> None:
    h, _ = closet
    gid = (await listing(env, h, subcategory="jeans"))["items"][0]["id"]
    r = await env.client.patch(f"/v1/garments/{gid}", headers=h, json={"archived": True})
    assert (
        r.status_code == 200
        and r.json()["archived"] is True
        and r.json()["excluded_from_outfits"] is True
    )
    assert "jeans" not in subs(await listing(env, h))
    assert subs(await listing(env, h, archived="only")) == ["jeans"]
    assert "jeans" in subs(await listing(env, h, archived="include"))
    back = await env.client.patch(f"/v1/garments/{gid}", headers=h, json={"archived": False})
    assert back.json()["archived"] is False and back.json()["excluded_from_outfits"] is False


@pytest.mark.parametrize("state", ["laundry", "lent", "repair"])
async def test_unavailable_items_are_flagged_and_filterable(
    env: Env, closet: tuple[dict[str, str], uuid.UUID], state: str
) -> None:
    h, _ = closet
    gid = (await listing(env, h, subcategory="blazer"))["items"][0]["id"]
    until = (date.today() + timedelta(days=5)).isoformat()
    r = await env.client.patch(
        f"/v1/garments/{gid}", headers=h, json={"availability": state, "unavailable_until": until}
    )
    body = r.json()
    assert (
        r.status_code == 200
        and body["availability"] == state
        and body["unavailable_until"] == until
    )
    assert body["excluded_from_outfits"] is True
    flagged = (await listing(env, h, availability=state))["items"]
    assert [i["id"] for i in flagged] == [gid] and flagged[0]["excluded_from_outfits"] is True
    ok = await env.client.patch(
        f"/v1/garments/{gid}", headers=h, json={"availability": "available"}
    )
    assert ok.json()["unavailable_until"] is None and ok.json()["excluded_from_outfits"] is False


async def test_return_date_cannot_be_in_the_past(
    env: Env, closet: tuple[dict[str, str], uuid.UUID]
) -> None:
    h, _ = closet
    gid = (await listing(env, h, subcategory="blazer"))["items"][0]["id"]
    r = await env.client.patch(
        f"/v1/garments/{gid}",
        headers=h,
        json={
            "availability": "lent",
            "unavailable_until": (date.today() - timedelta(days=1)).isoformat(),
        },
    )
    assert (
        r.status_code == 422
        and r.json()["error"]["details"]["errors"][0]["field"] == "unavailable_until"
    )


async def test_unarchiving_into_a_full_closet_is_blocked(env: Env) -> None:
    async with env.maker() as s:
        await set_flag(s, get_redis(), "closet_item_limit_free", 2)
    h = await signin(env)
    uid = await user_id(env, h)
    a, b = await seed(env, uid, [g("top", "t_shirt", "white"), g("top", "shirt", "navy")])
    assert (
        await env.client.patch(f"/v1/garments/{a}", headers=h, json={"archived": True})
    ).status_code == 200
    await seed(env, uid, [g("bottom", "jeans", "navy")], start=100)  # fills the freed slot
    r = await env.client.patch(f"/v1/garments/{a}", headers=h, json={"archived": False})
    assert r.status_code == 403 and r.json()["error"]["code"] == "item_limit_reached"
    assert b  # untouched


async def test_review_state_and_filter(env: Env, closet: tuple[dict[str, str], uuid.UUID]) -> None:
    h, _ = closet
    assert (await listing(env, h, reviewed="false"))["total"] == len(CLOSET)
    gid = (await listing(env, h, subcategory="jeans"))["items"][0]["id"]
    assert (
        await env.client.patch(f"/v1/garments/{gid}", headers=h, json={"reviewed": True})
    ).json()["reviewed"] is True
    assert (await listing(env, h, reviewed="false"))["total"] == len(CLOSET) - 1


# ---- thumbnails in the list ----------------------------------------------------------------------


async def test_list_returns_the_requested_thumbnail_size_and_a_stable_cache_key(env: Env) -> None:
    h = await signin(env)
    g1 = await add_garment(env, h, "list-thumb-1", "navy_jeans.jpg")
    for size, side in (("s", 200), ("m", 600), ("l", 1200)):
        item = (await listing(env, h, thumb=size))["items"][0]
        got = await env.client.get(item["thumb_url"])
        from io import BytesIO

        from PIL import Image

        assert Image.open(BytesIO(got.content)).size == (side, side)
    a = (await listing(env, h))["items"][0]
    b = (await listing(env, h))["items"][0]
    assert a["image_version"] == b["image_version"] and a["image_version"], (
        "cache key must not change per request"
    )
    assert a["thumb_url"] != "" and g1["id"] == a["id"]


async def test_items_without_a_ready_photo_have_no_thumbnail(
    env: Env, closet: tuple[dict[str, str], uuid.UUID]
) -> None:
    h, _ = closet
    assert all(
        i["thumb_url"] is None and i["image_version"] is None
        for i in (await listing(env, h))["items"]
    )


# ---- privacy -----------------------------------------------------------------------------------------


async def test_a_user_never_sees_anyone_elses_closet(
    env: Env, closet: tuple[dict[str, str], uuid.UUID]
) -> None:
    mine, _ = closet
    other = await signin(env, "other", "other@x.com")
    page = await listing(env, other)
    assert page["items"] == [] and page["total"] == 0
    for params in (
        {"q": "navy"},
        {"category": "top"},
        {"archived": "include"},
        {"color": "navy", "sort": "formality_desc"},
    ):
        assert (await listing(env, other, **params))["total"] == 0
    summary = (await env.client.get("/v1/garments/summary", headers=other)).json()
    assert summary["total"] == 0 and summary["counts"]["by_category"] == {}
    mine_page = await listing(env, mine)
    assert mine_page["total"] == len(CLOSET)
    # a cursor from my list cannot be used to read yours
    cur = (await listing(env, mine, limit=2))["next_cursor"]
    assert (await listing(env, other, limit=2, cursor=cur))["items"] == []


# ---- summary -------------------------------------------------------------------------------------------


async def test_summary_counts_for_the_meter_and_header(
    env: Env, closet: tuple[dict[str, str], uuid.UUID]
) -> None:
    h, _ = closet
    jeans = (await listing(env, h, subcategory="jeans"))["items"][0]["id"]
    blazer = (await listing(env, h, subcategory="blazer"))["items"][0]["id"]
    await env.client.patch(f"/v1/garments/{jeans}", headers=h, json={"availability": "laundry"})
    await env.client.patch(f"/v1/garments/{blazer}", headers=h, json={"archived": True})
    s = (await env.client.get("/v1/garments/summary", headers=h)).json()
    assert s["total"] == 7 and s["archived"] == 1 and s["favorites"] == 1 and s["needs_review"] == 7
    assert s["counts"]["by_category"] == {"top": 3, "bottom": 2, "footwear": 1, "dress": 1}
    assert s["available_counts"]["by_category"] == {
        "top": 3,
        "bottom": 1,
        "footwear": 1,
        "dress": 1,
    }  # jeans in the laundry
    assert (
        s["counts"]["by_subcategory"]["jeans"] == 1
        and "jeans" not in s["available_counts"]["by_subcategory"]
    )
    assert (s["closet_item_limit"], s["closet_items_used"], s["closet_items_remaining"]) == (
        30,
        7,
        23,
    )


# ---- delete ----------------------------------------------------------------------------------------------


async def test_delete_removes_rows_and_every_stored_image(env: Env) -> None:
    h = await signin(env)
    keep = await add_garment(env, h, "keep-0001", "white_tee.jpg")
    gone = await add_garment(env, h, "gone-0001", "navy_jeans.jpg")
    url = gone["images"][0]["urls"]["m"]
    assert (await env.client.get(url)).status_code == 200
    await env.client.patch(
        f"/v1/garments/{gone['id']}", headers=h, json={"primary_color": "red"}
    )  # creates a correction row

    assert (await env.client.delete(f"/v1/garments/{gone['id']}", headers=h)).status_code == 204
    files = {p.relative_to(env.storage.root).parts[1] for p in env.storage.root.rglob("*.webp")}
    assert files == {keep["id"]}, "only the other garment's images remain"
    assert (await env.client.get(url)).status_code == 404, "old signed URLs stop working"
    assert (await env.client.get(f"/v1/garments/{gone['id']}", headers=h)).status_code == 404
    async with env.maker() as s:
        for model in (GarmentImage, GarmentCorrection, AnalysisJob):
            rows = (await s.execute(select(model))).scalars().all()
            assert all(r.garment_id != uuid.UUID(gone["id"]) for r in rows), model
        assert len((await s.execute(select(Garment))).scalars().all()) == 1
    assert (await env.client.delete(f"/v1/garments/{gone['id']}", headers=h)).status_code == 404


async def test_deleting_someone_elses_garment_is_a_404_and_changes_nothing(env: Env) -> None:
    a, b = await signin(env, "a", "a@x.com"), await signin(env, "b", "b@x.com")
    g1 = await add_garment(env, a)
    assert (await env.client.delete(f"/v1/garments/{g1['id']}", headers=b)).status_code == 404
    assert (await env.client.get(f"/v1/garments/{g1['id']}", headers=a)).status_code == 200
    assert list(env.storage.root.rglob("*.webp"))


async def test_if_storage_cannot_delete_the_row_is_kept_so_nothing_is_orphaned(
    env: Env, monkeypatch: pytest.MonkeyPatch
) -> None:
    h = await signin(env)
    g1 = await add_garment(env, h)

    async def broken(prefix: str) -> int:
        raise OSError("bucket unreachable")

    monkeypatch.setattr(env.storage, "delete_prefix", broken)
    r = await env.client.delete(f"/v1/garments/{g1['id']}", headers=h)
    assert r.status_code == 503 and r.json()["error"]["code"] == "storage_unavailable"
    monkeypatch.undo()
    assert (await env.client.get(f"/v1/garments/{g1['id']}", headers=h)).status_code == 200
    assert (
        await env.client.delete(f"/v1/garments/{g1['id']}", headers=h)
    ).status_code == 204  # retry works


async def test_deleting_frees_an_item_slot(env: Env) -> None:
    async with env.maker() as s:
        await set_flag(s, get_redis(), "closet_item_limit_free", 1)
    h = await signin(env)
    first = await env.client.post("/v1/garments", headers=h, json={"client_id": "slot-0000001"})
    assert (
        await env.client.post("/v1/garments", headers=h, json={"client_id": "slot-0000002"})
    ).status_code == 403
    await env.client.delete(f"/v1/garments/{first.json()['id']}", headers=h)
    assert (
        await env.client.post("/v1/garments", headers=h, json={"client_id": "slot-0000002"})
    ).status_code == 201


# ---- sample closet (guests) ------------------------------------------------------------------------------------


async def test_sample_closet_is_seeded_once_and_does_not_use_item_slots(env: Env) -> None:
    h = await signin(env)
    first = await env.client.post("/v1/garments/sample", headers=h)
    assert first.status_code == 201 and len(first.json()) == len(SAMPLE_GARMENTS) == 16
    again = await env.client.post("/v1/garments/sample", headers=h)
    assert again.status_code == 200 and {x["id"] for x in again.json()} == {
        x["id"] for x in first.json()
    }
    ent = (await env.client.get("/v1/entitlements", headers=h)).json()
    assert ent["closet_items_used"] == 0 and ent["closet_items_remaining"] == 30
    items = (await listing(env, h, limit=100))["items"]
    assert len(items) == 16 and all(
        i["is_sample"] and i["sample_asset"].startswith("sample_") for i in items
    )
    for g1 in first.json():  # taxonomy-valid, ready to use, no upload needed
        _, errors = tx.validate_fields(
            {
                k: g1[k]
                for k in (
                    "category",
                    "subcategory",
                    "primary_color",
                    "pattern",
                    "formality",
                    "seasons",
                )
            },
            require_core=True,
        )
        assert not errors and g1["analysis"]["status"] == "done" and g1["images"] == []
    cats = {x["category"] for x in first.json()}
    assert {"top", "bottom", "footwear", "dress", "outerwear"} <= cats


async def test_sample_closets_are_per_user(env: Env) -> None:
    a, b = await signin(env, "a", "a@x.com"), await signin(env, "b", "b@x.com")
    await env.client.post("/v1/garments/sample", headers=a)
    assert (await listing(env, b))["total"] == 0


# ---- performance budget ----------------------------------------------------------------------------------------


async def test_list_endpoint_p95_with_a_500_item_closet(
    env: Env, capsys: pytest.CaptureFixture[str]
) -> None:
    h = await signin(env)
    uid = await user_id(env, h)
    palette = list(tx.COLORS)
    specs = [
        g("top", "t_shirt", palette[n % len(palette)], formality=1 + n % 5, brand=f"Brand{n % 17}")
        for n in range(500)
    ]
    await seed(env, uid, specs)
    timings: list[float] = []
    for n in range(60):
        params: dict[str, Any] = [
            {},
            {"color": "navy"},
            {"q": "brand3 black"},
            {"sort": "formality_desc"},
        ][n % 4]
        t0 = time.perf_counter()
        r = await env.client.get("/v1/garments", headers=h, params={"limit": 40, **params})
        timings.append(time.perf_counter() - t0)
        assert r.status_code == 200
    timings.sort()
    p95 = timings[int(len(timings) * 0.95) - 1]
    with capsys.disabled():
        print(
            f"\nlist p50={statistics.median(timings) * 1000:.0f}ms p95={p95 * 1000:.0f}ms (500 items, 40 per page, SQLite in-process)"
        )
    assert p95 < 0.30, f"p95 {p95:.3f}s exceeds the 300 ms in-process budget"
    summary_t0 = time.perf_counter()
    assert (await env.client.get("/v1/garments/summary", headers=h)).json()["total"] == 500
    assert time.perf_counter() - summary_t0 < 0.3
    assert get_settings().upload_rate_per_hour > 0 and User and Availability and ImageStatus
