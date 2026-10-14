"""Garment taxonomy: typed access, validation and the schema handed to the vision model.

The data comes from ``taxonomy/garment_taxonomy.v1.json`` via ``taxonomy_data.py`` (generated).
App, API and AI prompt all read the same document; never hard-code category names elsewhere.
"""

from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any

from app.domain.taxonomy_data import TAXONOMY

TAXONOMY_VERSION: int = TAXONOMY["version"]

CATEGORIES: tuple[str, ...] = tuple(c["id"] for c in TAXONOMY["categories"])
SUBCATEGORY_TO_CATEGORY: dict[str, str] = {
    s["id"]: c["id"] for c in TAXONOMY["categories"] for s in c["subcategories"]
}
SUBCATEGORY_DEPARTMENTS: dict[str, tuple[str, ...]] = {
    s["id"]: tuple(s["departments"]) for c in TAXONOMY["categories"] for s in c["subcategories"]
}
COLORS: tuple[str, ...] = tuple(p["id"] for p in TAXONOMY["palette"])
COLOR_HEX: dict[str, str] = {p["id"]: p["hex"] for p in TAXONOMY["palette"]}
BRIGHT_COLORS: frozenset[str] = frozenset(p["id"] for p in TAXONOMY["palette"] if p["bright"])
PATTERNS: tuple[str, ...] = tuple(p["id"] for p in TAXONOMY["patterns"])
SEASONS: tuple[str, ...] = tuple(p["id"] for p in TAXONOMY["seasons"])
FITS: tuple[str, ...] = tuple(p["id"] for p in TAXONOMY["fits"])
MATERIALS: tuple[str, ...] = tuple(p["id"] for p in TAXONOMY["materials"])
FORMALITY: tuple[int, ...] = tuple(f["value"] for f in TAXONOMY["formality"])
AI_FIELDS: tuple[str, ...] = tuple(TAXONOMY["ai_fields"])
USER_FIELDS: tuple[str, ...] = tuple(TAXONOMY["user_fields"])
BRAND_MAX: int = TAXONOMY["limits"]["brand_max"]
NOTES_MAX: int = TAXONOMY["limits"]["notes_max"]
EDITABLE_FIELDS: tuple[str, ...] = (*AI_FIELDS, *USER_FIELDS)
OPTIONAL_AI_FIELDS = frozenset({"secondary_color", "fit", "material"})  # may be null


@dataclass(frozen=True)
class FieldError:
    field: str
    message: str


def subcategories_of(category: str) -> tuple[str, ...]:
    return tuple(s for s, c in SUBCATEGORY_TO_CATEGORY.items() if c == category)


def visible_subcategories(department: str | None) -> frozenset[str]:
    """Subcategories for a user's ``clothing_department`` (menswear|womenswear|both|everything)."""
    if department in ("menswear", "womenswear"):
        return frozenset(s for s, d in SUBCATEGORY_DEPARTMENTS.items() if department in d)
    return frozenset(SUBCATEGORY_DEPARTMENTS)


def visible_categories(department: str | None) -> tuple[str, ...]:
    subs = visible_subcategories(department)
    return tuple(c for c in CATEGORIES if any(s in subs for s in subcategories_of(c)))


def _in(value: Any, allowed: tuple[Any, ...]) -> bool:
    return isinstance(value, type(allowed[0])) and value in allowed if allowed else False


def validate_fields(
    fields: Mapping[str, Any], *, require_core: bool = False
) -> tuple[dict[str, Any], list[FieldError]]:
    """Validates (a subset of) garment fields against the taxonomy.

    Returns the cleaned values (seasons de-duplicated and ordered, strings trimmed) and the errors.
    With ``require_core`` the core fields (category .. formality, seasons) must be present.
    """
    errors: list[FieldError] = []
    clean: dict[str, Any] = {}

    def bad(field: str, message: str) -> None:
        errors.append(FieldError(field, message))

    unknown = set(fields) - set(EDITABLE_FIELDS)
    for f in sorted(unknown):
        bad(f, "unknown field")

    category = fields.get("category")
    subcategory = fields.get("subcategory")
    if "category" in fields:
        if _in(category, CATEGORIES):
            clean["category"] = category
        else:
            bad("category", f"must be one of {list(CATEGORIES)}")
    if "subcategory" in fields:
        if not isinstance(subcategory, str) or subcategory not in SUBCATEGORY_TO_CATEGORY:
            bad("subcategory", "unknown subcategory")
        else:
            clean["subcategory"] = subcategory
            if "category" in clean and SUBCATEGORY_TO_CATEGORY[subcategory] != clean["category"]:
                bad("subcategory", f"{subcategory!r} does not belong to category {category!r}")

    for f, allowed in (("primary_color", COLORS), ("pattern", PATTERNS)):
        if f in fields:
            if _in(fields[f], allowed):
                clean[f] = fields[f]
            else:
                bad(f, f"must be one of {list(allowed)}")
    for f, allowed in (("secondary_color", COLORS), ("fit", FITS), ("material", MATERIALS)):
        if f in fields:
            if fields[f] is None or _in(fields[f], allowed):
                clean[f] = fields[f]
            else:
                bad(f, f"must be null or one of {list(allowed)}")
    if clean.get("secondary_color") is not None and clean.get("secondary_color") == fields.get(
        "primary_color"
    ):
        bad("secondary_color", "must differ from primary_color")

    if "formality" in fields:
        v = fields["formality"]
        if isinstance(v, int) and not isinstance(v, bool) and v in FORMALITY:
            clean["formality"] = v
        else:
            bad("formality", f"must be an integer in {list(FORMALITY)}")
    if "seasons" in fields:
        v = fields["seasons"]
        if isinstance(v, list) and v and all(isinstance(s, str) and s in SEASONS for s in v):
            clean["seasons"] = [s for s in SEASONS if s in v]  # canonical order, de-duplicated
        else:
            bad("seasons", f"must be a non-empty list of {list(SEASONS)}")
    for f, limit in (("brand", BRAND_MAX), ("notes", NOTES_MAX)):
        if f in fields:
            v = fields[f]
            if v is None:
                clean[f] = None
            elif isinstance(v, str) and len(v.strip()) <= limit:
                clean[f] = v.strip() or None
            else:
                bad(f, f"must be text up to {limit} characters")

    if require_core:
        for f in ("category", "subcategory", "primary_color", "pattern", "formality", "seasons"):
            if f not in fields:
                bad(f, "required")
    return clean, errors


def ai_result_schema() -> dict[str, Any]:
    """JSON schema for the vision model's structured answer: ``{field: {value, confidence}}``."""

    def enum_for(field: str) -> dict[str, Any]:
        match field:
            case "category":
                return {"type": "string", "enum": list(CATEGORIES)}
            case "subcategory":
                return {"type": "string", "enum": list(SUBCATEGORY_TO_CATEGORY)}
            case "primary_color":
                return {"type": "string", "enum": list(COLORS)}
            case "secondary_color":
                return {"type": ["string", "null"], "enum": [*COLORS, None]}
            case "pattern":
                return {"type": "string", "enum": list(PATTERNS)}
            case "formality":
                return {"type": "integer", "enum": list(FORMALITY)}
            case "seasons":
                return {
                    "type": "array",
                    "items": {"type": "string", "enum": list(SEASONS)},
                    "minItems": 1,
                }
            case "fit":
                return {"type": ["string", "null"], "enum": [*FITS, None]}
            case "material":
                return {"type": ["string", "null"], "enum": [*MATERIALS, None]}
        raise KeyError(field)

    props = {
        f: {
            "type": "object",
            "properties": {
                "value": enum_for(f),
                "confidence": {"type": "number", "minimum": 0, "maximum": 1},
            },
            "required": ["value", "confidence"],
            "additionalProperties": False,
        }
        for f in AI_FIELDS
    }
    return {
        "type": "object",
        "properties": props,
        "required": list(AI_FIELDS),
        "additionalProperties": False,
    }


def prompt_guide() -> str:
    """Human-readable taxonomy used in the vision prompt (built from the same data)."""
    lines = ["Categories and their subcategories:"]
    for c in TAXONOMY["categories"]:
        subs = ", ".join(s["id"] for s in c["subcategories"])
        lines.append(f"- {c['id']}: {subs}")
    lines.append(
        "Colours (id: hex): " + ", ".join(f"{p['id']}={p['hex']}" for p in TAXONOMY["palette"])
    )
    lines.append("Patterns: " + ", ".join(PATTERNS))
    lines.append(
        "Seasons: " + ", ".join(SEASONS) + " (a garment can suit several; all four = all-season)"
    )
    lines.append("Fits: " + ", ".join(FITS))
    lines.append("Materials: " + ", ".join(MATERIALS))
    lines.append(
        "Formality: " + "; ".join(f"{f['value']}={f['label']}" for f in TAXONOMY["formality"])
    )
    return "\n".join(lines)
