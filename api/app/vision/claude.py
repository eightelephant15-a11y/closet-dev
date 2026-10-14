"""Claude vision adapter (Anthropic Messages API, image input, JSON-schema structured output).

UNVERIFIED against the live API: built from the documented request shapes and covered by tests that use a
stub client. Run ``make eval-vision`` with a real key before trusting it (docs/vision-eval.md).

Configuration (environment; nothing here is hard-coded to a model):
  ANTHROPIC_API_KEY   the key (never logged, never in git)
  VISION_MODEL        model id, default ``claude-opus-5-5``. Cheaper models (e.g. ``claude-sonnet-5-5``,
                      ``claude-haiku-5-5``) are worth trying: measure with ``make eval-vision`` first.
  VISION_EFFORT       ``low`` (default) | ``medium`` | ``high`` | ``xhigh`` | ``max`` | empty to omit.
                      Thinking depth is the main cost lever on current models.
  VISION_PRICE_INPUT_PER_MTOK / VISION_PRICE_OUTPUT_PER_MTOK   override the price table (USD per million tokens)
"""

import asyncio
import base64
import io
import json
import time
from typing import Any

import anthropic
from PIL import Image

from app.core.config import Settings, get_settings
from app.domain import taxonomy as tx
from app.vision.base import (
    VisionError,
    VisionResult,
    VisionResultInvalid,
    VisionUsage,
    validate_result,
)

# USD per million tokens (input, output). Copied from the published price list on 2026-10-06 so spend
# can be logged out of the box; override with VISION_PRICE_* if prices change. Unknown model => cost is
# logged as "unknown", never guessed.
KNOWN_PRICES: dict[str, tuple[float, float]] = {
    "claude-opus-5-5": (4.00, 20.00),
    "claude-opus-5": (5.00, 25.00),
    "claude-sonnet-5-5": (2.00, 10.00),
    "claude-sonnet-5": (2.00, 10.00),
    "claude-haiku-5-5": (0.10, 0.50),  # prompts up to 100K tokens
    "claude-haiku-4-5": (1.00, 5.00),
}
MAX_SIDE = 1024  # the model downsizes large images anyway; sending less saves input tokens
MAX_OUTPUT_TOKENS = 4000  # room for thinking at low effort plus the ~400-token JSON answer

SYSTEM_PROMPT = """You catalogue clothing for a personal wardrobe app. You are shown ONE photo of ONE garment, \
shoe or accessory that the owner took of their own item. Describe it using ONLY the controlled vocabulary below.

{guide}

Rules:
- Answer for the single most prominent item. If several are visible, describe the one the photo is about.
- primary_color is the dominant colour of the item itself (not the background, a hanger or a person's skin); \
secondary_color is a clearly visible second colour, otherwise null. Pick the nearest palette colour.
- pattern is "solid" unless there is a clear pattern.
- seasons lists every season the item suits (all four for year-round basics such as jeans or a white tee).
- fit and material are null unless you can actually tell from the photo. Never guess a brand.
- confidence is your honest probability (0 to 1) that the value is right: 0.9+ clearly visible, \
0.6-0.8 probable, below 0.6 a guess. Do not give every field a high score; a wrong high-confidence answer is \
worse than an honest low one because the owner is asked to double-check low-confidence fields.
- Reply with the JSON object only."""


def api_schema() -> dict[str, Any]:
    """The taxonomy result schema, reduced to what structured outputs accept.

    Numeric/array bounds are dropped from the schema sent to the API (the enums carry the real constraints and
    ``validate_result`` re-checks everything, including confidence in 0..1, on our side).
    """
    schema: dict[str, Any] = json.loads(json.dumps(tx.ai_result_schema()))

    def strip(node: Any) -> None:
        if isinstance(node, dict):
            for key in ("minimum", "maximum", "minItems", "maxItems"):
                node.pop(key, None)
            for v in node.values():
                strip(v)
        elif isinstance(node, list):
            for v in node:
                strip(v)

    strip(schema)
    return schema


def prepare_image(data: bytes) -> bytes:
    """Downsizes to ``MAX_SIDE`` and re-encodes as WebP (cheap on tokens, no metadata)."""
    opened = Image.open(io.BytesIO(data))
    opened.load()
    img: Image.Image = opened
    if max(img.size) > MAX_SIDE:
        img.thumbnail((MAX_SIDE, MAX_SIDE), Image.Resampling.LANCZOS)
    if img.mode not in ("RGB", "RGBA"):
        img = img.convert("RGB")
    out = io.BytesIO()
    img.save(out, format="WEBP", quality=85)
    return out.getvalue()


class ClaudeVisionProvider:
    name = "claude"
    version = "1"

    def __init__(
        self,
        *,
        client: Any,
        model: str,
        effort: str = "low",
        price_input_per_mtok: float = 0.0,
        price_output_per_mtok: float = 0.0,
    ) -> None:
        self._client = client
        self.model = model
        self._effort = effort
        self._price = self._resolve_price(model, price_input_per_mtok, price_output_per_mtok)

    @classmethod
    def from_settings(cls, settings: Settings | None = None) -> "ClaudeVisionProvider":
        settings = settings or get_settings()
        key = settings.anthropic_api_key.get_secret_value()
        if not key:
            raise VisionError("ANTHROPIC_API_KEY is not set", retryable=False)
        client = anthropic.AsyncAnthropic(api_key=key, timeout=60.0, max_retries=2)
        return cls(
            client=client,
            model=settings.vision_model,
            effort=settings.vision_effort,
            price_input_per_mtok=settings.vision_price_input_per_mtok,
            price_output_per_mtok=settings.vision_price_output_per_mtok,
        )

    @staticmethod
    def _resolve_price(model: str, inp: float, out: float) -> tuple[float, float] | None:
        if inp > 0 or out > 0:
            return (inp, out)
        return KNOWN_PRICES.get(model)

    def request_kwargs(self, image: bytes, department: str | None) -> dict[str, Any]:
        """The exact request (kept separate so tests can assert its shape without a network)."""
        user_text = "Catalogue this item."
        if department in ("menswear", "womenswear"):
            user_text += f" (The owner shops in {department}; use that only to break ties.)"
        output_config: dict[str, Any] = {"format": {"type": "json_schema", "schema": api_schema()}}
        if self._effort:
            output_config["effort"] = self._effort
        return {
            "model": self.model,
            "max_tokens": MAX_OUTPUT_TOKENS,
            "system": SYSTEM_PROMPT.format(guide=tx.prompt_guide()),
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/webp",
                                "data": base64.standard_b64encode(image).decode("ascii"),
                            },
                        },
                        {"type": "text", "text": user_text},
                    ],
                }
            ],
            # No temperature/top_p (rejected by current models), no forced tool_choice (400 on
            # Opus 5.5 / Sonnet 5.5): the JSON schema is what constrains the answer.
            "output_config": output_config,
        }

    async def analyse(
        self,
        image: bytes,
        *,
        media_type: str,
        hint: str | None = None,
        department: str | None = None,
    ) -> VisionResult:
        # `hint` (the client's file name) is deliberately NOT sent: it is only for the fake provider.
        try:
            prepared = await asyncio.to_thread(prepare_image, image)
        except Exception as exc:
            raise VisionError(f"could not read the image: {exc}", retryable=False) from exc
        started = time.monotonic()
        try:
            response = await self._client.messages.create(
                **self.request_kwargs(prepared, department)
            )
        except anthropic.RateLimitError as exc:
            raise VisionError("rate limited by the provider", retryable=True) from exc
        except (anthropic.APIConnectionError, anthropic.APITimeoutError) as exc:
            raise VisionError(
                f"provider unreachable: {type(exc).__name__}", retryable=True
            ) from exc
        except anthropic.APIStatusError as exc:
            retryable = exc.status_code >= 500 or exc.status_code in (408, 409, 529)
            raise VisionError(f"provider error {exc.status_code}", retryable=retryable) from exc
        latency_ms = int((time.monotonic() - started) * 1000)

        if response.stop_reason == "refusal":
            category = getattr(getattr(response, "stop_details", None), "category", None)
            raise VisionError(
                f"the model declined this image (category: {category})", retryable=False
            )
        if response.stop_reason == "max_tokens":
            raise VisionResultInvalid("the answer was cut off (max_tokens)")
        text = next((b.text for b in response.content if getattr(b, "type", "") == "text"), None)
        if not text:
            raise VisionResultInvalid("no text in the answer")
        try:
            raw = json.loads(text)
        except json.JSONDecodeError as exc:
            raise VisionResultInvalid("the answer is not valid JSON") from exc

        usage = VisionUsage(
            input_tokens=int(getattr(response.usage, "input_tokens", 0) or 0),
            output_tokens=int(getattr(response.usage, "output_tokens", 0) or 0),
        )
        if self._price is not None:
            usage.cost_usd = (
                usage.input_tokens * self._price[0] + usage.output_tokens * self._price[1]
            ) / 1_000_000
        return VisionResult(
            fields=validate_result(raw),
            provider=self.name,
            model=str(getattr(response, "model", self.model) or self.model),
            version=self.version,
            usage=usage,
            latency_ms=latency_ms,
        )
