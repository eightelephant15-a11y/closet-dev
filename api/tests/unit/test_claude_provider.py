"""ClaudeVisionProvider against a stub client: no network, no key. Verifies the request we would send."""

import base64
import io
import json
from types import SimpleNamespace
from typing import Any

import anthropic
import httpx
import jsonschema
import pytest
from PIL import Image

from app.core.config import Settings
from app.domain import taxonomy as tx
from app.vision import VisionError
from app.vision.base import VisionResultInvalid
from app.vision.claude import (
    KNOWN_PRICES,
    MAX_SIDE,
    ClaudeVisionProvider,
    api_schema,
    prepare_image,
)
from tests.imagegen import garment_image

GOOD = {
    f: {"value": v, "confidence": 0.9}
    for f, v in {
        "category": "top", "subcategory": "t_shirt", "primary_color": "white", "secondary_color": None,
        "pattern": "solid", "formality": 2, "seasons": ["spring", "summer"], "fit": "regular", "material": "cotton",
    }.items()
}  # fmt: skip


def reply(
    payload: Any = GOOD, *, stop: str = "end_turn", text: str | None = None, **usage: int
) -> Any:
    body = text if text is not None else json.dumps(payload)
    return SimpleNamespace(
        content=[SimpleNamespace(type="text", text=body)],
        stop_reason=stop,
        stop_details=SimpleNamespace(category="cyber"),
        model="claude-opus-5-5",
        usage=SimpleNamespace(input_tokens=usage.get("i", 1500), output_tokens=usage.get("o", 400)),
    )


class StubClient:
    def __init__(self, result: Any = None, error: Exception | None = None) -> None:
        self.calls: list[dict[str, Any]] = []
        self._result, self._error = result, error
        self.messages = SimpleNamespace(create=self._create)

    async def _create(self, **kwargs: Any) -> Any:
        self.calls.append(kwargs)
        if self._error:
            raise self._error
        return self._result if self._result is not None else reply()


def provider(client: StubClient, **kw: Any) -> ClaudeVisionProvider:
    return ClaudeVisionProvider(client=client, model=kw.pop("model", "claude-opus-5-5"), **kw)


def webp_photo() -> bytes:
    out = io.BytesIO()
    Image.open(io.BytesIO(garment_image((600, 900)))).save(out, format="WEBP")
    return out.getvalue()


def status_error(cls: type[anthropic.APIStatusError], code: int) -> anthropic.APIStatusError:
    req = httpx.Request("POST", "https://api.anthropic.com/v1/messages")
    return cls("boom", response=httpx.Response(code, request=req), body=None)


# ---- the request ---------------------------------------------------------------------------------


async def test_request_shape() -> None:
    stub = StubClient()
    await provider(stub).analyse(
        webp_photo(), media_type="image/webp", hint="my_private_name.jpg", department="womenswear"
    )
    req = stub.calls[0]
    assert req["model"] == "claude-opus-5-5" and req["max_tokens"] >= 2000
    msg = req["messages"][0]
    assert msg["role"] == "user"
    image, text = msg["content"]
    assert image["type"] == "image" and image["source"]["type"] == "base64"
    assert image["source"]["media_type"] == "image/webp"
    decoded = base64.b64decode(image["source"]["data"])
    assert Image.open(io.BytesIO(decoded)).format == "WEBP"
    assert "womenswear" in text["text"]
    assert "my_private_name" not in json.dumps(req), (
        "the client's file name must never reach the provider"
    )
    fmt = req["output_config"]["format"]
    assert fmt["type"] == "json_schema" and req["output_config"]["effort"] == "low"
    # parameters that current models reject must not be sent
    for forbidden in ("temperature", "top_p", "top_k", "tool_choice", "thinking", "prefill"):
        assert forbidden not in req
    # the prompt is built from the same taxonomy the app and API use
    assert (
        "burgundy" in req["system"]
        and "cocktail_dress" in req["system"]
        and "Formality" in req["system"]
    )
    assert not any(m["role"] == "assistant" for m in req["messages"]), "no assistant prefill"


async def test_effort_can_be_turned_off_and_department_is_optional() -> None:
    stub = StubClient()
    await provider(stub, effort="").analyse(webp_photo(), media_type="image/webp")
    assert "effort" not in stub.calls[0]["output_config"]
    assert "shops in" not in stub.calls[0]["messages"][0]["content"][1]["text"]


def test_schema_sent_to_the_api_has_no_unsupported_keywords_but_keeps_the_enums() -> None:
    schema = api_schema()
    text = json.dumps(schema)
    for kw in ("minimum", "maximum", "minItems", "maxItems"):
        assert kw not in text
    assert "burgundy" in text and "cocktail_dress" in text
    jsonschema.Draft202012Validator.check_schema(schema)
    jsonschema.validate(GOOD, schema)
    assert set(schema["required"]) == set(tx.AI_FIELDS)
    assert "minimum" in json.dumps(tx.ai_result_schema()), "the internal schema keeps its bounds"


def test_images_are_downsized_and_stripped_before_sending() -> None:
    big = io.BytesIO()
    Image.new("RGB", (3000, 2000), (10, 20, 30)).save(big, format="WEBP")
    out = Image.open(io.BytesIO(prepare_image(big.getvalue())))
    assert max(out.size) == MAX_SIDE and out.format == "WEBP"


# ---- the answer ----------------------------------------------------------------------------------


async def test_a_valid_answer_is_returned_with_usage_and_cost() -> None:
    stub = StubClient(reply(i=2000, o=500))
    r = await provider(stub).analyse(webp_photo(), media_type="image/webp")
    assert r.fields["category"] == {"value": "top", "confidence": 0.9}
    assert (r.provider, r.model, r.usage.input_tokens, r.usage.output_tokens) == (
        "claude",
        "claude-opus-5-5",
        2000,
        500,
    )
    assert r.usage.cost_usd == pytest.approx((2000 * 4.0 + 500 * 20.0) / 1e6)
    assert r.latency_ms >= 0


@pytest.mark.parametrize(
    ("model", "override", "expected"),
    [
        ("claude-haiku-5-5", (0, 0), (0.10, 0.50)),
        ("claude-sonnet-5-5", (0, 0), (2.0, 10.0)),
        ("claude-opus-5-5", (1.0, 2.0), (1.0, 2.0)),  # the env override wins
        ("some-new-model", (0, 0), None),  # unknown pricing is never guessed
    ],
)
async def test_pricing(
    model: str, override: tuple[float, float], expected: tuple[float, float] | None
) -> None:
    r = await provider(
        StubClient(reply(i=1_000_000, o=1_000_000)),
        model=model,
        price_input_per_mtok=override[0],
        price_output_per_mtok=override[1],
    ).analyse(webp_photo(), media_type="image/webp")
    if expected is None:
        assert r.usage.cost_usd is None
    else:
        assert r.usage.cost_usd == pytest.approx(expected[0] + expected[1])
    assert "claude-opus-5-5" in KNOWN_PRICES


@pytest.mark.parametrize(
    "text",
    [
        "not json at all",
        "[]",
        json.dumps({"category": {"value": "top", "confidence": 0.9}}),
        json.dumps({**GOOD, "pattern": {"value": "tartan", "confidence": 0.9}}),
        json.dumps({**GOOD, "formality": {"value": 3, "confidence": 4}}),
    ],
)
async def test_untrusted_output_is_rejected_as_retryable_invalid(text: str) -> None:
    with pytest.raises(VisionResultInvalid) as exc:
        await provider(StubClient(reply(text=text))).analyse(webp_photo(), media_type="image/webp")
    assert exc.value.retryable is True


async def test_truncated_answers_are_invalid_not_trusted() -> None:
    with pytest.raises(VisionResultInvalid, match="cut off"):
        await provider(StubClient(reply(stop="max_tokens", text='{"category": {"va'))).analyse(
            webp_photo(), media_type="image/webp"
        )


async def test_a_refusal_is_a_permanent_error_with_the_category() -> None:
    with pytest.raises(VisionError, match="declined") as exc:
        await provider(StubClient(reply(stop="refusal", text=""))).analyse(
            webp_photo(), media_type="image/webp"
        )
    assert exc.value.retryable is False and "cyber" in str(exc.value)


async def test_an_unreadable_image_never_reaches_the_api() -> None:
    stub = StubClient()
    with pytest.raises(VisionError) as exc:
        await provider(stub).analyse(b"not an image", media_type="image/webp")
    assert exc.value.retryable is False and stub.calls == []


# ---- errors from the SDK -----------------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("error", "retryable"),
    [
        (status_error(anthropic.RateLimitError, 429), True),
        (status_error(anthropic.InternalServerError, 500), True),
        (status_error(anthropic.InternalServerError, 529), True),
        (anthropic.APIConnectionError(request=httpx.Request("POST", "https://x")), True),
        (anthropic.APITimeoutError(request=httpx.Request("POST", "https://x")), True),
        (status_error(anthropic.BadRequestError, 400), False),
        (status_error(anthropic.AuthenticationError, 401), False),
        (status_error(anthropic.PermissionDeniedError, 403), False),
        (status_error(anthropic.NotFoundError, 404), False),
    ],
)
async def test_sdk_errors_are_classified_for_retry(error: Exception, retryable: bool) -> None:
    with pytest.raises(VisionError) as exc:
        await provider(StubClient(error=error)).analyse(webp_photo(), media_type="image/webp")
    assert exc.value.retryable is retryable
    assert "sk-" not in str(exc.value)


def test_from_settings_needs_a_key_and_reads_the_model(monkeypatch: pytest.MonkeyPatch) -> None:
    with pytest.raises(VisionError, match="ANTHROPIC_API_KEY"):
        ClaudeVisionProvider.from_settings(Settings(_env_file=None))  # type: ignore[call-arg]
    s = Settings(
        _env_file=None,
        anthropic_api_key="sk-ant-test",
        vision_model="claude-sonnet-5-5",
        vision_effort="medium",
    )  # type: ignore[call-arg]
    p = ClaudeVisionProvider.from_settings(s)
    assert p.model == "claude-sonnet-5-5" and p._effort == "medium"
    assert "sk-ant-test" not in repr(s), "the key must not leak through repr"


def test_provider_is_selected_by_name_without_code_changes(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.vision import FakeVisionProvider, build_provider

    assert isinstance(build_provider("fake"), FakeVisionProvider)
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-ant-test")
    from app.core.config import get_settings

    get_settings.cache_clear()
    try:
        assert isinstance(build_provider("claude"), ClaudeVisionProvider)
    finally:
        get_settings.cache_clear()
