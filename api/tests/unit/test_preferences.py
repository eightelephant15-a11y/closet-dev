import pytest

from app.domain.preferences import (
    compute_weights,
    never_wear_options,
    validate_answers,
)

BASE = {"department": "womenswear", "fit": "regular", "colors": ["navy"], "dress_code": 2}


def test_fit_answer_changes_weights() -> None:
    relaxed = compute_weights({**BASE, "fit": "relaxed"})["fit"]
    slim = compute_weights({**BASE, "fit": "slim"})["fit"]
    assert relaxed == {"relaxed": 1.0, "regular": 0.0, "slim": 0.0}
    assert slim == {"relaxed": 0.0, "regular": 0.0, "slim": 1.0}


def test_colours_and_bright_exclusion() -> None:
    w = compute_weights({**BASE, "colors": ["navy", "red"]})["colors"]
    assert w["navy"] == w["red"] == 1.0 and w["olive"] == 0.0
    w2 = compute_weights({**BASE, "colors": ["navy", "red"], "never_wear": ["bright_colors"]})
    assert w2["colors"]["red"] == -1.0 and w2["colors"]["navy"] == 1.0
    assert "bright_colors" not in w2["blocked"]


def test_never_wear_blocks_categories_and_formality_scales() -> None:
    w = compute_weights({**BASE, "never_wear": ["heels", "skirts"], "dress_code": 4})
    assert w["blocked"] == ["heels", "skirts"]
    assert w["formality"] == 1.0
    assert compute_weights({**BASE, "dress_code": 0})["formality"] == 0.0


def test_goals_and_department() -> None:
    w = compute_weights({**BASE, "goals": ["work", "travel"]})
    assert w["goals"] == {"work": 1.0, "dates": 0.0, "travel": 1.0, "everyday": 0.0}
    assert w["department"] == "womenswear"


def test_empty_answers_are_neutral() -> None:
    w = compute_weights({})
    assert w["formality"] is None and w["blocked"] == []
    assert all(v == 0.0 for v in w["fit"].values())


def test_never_wear_options_adapt_to_department() -> None:
    assert "heels" in never_wear_options("womenswear")
    assert "heels" not in never_wear_options("menswear")
    assert "ties" in never_wear_options("menswear")
    both = never_wear_options("both")
    assert "heels" in both and "ties" in both


@pytest.mark.parametrize(
    "bad",
    [
        {"department": "kids"},
        {"fit": "baggy"},
        {"colors": ["chartreuse"]},
        {"dress_code": 9},
        {"goals": ["sleep"]},
        {"department": "menswear", "never_wear": ["heels"]},
        {"unknown": 1},
    ],
)
def test_validation_rejects(bad: dict[str, object]) -> None:
    with pytest.raises(ValueError):
        validate_answers(bad)
