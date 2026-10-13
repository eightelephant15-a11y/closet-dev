"""Versioned preference model derived from style-quiz answers.

The output (``weights``) is what a future ranking engine consumes. Keep this pure and
deterministic; bump MODEL_VERSION when the shape or semantics change.
"""

from typing import Any

MODEL_VERSION = 1

DEPARTMENTS = ("menswear", "womenswear", "both", "everything")
FITS = ("relaxed", "regular", "slim")
COLORS = (
    "black", "white", "grey", "navy", "beige", "brown", "olive",
    "red", "pink", "blue", "green", "yellow", "purple", "orange",
)  # fmt: skip
BRIGHT_COLORS = ("red", "pink", "yellow", "orange", "green", "purple")
GOALS = ("work", "dates", "travel", "everyday")
DRESS_CODE_LEVELS = 5  # 0 = very casual ... 4 = formal

_COMMON_NEVER = ("sleeveless", "shorts", "bright_colors")
_MEN_NEVER = (*_COMMON_NEVER, "suits", "ties", "hats")
_WOMEN_NEVER = (*_COMMON_NEVER, "heels", "skirts", "dresses", "crop_tops")


def never_wear_options(department: str | None) -> tuple[str, ...]:
    """Never-wear choices adapted to the department."""
    if department == "menswear":
        return _MEN_NEVER
    if department == "womenswear":
        return _WOMEN_NEVER
    return tuple(dict.fromkeys((*_MEN_NEVER, *_WOMEN_NEVER)))


def validate_answers(answers: dict[str, Any]) -> None:
    """Raises ValueError describing the first invalid field."""
    allowed = {"department", "fit", "colors", "never_wear", "dress_code", "goals"}
    unknown = set(answers) - allowed
    if unknown:
        raise ValueError(f"unknown answer(s): {sorted(unknown)}")
    if "department" in answers and answers["department"] not in DEPARTMENTS:
        raise ValueError("department")
    if "fit" in answers and answers["fit"] not in FITS:
        raise ValueError("fit")
    if "colors" in answers and not set(answers["colors"]) <= set(COLORS):
        raise ValueError("colors")
    if "goals" in answers and not set(answers["goals"]) <= set(GOALS):
        raise ValueError("goals")
    if "dress_code" in answers and answers["dress_code"] not in range(DRESS_CODE_LEVELS):
        raise ValueError("dress_code")
    if "never_wear" in answers and not set(answers["never_wear"]) <= set(
        never_wear_options(answers.get("department"))
    ):
        raise ValueError("never_wear")


def compute_weights(answers: dict[str, Any]) -> dict[str, Any]:
    """Map quiz answers to preference weights (all in [-1, 1])."""
    fit = answers.get("fit")
    fav = set(answers.get("colors", []))
    never = set(answers.get("never_wear", []))
    goals = set(answers.get("goals", []))

    color_weights = {c: (1.0 if c in fav else 0.0) for c in COLORS}
    if "bright_colors" in never:
        for c in BRIGHT_COLORS:
            color_weights[c] = -1.0  # explicit dislike overrides a favourite

    dress_code = answers.get("dress_code")
    return {
        "version": MODEL_VERSION,
        "department": answers.get("department"),
        "fit": {f: (1.0 if f == fit else 0.0) for f in FITS},
        "colors": color_weights,
        "formality": None if dress_code is None else dress_code / (DRESS_CODE_LEVELS - 1),
        "goals": {g: (1.0 if g in goals else 0.0) for g in GOALS},
        "blocked": sorted(never - {"bright_colors"}),
    }
