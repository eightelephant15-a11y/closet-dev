import csv
import json
from pathlib import Path
from typing import Any

import pytest

from app.eval import labels_csv
from app.eval import vision_eval as ve
from app.vision import VisionError, VisionResult, VisionUsage
from tests.imagegen import garment_image

REPO = Path(__file__).resolve().parents[3]
LABEL = {
    "category": "bottom", "subcategory": "jeans", "primary_color": "navy", "secondary_color": None,
    "pattern": "solid", "formality": 2, "seasons": ["spring", "summer"], "fit": None, "material": None,
}  # fmt: skip


def fields(**over: Any) -> dict[str, dict[str, Any]]:
    return {k: {"value": v, "confidence": 0.9} for k, v in (LABEL | over).items()}


class Scripted:
    name, model, version = "scripted", "s-1", "1"

    def __init__(self, answers: list[Any], cost: float | None = 0.01) -> None:
        self.answers, self.cost, self.i = answers, cost, 0

    async def analyse(self, image: bytes, **_: Any) -> VisionResult:
        a = self.answers[self.i % len(self.answers)]
        self.i += 1
        if isinstance(a, Exception):
            raise a
        return VisionResult(fields=a, provider="scripted", model="s-1", version="1", latency_ms=100 + self.i,
                            usage=VisionUsage(input_tokens=1000, output_tokens=100, cost_usd=self.cost))  # fmt: skip


def make_dataset(tmp_path: Path, n: int = 10, **label_over: Any) -> Path:
    items = []
    for i in range(n):
        f = f"img{i}.jpg"
        (tmp_path / f).write_bytes(garment_image())
        items.append({"file": f, "labels": LABEL | label_over})
    (tmp_path / "labels.json").write_text(json.dumps({"taxonomy_version": 1, "items": items}))
    return tmp_path


async def evaluate(
    tmp_path: Path, provider: Scripted, n: int = 10, **label_over: Any
) -> dict[str, Any]:
    folder = make_dataset(tmp_path, n, **label_over)
    out = await ve.run(folder, ve.load_dataset(folder), provider)
    return ve.score(out)


# ---- metrics --------------------------------------------------------------------------------------


async def test_perfect_provider_scores_100_and_meets_every_target(tmp_path: Path) -> None:
    r = await evaluate(tmp_path, Scripted([fields()]))
    assert all(
        r["fields"][f]["accuracy"] == 1.0
        for f in ("category", "subcategory", "primary_color", "pattern", "formality", "seasons")
    )
    assert all(t["pass"] for t in r["targets"].values()) and r["confusions"] == {}


async def test_accuracy_per_field_and_confusions(tmp_path: Path) -> None:
    wrong_cat = fields(category="top", subcategory="t_shirt")
    answers = [fields()] * 7 + [wrong_cat] * 3  # category right 7/10
    r = await evaluate(tmp_path, Scripted(answers))
    assert r["fields"]["category"]["accuracy"] == pytest.approx(0.7)
    assert (
        r["targets"]["category"]["pass"] is False and r["targets"]["primary_color"]["pass"] is True
    )
    assert r["confusions"]["category"] == [{"label": "bottom", "predicted": "top", "count": 3}]


async def test_formality_is_scored_exactly_and_within_one_point(tmp_path: Path) -> None:
    answers = [fields(formality=2)] * 5 + [fields(formality=3)] * 3 + [fields(formality=5)] * 2
    r = await evaluate(tmp_path, Scripted(answers))
    assert r["fields"]["formality"]["accuracy"] == pytest.approx(0.5)
    assert r["fields"]["formality_within_1"]["accuracy"] == pytest.approx(0.8)
    assert r["targets"]["formality_within_1"]["pass"] is True  # exactly at the 80% target


async def test_seasons_need_the_exact_set_and_optional_fields_only_count_when_labelled(
    tmp_path: Path,
) -> None:
    r = await evaluate(
        tmp_path,
        Scripted([fields(seasons=["summer", "spring"])] * 2 + [fields(seasons=["summer"])] * 2),
        n=4,
    )
    assert r["fields"]["seasons"]["accuracy"] == pytest.approx(
        0.5
    )  # order does not matter, membership does
    assert (
        r["fields"]["fit"]["n"] == 0 and r["fields"]["fit"]["accuracy"] is None
    )  # nobody labelled fit
    labelled = (
        await evaluate(tmp_path / "x", Scripted([fields(fit="slim")]), n=4, fit="slim")
        if (tmp_path / "x").mkdir() is None
        else {}
    )
    assert labelled["fields"]["fit"]["n"] == 4


async def test_failed_images_count_against_the_score_and_are_listed(tmp_path: Path) -> None:
    answers = [fields()] * 8 + [VisionError("boom")] * 2
    r = await evaluate(tmp_path, Scripted(answers))
    assert r["answered"] == 8 and len(r["errors"]) == 2
    assert r["fields"]["category"]["accuracy"] == pytest.approx(0.8)
    assert r["confusions"]["category"][0]["predicted"] == "ERROR"


async def test_confidence_calibration(tmp_path: Path) -> None:
    good = fields()
    shaky = {
        k: {**v, "confidence": 0.4}
        for k, v in fields(category="top", subcategory="t_shirt").items()
    }
    r = await evaluate(tmp_path, Scripted([good] * 6 + [shaky] * 4))
    cal = r["calibration"]
    assert cal["high_confidence"]["accuracy"] > cal["low_confidence"]["accuracy"]
    assert cal["low_confidence"]["n"] > 0


async def test_cost_and_latency(tmp_path: Path) -> None:
    r = await evaluate(tmp_path, Scripted([fields()], cost=0.02))
    assert r["cost"]["input_tokens"] == 10_000 and r["cost"]["usd"] == pytest.approx(0.2)
    assert r["cost"]["usd_per_1000_images"] == pytest.approx(20.0)
    assert r["latency_ms"]["p50"] >= 100
    unknown = (
        await evaluate(tmp_path / "u", Scripted([fields()], cost=None))
        if (tmp_path / "u").mkdir() is None
        else {}
    )
    assert unknown["cost"]["usd"] is None and "unknown" in ve.render(unknown, "claude", "m")


# ---- dataset loading --------------------------------------------------------------------------------


def test_dataset_problems_are_reported_together(tmp_path: Path) -> None:
    (tmp_path / "ok.jpg").write_bytes(garment_image())
    doc = {"taxonomy_version": 1, "items": [
        {"file": "ok.jpg", "labels": {**LABEL, "primary_color": "chartreuse"}},
        {"file": "missing.jpg", "labels": LABEL},
    ]}  # fmt: skip
    (tmp_path / "labels.json").write_text(json.dumps(doc))
    with pytest.raises(ve.DatasetError) as exc:
        ve.load_dataset(tmp_path)
    assert "chartreuse" in str(exc.value) or "primary_color" in str(exc.value)
    assert "missing.jpg" in str(exc.value)


@pytest.mark.parametrize(
    "content",
    ["not json", json.dumps({"taxonomy_version": 99, "items": []}), json.dumps({"items": []})],
)
def test_bad_label_files_are_rejected(tmp_path: Path, content: str) -> None:
    (tmp_path / "labels.json").write_text(content)
    with pytest.raises(ve.DatasetError):
        ve.load_dataset(tmp_path)


def test_missing_labels_file(tmp_path: Path) -> None:
    with pytest.raises(ve.DatasetError, match="not found"):
        ve.load_dataset(tmp_path)


# ---- the CLI ----------------------------------------------------------------------------------------


def test_cli_refuses_to_spend_money_without_yes(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    folder = make_dataset(tmp_path, 2)
    assert ve.main([str(folder), "--provider", "claude"]) == 2
    assert "--yes" in capsys.readouterr().err


def test_cli_needs_a_key_for_claude(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    from app.core.config import get_settings

    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    get_settings.cache_clear()
    folder = make_dataset(tmp_path, 2)
    assert ve.main([str(folder), "--provider", "claude", "--yes"]) == 2
    assert "ANTHROPIC_API_KEY" in capsys.readouterr().err


def test_cli_exit_code_reflects_the_targets_and_writes_json(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    out = tmp_path / "report.json"
    code = ve.main([str(REPO / "eval/sample_dataset"), "--json", str(out)])
    text = capsys.readouterr().out
    assert code == 0 and "PASS  category" in text and "provider=fake" in text
    assert json.loads(out.read_text())["images"] == 50


def test_cli_fails_when_a_target_is_missed(tmp_path: Path) -> None:
    folder = make_dataset(
        tmp_path, 3, category="top", subcategory="t_shirt", primary_color="red"
    )  # the fake guesses otherwise
    (tmp_path / "anon0.jpg").write_bytes(garment_image())
    assert ve.main([str(folder)]) == 1
    assert ve.main([str(folder), "--no-fail"]) == 0


def test_cli_limit_and_raw_pipeline(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert ve.main([str(REPO / "eval/sample_dataset"), "--limit", "5", "--raw", "--no-fail"]) == 0
    assert "images=5" in capsys.readouterr().out


# ---- labelling helper -------------------------------------------------------------------------------


def test_csv_converter_builds_valid_labels(tmp_path: Path) -> None:
    path = tmp_path / "labels.csv"
    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            [
                "file",
                "category",
                "subcategory",
                "primary_color",
                "secondary_color",
                "pattern",
                "formality",
                "seasons",
                "fit",
                "material",
            ]
        )
        w.writerow(
            ["a.jpg", "top", "t_shirt", "white", "", "solid", "2", "spring|summer", "", "cotton"]
        )
    doc = labels_csv.convert(path)
    assert doc["taxonomy_version"] == 1
    item = doc["items"][0]  # type: ignore[index]
    assert item["labels"] == {
        **item["labels"],
        "seasons": ["spring", "summer"],
        "secondary_color": None,
        "fit": None,
        "formality": 2,
    }


def test_csv_converter_names_the_bad_row(tmp_path: Path) -> None:
    path = tmp_path / "labels.csv"
    path.write_text(
        "file,category,subcategory,primary_color,secondary_color,pattern,formality,seasons,fit,material\nb.jpg,top,jeans,white,,solid,2,summer,,\n"
    )
    with pytest.raises(ValueError, match=r"row 2 \(b.jpg\)"):
        labels_csv.convert(path)
