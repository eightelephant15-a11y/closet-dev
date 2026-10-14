import logging
from typing import Any

import pytest
from sqlalchemy import select

from app.core.config import get_settings
from app.core.redis import get_redis
from app.domain import taxonomy as tx
from app.models import AnalysisJob, Garment, GarmentCorrection, JobStatus
from app.queue.core import DLQ_KEY
from app.queue.deps import set_vision_factory
from app.vision import VisionError, VisionResult, VisionUsage
from tests.closet_helpers import add_garment, complete, create, signin, upload
from tests.conftest import Env
from tests.imagegen import garment_image


@pytest.fixture(autouse=True)
def _restore_settings():  # type: ignore[no-untyped-def]
    s = get_settings()
    saved = {
        k: getattr(s, k) for k in ("vision_daily_cap", "reanalyse_daily_cap", "queue_max_tries")
    }
    yield
    for k, v in saved.items():
        setattr(s, k, v)


def fields(**over: Any) -> dict[str, dict[str, Any]]:
    base = {
        "category": "top", "subcategory": "t_shirt", "primary_color": "white", "secondary_color": None,
        "pattern": "solid", "formality": 2, "seasons": ["spring", "summer"], "fit": "regular", "material": "cotton",
    }  # fmt: skip
    base.update(over)
    return {k: {"value": v, "confidence": 0.9} for k, v in base.items()}


class Spy:
    """A scripted vision provider that records how it was called."""

    name, model, version = "spy", "spy-1", "9"

    def __init__(self, *answers: Any) -> None:
        self.answers = list(answers)
        self.calls: list[dict[str, Any]] = []

    async def analyse(
        self,
        image: bytes,
        *,
        media_type: str,
        hint: str | None = None,
        department: str | None = None,
    ) -> VisionResult:
        self.calls.append(
            {"bytes": len(image), "media_type": media_type, "hint": hint, "department": department}
        )
        answer = self.answers.pop(0) if len(self.answers) > 1 else self.answers[0]
        if isinstance(answer, Exception):
            raise answer
        return VisionResult(fields=answer, provider=self.name, model=self.model, version=self.version,
                            usage=VisionUsage(input_tokens=1200, output_tokens=150, cost_usd=0.0021), latency_ms=420)  # fmt: skip


async def detail(env: Env, h: dict[str, str], gid: str) -> dict[str, Any]:
    return (await env.client.get(f"/v1/garments/{gid}", headers=h)).json()


# ---- the fake provider, end to end ---------------------------------------------------------------


async def test_analysis_fills_the_details_from_the_photo(env: Env) -> None:
    h = await signin(env)
    g = await add_garment(env, h, filename="navy_jeans_casual.jpg")
    assert g["analysis"]["status"] == "done"
    assert (g["category"], g["subcategory"], g["primary_color"], g["formality"]) == (
        "bottom",
        "jeans",
        "navy",
        2,
    )
    assert g["pattern"] == "solid" and g["seasons"]
    a = g["analysis"]
    assert (a["provider"], a["model"], a["version"], a["taxonomy_version"]) == (
        "fake",
        "fake-vision",
        "1",
        1,
    )
    assert set(a["fields"]) == set(tx.AI_FIELDS)
    assert all(0 <= v["confidence"] <= 1 for v in a["fields"].values())
    assert (
        a["fields"]["primary_color"]["value"] == "navy"
        and a["fields"]["primary_color"]["confidence"] > 0.9
    )


async def test_low_confidence_fields_are_flagged_for_the_review_screen(env: Env) -> None:
    h = await signin(env)
    vague = await add_garment(env, h, "vague-0001", "IMG_0042.jpg")
    assert {"primary_color", "subcategory"} <= set(vague["analysis"]["low_confidence_fields"])
    sure = await add_garment(env, h, "sure-0001", "white_polo_f3_summer.jpg")
    assert "primary_color" not in sure["analysis"]["low_confidence_fields"]
    low = await add_garment(env, h, "lowconf-0001", "black_blazer_lowconf.jpg")
    assert set(low["analysis"]["low_confidence_fields"]) == set(tx.AI_FIELDS)


async def test_results_are_always_valid_taxonomy_values(env: Env) -> None:
    h = await signin(env)
    for i, name in enumerate(
        ["x.jpg", "red_dress.jpg", "a_b_c.jpg", "plaid_scarf_winter.jpg", "TOP.jpg", "11.jpg"]
    ):
        g = await add_garment(
            env, h, f"valid-{i:04d}", name, garment_image(color=(i * 30 % 255, 40, 90))
        )
        values = {f: g["analysis"]["fields"][f]["value"] for f in tx.AI_FIELDS}
        _, errors = tx.validate_fields(values, require_core=True)
        assert not errors, (name, errors)


async def test_the_same_photo_gives_the_same_answer(env: Env) -> None:
    h = await signin(env)
    data = garment_image(color=(10, 200, 30))
    a = await add_garment(env, h, "deterministic-1", "unknown.jpg", data)
    b = await add_garment(env, h, "deterministic-2", "unknown.jpg", data)
    assert a["analysis"]["fields"] == b["analysis"]["fields"]


# ---- analyse once; re-analyse only on request ----------------------------------------------------


async def test_a_finished_analysis_is_never_repeated(env: Env) -> None:
    spy = Spy(fields())
    set_vision_factory(lambda name: spy)
    h = await signin(env)
    g = await add_garment(env, h)
    assert len(spy.calls) == 1
    from app.queue.core import execute

    for _ in range(3):  # duplicate deliveries, manual re-enqueues
        out = await execute(
            "analyse_garment",
            (g["id"], g["images"][0]["id"], "analyse"),
            env.deps,
            try_number=1,
            max_tries=3,
        )
        assert out.kind == "ok"
    assert len(spy.calls) == 1


async def test_reanalyse_keeps_the_users_edits_and_replaces_the_rest(env: Env) -> None:
    spy = Spy(
        fields(primary_color="white", pattern="solid"),
        fields(primary_color="grey", pattern="striped", subcategory="polo"),
    )
    set_vision_factory(lambda name: spy)
    h = await signin(env)
    g = await add_garment(env, h)
    assert g["primary_color"] == "white"
    # the user fixes the colour themselves
    assert (
        await env.client.patch(
            f"/v1/garments/{g['id']}", headers=h, json={"primary_color": "cream"}
        )
    ).status_code == 200

    r = await env.client.post(f"/v1/garments/{g['id']}/reanalyse", headers=h)
    assert r.status_code == 202
    d = await detail(env, h, g["id"])
    assert len(spy.calls) == 2
    assert d["primary_color"] == "cream", "the user's edit must survive a re-analysis"
    assert d["pattern"] == "striped" and d["subcategory"] == "polo", (
        "untouched fields take the new answer"
    )
    assert d["analysis"]["fields"]["primary_color"]["value"] == "grey", (
        "the AI's latest opinion is kept as the AI's"
    )


async def test_reanalyse_is_rate_limited_and_refuses_while_running(env: Env) -> None:
    get_settings().reanalyse_daily_cap = 1
    h = await signin(env)
    g = await add_garment(env, h)
    assert (
        await env.client.post(f"/v1/garments/{g['id']}/reanalyse", headers=h)
    ).status_code == 202
    limited = await env.client.post(f"/v1/garments/{g['id']}/reanalyse", headers=h)
    assert limited.status_code == 429 and limited.json()["error"]["code"] == "rate_limited"

    env.queue.paused = True
    fresh = await create(env, h, "pending-0001")
    assert (await env.client.post(f"/v1/garments/{fresh['id']}/reanalyse", headers=h)).json()[
        "error"
    ]["code"] == "image_not_ready"


async def test_reanalyse_of_someone_elses_garment_is_a_404(env: Env) -> None:
    a, b = await signin(env, "a", "a@x.com"), await signin(env, "b", "b@x.com")
    g = await add_garment(env, a)
    assert (
        await env.client.post(f"/v1/garments/{g['id']}/reanalyse", headers=b)
    ).status_code == 404


# ---- failures -------------------------------------------------------------------------------------


async def test_invalid_model_output_is_never_stored(env: Env) -> None:
    bad = fields(primary_color="chartreuse")
    spy = Spy(bad)
    set_vision_factory(lambda name: spy)
    h = await signin(env)
    g = await add_garment(env, h)
    assert len(spy.calls) == get_settings().queue_max_tries  # retried, then given up
    assert g["analysis"]["status"] == "needs_manual"
    assert g["primary_color"] is None and g["analysis"]["fields"] is None
    assert len(await get_redis().lrange(DLQ_KEY, 0, -1)) == 1
    async with env.maker() as s:
        rows = (await s.execute(select(AnalysisJob))).scalars().all()
        assert rows and all(r.status in (JobStatus.failed, JobStatus.dead) for r in rows)


@pytest.mark.parametrize(
    "mutation",
    [
        lambda f: f["category"].update(confidence=1.7),
        lambda f: f["category"].update(confidence="high"),
        lambda f: f.pop("pattern"),
        lambda f: f["subcategory"].update(value="jeans"),  # not in category "top"
        lambda f: f["seasons"].update(value=[]),
        lambda f: f["formality"].update(value=9),
    ],
)
async def test_malformed_model_output_is_rejected(env: Env, mutation: Any) -> None:
    answer = fields()
    mutation(answer)
    set_vision_factory(lambda name: Spy(answer))
    h = await signin(env)
    g = await add_garment(env, h)
    assert g["analysis"]["status"] == "needs_manual" and g["category"] is None


async def test_transient_provider_errors_are_retried(env: Env) -> None:
    spy = Spy(VisionError("timeout", retryable=True), VisionError("503", retryable=True), fields())
    set_vision_factory(lambda name: spy)
    h = await signin(env)
    g = await add_garment(env, h)
    assert len(spy.calls) == 3 and g["analysis"]["status"] == "done" and g["category"] == "top"


async def test_permanent_provider_errors_go_straight_to_manual_entry(env: Env) -> None:
    spy = Spy(VisionError("content blocked", retryable=False))
    set_vision_factory(lambda name: spy)
    h = await signin(env)
    g = await add_garment(env, h)
    assert len(spy.calls) == 1
    assert g["analysis"]["status"] == "needs_manual" and g["analysis"]["fields"] is None


async def test_manual_entry_completes_a_garment_the_ai_could_not_read(env: Env) -> None:
    h = await signin(env)
    g = await add_garment(
        env, h, filename="old_coat_fail.jpg"
    )  # "fail" makes the fake provider refuse
    assert g["analysis"]["status"] == "needs_manual"
    r = await env.client.patch(
        f"/v1/garments/{g['id']}", headers=h,
        json={"category": "outerwear", "subcategory": "coat", "primary_color": "brown", "pattern": "solid", "formality": 3, "seasons": ["winter"]},
    )  # fmt: skip
    assert r.status_code == 200 and r.json()["analysis"]["status"] == "done"
    async with env.maker() as s:  # nothing to learn from: the AI never answered
        assert (await s.execute(select(GarmentCorrection))).scalars().all() == []


async def test_per_user_daily_cap_stops_vision_calls(env: Env) -> None:
    get_settings().vision_daily_cap = 2
    spy = Spy(fields())
    set_vision_factory(lambda name: spy)
    h, other = await signin(env), await signin(env, "u2", "u2@x.com")
    for i in range(2):
        assert (await add_garment(env, h, f"cap-{i:04d}", data=garment_image(color=(i, 9, 9))))[
            "analysis"
        ]["status"] == "done"
    third = await add_garment(env, h, "cap-0003", data=garment_image(color=(3, 9, 9)))
    assert third["analysis"]["status"] == "needs_manual" and len(spy.calls) == 2
    async with env.maker() as s:
        capped = (
            (await s.execute(select(AnalysisJob).where(AnalysisJob.error == "usage_cap_reached")))
            .scalars()
            .all()
        )
        assert len(capped) == 1 and capped[0].status == JobStatus.failed
    # another user is unaffected
    assert (await add_garment(env, other, "cap-other-1", data=garment_image(color=(5, 9, 9))))[
        "analysis"
    ]["status"] == "done"


async def test_a_deleted_garment_mid_flight_does_not_crash_the_worker(env: Env) -> None:
    h = await signin(env)
    env.queue.paused = True
    g = await create(env, h)
    await upload(env, g["upload"], garment_image())
    await complete(env, h, g)
    async with env.maker() as s:
        row = await s.get(Garment, __import__("uuid").UUID(g["id"]))
        await s.delete(row)
        await s.commit()
    await env.queue.drain()
    assert all(kind == "ok" for _, _, kind in env.queue.log)


# ---- bookkeeping: cost line, usage rows, hints ----------------------------------------------------


async def test_every_vision_call_logs_a_cost_line_and_a_job_row(
    env: Env, caplog: pytest.LogCaptureFixture
) -> None:
    set_vision_factory(lambda name: Spy(fields()))
    h = await signin(env)
    with caplog.at_level(logging.INFO, logger="app.closet"):
        await add_garment(env, h)
    line = next(r.getMessage() for r in caplog.records if "vision_call" in r.getMessage())
    assert "provider=spy" in line and "model=spy-1" in line
    assert (
        "in_tokens=1200" in line
        and "out_tokens=150" in line
        and "cost_usd=0.002100" in line
        and "latency_ms=420" in line
    )
    assert "user=" in line and "@" not in line
    async with env.maker() as s:
        row = (await s.execute(select(AnalysisJob))).scalar_one()
        assert (row.status, row.provider, row.model, row.input_tokens, row.output_tokens, row.cost_usd, row.latency_ms) == (
            JobStatus.succeeded, "fake", "spy-1", 1200, 150, 0.0021, 420,
        )  # fmt: skip


async def test_unknown_pricing_is_logged_as_unknown_not_zero(
    env: Env, caplog: pytest.LogCaptureFixture
) -> None:
    class NoPrice(Spy):
        async def analyse(self, image: bytes, **kw: Any) -> VisionResult:
            r = await super().analyse(image, **kw)
            r.usage.cost_usd = None
            return r

    set_vision_factory(lambda name: NoPrice(fields()))
    h = await signin(env)
    with caplog.at_level(logging.INFO, logger="app.closet"):
        await add_garment(env, h)
    assert any("cost_usd=unknown" in r.getMessage() for r in caplog.records)


async def test_the_provider_gets_the_processed_image_the_filename_hint_and_the_department(
    env: Env,
) -> None:
    spy = Spy(fields())
    set_vision_factory(lambda name: spy)
    h = await signin(env)
    await env.client.patch("/v1/me", headers=h, json={"clothing_department": "womenswear"})
    await add_garment(env, h, filename="../../etc/Summer Dress (final).JPG")
    call = spy.calls[0]
    assert call["media_type"] == "image/webp" and call["department"] == "womenswear"
    assert call["hint"] == "Summer Dress final.JPG"  # path and odd characters stripped
    assert call["bytes"] > 100


async def test_provider_is_chosen_by_the_remote_config_flag(env: Env) -> None:
    from app.services.flags import set_flag

    seen: list[str] = []
    set_vision_factory(lambda name: (seen.append(name), Spy(fields()))[1])
    h = await signin(env)
    await add_garment(env, h, "flag-0001")
    async with env.maker() as s:
        await set_flag(s, get_redis(), "vision_provider", "claude")
    await add_garment(env, h, "flag-0002", data=garment_image(color=(9, 9, 200)))
    assert seen == ["fake", "claude"]  # switched without touching any code


# ---- corrections (feedback data) ------------------------------------------------------------------


async def corrections(env: Env) -> list[GarmentCorrection]:
    async with env.maker() as s:
        return list(
            (
                await s.execute(select(GarmentCorrection).order_by(GarmentCorrection.created_at))
            ).scalars()
        )


async def test_correcting_an_ai_value_is_recorded_as_feedback(env: Env) -> None:
    set_vision_factory(lambda name: Spy(fields()))
    h = await signin(env)
    g = await add_garment(env, h)
    r = await env.client.patch(
        f"/v1/garments/{g['id']}",
        headers=h,
        json={"primary_color": "cream", "formality": 4, "brand": "Acme"},
    )
    assert r.status_code == 200 and r.json()["primary_color"] == "cream"
    rows = await corrections(env)
    assert {(c.field, c.ai_value, c.user_value) for c in rows} == {
        ("primary_color", "white", "cream"),
        ("formality", 2, 4),
    }
    assert all(c.taxonomy_version == 1 for c in rows)  # brand is not an AI field: no row


async def test_no_feedback_for_unchanged_values_user_only_fields_or_reverts(env: Env) -> None:
    set_vision_factory(lambda name: Spy(fields()))
    h = await signin(env)
    g = await add_garment(env, h)
    await env.client.patch(
        f"/v1/garments/{g['id']}",
        headers=h,
        json={"primary_color": "white", "notes": "gift", "favorite": True},
    )
    assert await corrections(env) == []
    await env.client.patch(f"/v1/garments/{g['id']}", headers=h, json={"pattern": "striped"})
    await env.client.patch(
        f"/v1/garments/{g['id']}", headers=h, json={"pattern": "solid"}
    )  # back to what the AI said
    assert [(c.field, c.user_value) for c in await corrections(env)] == [("pattern", "striped")]


async def test_each_further_correction_of_the_same_field_is_kept(env: Env) -> None:
    set_vision_factory(lambda name: Spy(fields()))
    h = await signin(env)
    g = await add_garment(env, h)
    for colour in ("cream", "beige"):
        await env.client.patch(f"/v1/garments/{g['id']}", headers=h, json={"primary_color": colour})
    assert [(c.ai_value, c.user_value) for c in await corrections(env)] == [
        ("white", "cream"),
        ("white", "beige"),
    ]


# ---- editing validation ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("patch", "field"),
    [
        ({"primary_color": "chartreuse"}, "primary_color"),
        ({"formality": 6}, "formality"),
        ({"seasons": []}, "seasons"),
        ({"subcategory": "jeans"}, "subcategory"),  # the garment is a "top"
        ({"category": "bottom"}, "subcategory"),  # category change needs a matching subcategory
        ({"secondary_color": "white"}, "secondary_color"),  # same as primary
        ({"brand": "x" * 61}, "brand"),
        ({"fit": "baggy"}, "fit"),
    ],
)
async def test_invalid_edits_are_rejected_with_field_errors_and_change_nothing(
    env: Env, patch: dict[str, Any], field: str
) -> None:
    set_vision_factory(lambda name: Spy(fields()))
    h = await signin(env)
    g = await add_garment(env, h)
    r = await env.client.patch(f"/v1/garments/{g['id']}", headers=h, json=patch)
    assert r.status_code == 422 and r.json()["error"]["code"] == "invalid_garment"
    assert field in {e["field"] for e in r.json()["error"]["details"]["errors"]}
    assert (await detail(env, h, g["id"]))["primary_color"] == "white"
    assert await corrections(env) == []


async def test_category_and_subcategory_can_change_together(env: Env) -> None:
    set_vision_factory(lambda name: Spy(fields()))
    h = await signin(env)
    g = await add_garment(env, h)
    r = await env.client.patch(
        f"/v1/garments/{g['id']}", headers=h, json={"category": "bottom", "subcategory": "jeans"}
    )
    assert r.status_code == 200 and (r.json()["category"], r.json()["subcategory"]) == (
        "bottom",
        "jeans",
    )
    assert {c.field for c in await corrections(env)} == {"category", "subcategory"}


async def test_other_users_cannot_edit_my_garment(env: Env) -> None:
    a, b = await signin(env, "a", "a@x.com"), await signin(env, "b", "b@x.com")
    g = await add_garment(env, a)
    r = await env.client.patch(f"/v1/garments/{g['id']}", headers=b, json={"primary_color": "red"})
    assert r.status_code == 404
    assert (await detail(env, a, g["id"]))["primary_color"] != "red"
