"""Vision provider seam: image in, taxonomy-valid fields with a confidence per field out."""

from dataclasses import dataclass, field
from typing import Any, Protocol

from app.domain.taxonomy import AI_FIELDS, OPTIONAL_AI_FIELDS, validate_fields


class VisionError(Exception):
    """The provider failed. ``retryable`` errors (timeouts, 5xx, rate limits) are retried with backoff."""

    def __init__(self, message: str, *, retryable: bool = False) -> None:
        super().__init__(message)
        self.retryable = retryable


class VisionResultInvalid(VisionError):
    """The model answered, but not in the taxonomy format. Worth one more try, never trusted."""

    def __init__(self, message: str) -> None:
        super().__init__(message, retryable=True)


@dataclass
class VisionUsage:
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float | None = None  # None = pricing unknown (never guessed)


@dataclass
class VisionResult:
    # {field: {"value": ..., "confidence": 0..1}} for every field in the taxonomy's ai_fields
    fields: dict[str, dict[str, Any]]
    provider: str
    model: str
    version: str
    usage: VisionUsage = field(default_factory=VisionUsage)
    latency_ms: int = 0


class VisionProvider(Protocol):
    name: str
    model: str
    version: str

    async def analyse(
        self,
        image: bytes,
        *,
        media_type: str,
        hint: str | None = None,
        department: str | None = None,
    ) -> VisionResult: ...


def validate_result(raw: Any) -> dict[str, dict[str, Any]]:
    """Strictly validates a provider answer against the taxonomy. Returns the cleaned fields.

    Anything off (missing field, unknown id, confidence outside 0..1, subcategory not in category) raises
    ``VisionResultInvalid``: model output is untrusted input.
    """
    if not isinstance(raw, dict):
        raise VisionResultInvalid("result is not an object")
    values: dict[str, Any] = {}
    confidences: dict[str, float] = {}
    for f in AI_FIELDS:
        entry = raw.get(f)
        if not isinstance(entry, dict) or "value" not in entry or "confidence" not in entry:
            if f in OPTIONAL_AI_FIELDS:
                entry = {"value": None, "confidence": 0.0}
            else:
                raise VisionResultInvalid(f"missing field {f!r}")
        conf = entry["confidence"]
        if isinstance(conf, bool) or not isinstance(conf, (int, float)) or not 0 <= conf <= 1:
            raise VisionResultInvalid(f"bad confidence for {f!r}")
        values[f] = entry["value"]
        confidences[f] = float(conf)
    clean, errors = validate_fields(values)
    if errors:
        raise VisionResultInvalid("; ".join(f"{e.field}: {e.message}" for e in errors))
    return {f: {"value": clean[f], "confidence": round(confidences[f], 4)} for f in AI_FIELDS}
