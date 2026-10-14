import importlib.util
import json
from pathlib import Path

import jsonschema
import pytest

from app.domain import preferences as quiz
from app.domain import taxonomy as tx

REPO = Path(__file__).resolve().parents[3]
VALID = {
    "category": "top",
    "subcategory": "t_shirt",
    "primary_color": "navy",
    "secondary_color": None,
    "pattern": "solid",
    "formality": 2,
    "seasons": ["summer", "spring"],
    "fit": "regular",
    "material": "cotton",
}


def test_generated_files_match_the_single_source_of_truth() -> None:
    """Edit taxonomy/garment_taxonomy.v1.json, then run: python3 tool/gen_taxonomy.py"""
    spec = importlib.util.spec_from_file_location("gen_taxonomy", REPO / "tool/gen_taxonomy.py")
    assert spec and spec.loader
    gen = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gen)
    outputs = gen.build()
    py_out = REPO / "api/app/domain/taxonomy_data.py"
    assert py_out.read_text() == outputs[py_out]
    assert json.loads((REPO / "taxonomy/garment_taxonomy.v1.json").read_text()) == tx.TAXONOMY


def test_structure_is_consistent() -> None:
    subs = [s["id"] for c in tx.TAXONOMY["categories"] for s in c["subcategories"]]
    assert len(subs) == len(set(subs)), "subcategory ids must be unique"
    assert set(tx.CATEGORIES) == {"top", "bottom", "outerwear", "footwear", "dress", "accessory"}
    assert len(tx.COLORS) == len(set(tx.COLORS))
    assert all(h.startswith("#") and len(h) == 7 for h in tx.COLOR_HEX.values())
    assert tx.FORMALITY == (1, 2, 3, 4, 5)
    for group in tx.TAXONOMY["avoid_groups"].values():
        assert set(group.get("subcategories", [])) <= set(subs)
        assert set(group.get("categories", [])) <= set(tx.CATEGORIES)


def test_matches_phase1_quiz_vocabulary() -> None:
    """Colours from the style quiz are in the palette, and 'bright' agrees with the never-wear rule."""
    assert set(quiz.COLORS) <= set(tx.COLORS)
    assert set(quiz.BRIGHT_COLORS) == set(tx.BRIGHT_COLORS)
    assert set(tx.TAXONOMY["avoid_groups"]) == set(quiz.never_wear_options("everything"))


@pytest.mark.parametrize(
    ("department", "present", "absent"),
    [
        (
            "menswear",
            {"tie", "t_shirt", "suit_jacket"},
            {"heels", "skirt", "casual_dress", "crop_top"},
        ),
        ("womenswear", {"heels", "skirt", "casual_dress"}, {"tie"}),
        ("both", {"tie", "heels"}, set()),
        ("everything", {"tie", "heels"}, set()),
        (None, {"tie", "heels"}, set()),
    ],
)
def test_department_filtering(department: str | None, present: set[str], absent: set[str]) -> None:
    visible = tx.visible_subcategories(department)
    assert present <= visible
    assert not (absent & visible)


def test_menswear_does_not_see_the_dress_category() -> None:
    assert "dress" not in tx.visible_categories("menswear")
    assert "dress" in tx.visible_categories("womenswear")


def test_valid_garment_passes_and_is_normalised() -> None:
    clean, errors = tx.validate_fields(VALID, require_core=True)
    assert not errors
    assert clean["seasons"] == ["spring", "summer"]  # canonical order


@pytest.mark.parametrize(
    ("patch", "field"),
    [
        ({"category": "hat"}, "category"),
        ({"subcategory": "jeans"}, "subcategory"),  # belongs to bottom, not top
        ({"subcategory": "made_up"}, "subcategory"),
        ({"primary_color": "chartreuse"}, "primary_color"),
        ({"secondary_color": "navy"}, "secondary_color"),  # same as primary
        ({"pattern": "tartan"}, "pattern"),
        ({"formality": 0}, "formality"),
        ({"formality": 6}, "formality"),
        ({"formality": True}, "formality"),
        ({"formality": "3"}, "formality"),
        ({"seasons": []}, "seasons"),
        ({"seasons": ["monsoon"]}, "seasons"),
        ({"fit": "baggy"}, "fit"),
        ({"material": "unobtainium"}, "material"),
        ({"brand": "x" * 61}, "brand"),
        ({"notes": "x" * 501}, "notes"),
        ({"bogus": 1}, "bogus"),
    ],
)
def test_invalid_values_are_rejected(patch: dict[str, object], field: str) -> None:
    _, errors = tx.validate_fields({**VALID, **patch})
    assert field in {e.field for e in errors}


def test_optional_fields_accept_null_and_core_fields_are_required() -> None:
    clean, errors = tx.validate_fields({**VALID, "fit": None, "material": None, "brand": None})
    assert not errors and clean["fit"] is None
    _, errors = tx.validate_fields({"category": "top"}, require_core=True)
    assert {"subcategory", "primary_color", "pattern", "formality", "seasons"} <= {
        e.field for e in errors
    }


def test_ai_schema_accepts_valid_and_rejects_invalid_results() -> None:
    schema = tx.ai_result_schema()
    jsonschema.Draft202012Validator.check_schema(schema)
    good = {f: {"value": VALID[f], "confidence": 0.9} for f in tx.AI_FIELDS}
    jsonschema.validate(good, schema)

    bad_value = json.loads(json.dumps(good))
    bad_value["primary_color"]["value"] = "chartreuse"
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(bad_value, schema)

    bad_conf = json.loads(json.dumps(good))
    bad_conf["category"]["confidence"] = 1.5
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(bad_conf, schema)

    missing = json.loads(json.dumps(good))
    del missing["pattern"]
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(missing, schema)


def test_prompt_guide_is_built_from_the_taxonomy() -> None:
    guide = tx.prompt_guide()
    for needle in ("t_shirt", "burgundy=#7B1E3A", "polka_dot", "4=Business"):
        assert needle in guide
