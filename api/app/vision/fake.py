"""Deterministic vision provider for tests, CI, local runs and demos. No network, no account.

It reads the *file name* the app sent as a hint, e.g. ``navy_jeans_casual.jpg`` or ``red-polka-dot-sundress.png``:
taxonomy ids found in the name become high-confidence answers; everything else is derived from a hash of the
image bytes with low confidence (so the review screen's "check this" highlighting is exercised).
Special words: ``lowconf`` (all confidences 0.5), ``fail`` (permanent error), ``flaky`` (retryable error on
the first two attempts for that image).
"""

import hashlib
import re
from typing import Any

from app.domain import taxonomy as tx
from app.vision.base import VisionError, VisionResult, VisionUsage, validate_result

# typical formality / seasons per subcategory, used when the name does not say
_FORMALITY = {
    "t_shirt": 2, "long_sleeve_tee": 2, "shirt": 3, "blouse": 3, "polo": 3, "sweater": 2, "hoodie": 1,
    "tank_top": 2, "crop_top": 2, "cardigan": 3, "bodysuit": 2, "jeans": 2, "trousers": 4, "chinos": 3,
    "shorts": 2, "joggers": 1, "leggings": 1, "skirt": 3, "jacket": 2, "blazer": 4, "suit_jacket": 5,
    "coat": 3, "puffer": 2, "denim_jacket": 2, "raincoat": 2, "vest": 3, "sneakers": 2, "boots": 3,
    "loafers": 4, "sandals": 2, "dress_shoes": 5, "heels": 4, "flats": 3, "casual_dress": 2,
    "cocktail_dress": 5, "maxi_dress": 3, "jumpsuit": 3, "hat": 2, "scarf": 3, "belt": 3, "tie": 5,
    "bag": 3, "jewelry": 4, "sunglasses": 2, "watch": 3,
}  # fmt: skip
_WINTER = {"coat", "puffer", "sweater", "hoodie", "boots", "scarf", "cardigan"}
_SUMMER = {"shorts", "tank_top", "sandals", "crop_top", "sunglasses", "maxi_dress"}
_FORMALITY_WORDS = {
    "lounge": 1,
    "loungewear": 1,
    "casual": 2,
    "smart": 3,
    "business": 4,
    "formal": 5,
}
_DEFAULT_SUB = {c: tx.subcategories_of(c)[0] for c in tx.CATEGORIES}


def _tokens(name: str | None) -> str:
    return "_" + re.sub(r"[^a-z0-9]+", "_", (name or "").lower()).strip("_") + "_"


def _has(tokens: str, ident: str) -> bool:
    return f"_{ident}_" in tokens


class FakeVisionProvider:
    name = "fake"
    model = "fake-vision"
    version = "1"

    def __init__(self) -> None:
        self._attempts: dict[str, int] = {}

    async def analyse(
        self,
        image: bytes,
        *,
        media_type: str,
        hint: str | None = None,
        department: str | None = None,
    ) -> VisionResult:
        toks = _tokens(hint)
        digest = hashlib.sha256(image).hexdigest()
        n = int(digest[:12], 16)
        if _has(toks, "fail"):
            raise VisionError("fake provider: permanent failure requested by file name")
        if _has(toks, "flaky"):
            self._attempts[digest] = self._attempts.get(digest, 0) + 1
            if self._attempts[digest] <= 2:
                raise VisionError("fake provider: transient failure", retryable=True)

        raw = self._guess(toks, n, department)
        if _has(toks, "lowconf"):
            for v in raw.values():
                v["confidence"] = 0.5
        return VisionResult(
            fields=validate_result(raw),
            provider=self.name,
            model=self.model,
            version=self.version,
            usage=VisionUsage(cost_usd=0.0),
            latency_ms=1,
        )

    def _guess(self, toks: str, n: int, department: str | None) -> dict[str, dict[str, Any]]:
        def pick(options: tuple[str, ...], salt: int) -> str:
            return options[(n >> salt) % len(options)]

        hit = bool  # readability: "named in the file name"
        sub = next((s for s in tx.SUBCATEGORY_TO_CATEGORY if _has(toks, s)), None)
        category = next((c for c in tx.CATEGORIES if _has(toks, c)), None)
        sub_named = sub is not None
        if sub is None:
            if category:
                sub = _DEFAULT_SUB[category]
            else:
                visible = sorted(tx.visible_subcategories(department))
                sub = visible[n % len(visible)]
        category = tx.SUBCATEGORY_TO_CATEGORY[sub]
        cat_conf = 0.96 if sub_named else (0.9 if hit(category) else 0.55)
        sub_conf = 0.95 if sub_named else (0.6 if hit(category) else 0.5)

        named_colors = [c for c in tx.COLORS if _has(toks, c)]
        primary = named_colors[0] if named_colors else pick(tx.COLORS, 8)
        secondary = named_colors[1] if len(named_colors) > 1 else None
        named_pattern = next((p for p in tx.PATTERNS if p != "solid" and _has(toks, p)), None)
        pattern = named_pattern or "solid"

        formality = next((v for w, v in _FORMALITY_WORDS.items() if _has(toks, w)), None)
        if formality is None:
            formality = next((int(d) for d in "12345" if _has(toks, f"f{d}")), None)
        formality_conf = 0.9 if formality is not None else 0.62
        formality = formality if formality is not None else _FORMALITY.get(sub, 3)

        named_seasons = [s for s in tx.SEASONS if _has(toks, s)]
        if named_seasons:
            seasons, seasons_conf = named_seasons, 0.88
        else:
            seasons_conf = 0.6
            if sub in _WINTER:
                seasons = ["autumn", "winter"]
            elif sub in _SUMMER:
                seasons = ["spring", "summer"]
            else:
                seasons = ["spring", "summer", "autumn", "winter"]
        fit = next((f for f in tx.FITS if _has(toks, f)), None)
        material = next((m for m in tx.MATERIALS if _has(toks, m)), None)

        return {
            "category": {"value": category, "confidence": cat_conf},
            "subcategory": {"value": sub, "confidence": sub_conf},
            "primary_color": {
                "value": primary,
                "confidence": 0.94 if named_colors else 0.5,
            },
            "secondary_color": {
                "value": secondary,
                "confidence": 0.85 if secondary else 0.8,
            },
            "pattern": {"value": pattern, "confidence": 0.9 if named_pattern else 0.8},
            "formality": {"value": formality, "confidence": formality_conf},
            "seasons": {"value": seasons, "confidence": seasons_conf},
            "fit": {"value": fit, "confidence": 0.8 if fit else 0.4},
            "material": {"value": material, "confidence": 0.85 if material else 0.4},
        }
