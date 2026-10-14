"""Accuracy evaluation of the configured vision provider on a labelled folder.

    python -m app.eval.vision_eval eval/sample_dataset                  # fake provider, free
    python -m app.eval.vision_eval ~/my_photos --provider claude --yes  # REAL calls: costs money, uploads photos

Dataset folder: the images plus ``labels.json`` (see docs/vision-eval.md):

    {"taxonomy_version": 1, "items": [{"file": "navy_jeans.jpg", "labels": {"category": "bottom", ...}}]}

Images go through the same processing pipeline as production uploads before reaching the provider, so
the numbers describe what users would get. Targets (exit code 1 if missed): category >= 92%, primary
colour >= 85%, formality within 1 point >= 80%.
"""

import argparse
import asyncio
import json
import statistics
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from app.domain import taxonomy as tx
from app.services import images as imgs
from app.vision import VisionError, VisionProvider, build_provider

TARGETS = {"category": 0.92, "primary_color": 0.85, "formality_within_1": 0.80}
HIGH_CONFIDENCE = 0.7


@dataclass(frozen=True)
class Item:
    file: str
    labels: dict[str, Any]
    department: str | None = None


@dataclass
class Outcome:
    item: Item
    predicted: dict[str, Any] | None  # field -> value
    confidence: dict[str, float] = field(default_factory=dict)
    error: str | None = None
    latency_ms: int = 0
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float | None = None


class DatasetError(Exception):
    pass


def load_dataset(folder: Path) -> list[Item]:
    path = folder / "labels.json"
    if not path.is_file():
        raise DatasetError(f"{path} not found")
    try:
        doc = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise DatasetError(f"labels.json is not valid JSON: {exc}") from exc
    if doc.get("taxonomy_version", tx.TAXONOMY_VERSION) != tx.TAXONOMY_VERSION:
        raise DatasetError(
            f"labels are for taxonomy v{doc['taxonomy_version']}, this is v{tx.TAXONOMY_VERSION}"
        )
    items: list[Item] = []
    problems: list[str] = []
    for n, raw in enumerate(doc.get("items", [])):
        file = raw.get("file", "")
        if not (folder / file).is_file():
            problems.append(f"item {n}: image {file!r} not found")
            continue
        clean, errors = tx.validate_fields(raw.get("labels", {}))
        if errors:
            problems.append(
                f"item {n} ({file}): " + "; ".join(f"{e.field}: {e.message}" for e in errors)
            )
            continue
        items.append(Item(file, clean, raw.get("department")))
    if problems:
        raise DatasetError("invalid dataset:\n  " + "\n  ".join(problems))
    if not items:
        raise DatasetError("labels.json has no items")
    return items


async def _prepare(folder: Path, item: Item, use_pipeline: bool) -> bytes:
    raw = (folder / item.file).read_bytes()
    if not use_pipeline:
        return raw
    clean, source, oriented = await asyncio.to_thread(
        imgs.normalise, raw, max_pixels=50_000_000, max_dimension=8000
    )
    return (await asyncio.to_thread(imgs.render, clean, source, oriented)).full


async def run(
    folder: Path,
    items: list[Item],
    provider: VisionProvider,
    *,
    concurrency: int = 4,
    use_pipeline: bool = True,
) -> list[Outcome]:
    sem = asyncio.Semaphore(concurrency)

    async def one(item: Item) -> Outcome:
        async with sem:
            try:
                data = await _prepare(folder, item, use_pipeline)
                result = await provider.analyse(
                    data,
                    media_type="image/webp",
                    hint=Path(item.file).name,
                    department=item.department,
                )
            except (VisionError, imgs.ImageRejected, OSError) as exc:
                return Outcome(item, None, error=f"{type(exc).__name__}: {exc}")
            return Outcome(
                item,
                {f: v["value"] for f, v in result.fields.items()},
                {f: float(v["confidence"]) for f, v in result.fields.items()},
                latency_ms=result.latency_ms,
                input_tokens=result.usage.input_tokens,
                output_tokens=result.usage.output_tokens,
                cost_usd=result.usage.cost_usd,
            )

    return list(await asyncio.gather(*(one(i) for i in items)))


def _correct(field_name: str, label: Any, pred: Any) -> bool:
    if field_name == "formality_within_1":
        return pred is not None and abs(int(pred) - int(label)) <= 1
    if field_name == "seasons":
        return set(label) == set(pred or [])
    return bool(label == pred)


def score(outcomes: list[Outcome]) -> dict[str, Any]:
    fields = ["category", "subcategory", "primary_color", "secondary_color", "pattern", "formality",
              "formality_within_1", "seasons", "fit", "material"]  # fmt: skip
    stats: dict[str, dict[str, Any]] = {}
    confusions: dict[str, Counter[tuple[str, str]]] = {f: Counter() for f in fields}
    for f in fields:
        base = "formality" if f == "formality_within_1" else f
        labelled = [
            o
            for o in outcomes
            if base in o.item.labels
            and (o.item.labels[base] is not None or base in ("secondary_color",))
        ]
        if f in ("fit", "material"):  # only score what the labeller actually decided
            labelled = [o for o in labelled if o.item.labels[base] is not None]
        n = len(labelled)
        right = 0
        for o in labelled:
            label = o.item.labels[base]
            pred = o.predicted.get(base) if o.predicted else None
            ok = o.predicted is not None and _correct(f, label, pred)
            right += ok
            if not ok and f not in ("formality_within_1",):
                confusions[f][(str(label), "ERROR" if o.predicted is None else str(pred))] += 1
        stats[f] = {"n": n, "correct": right, "accuracy": right / n if n else None}
    answered = [o for o in outcomes if o.predicted is not None]
    high_n = high_ok = low_n = low_ok = 0
    for o in answered:
        for f in ("category", "subcategory", "primary_color", "pattern", "formality"):
            if f not in o.item.labels:
                continue
            ok = _correct(f, o.item.labels[f], o.predicted.get(f) if o.predicted else None)
            if o.confidence.get(f, 0) >= HIGH_CONFIDENCE:
                high_n += 1
                high_ok += ok
            else:
                low_n += 1
                low_ok += ok
    costs = [o.cost_usd for o in answered]
    latencies = sorted(o.latency_ms for o in answered)
    total_cost = (
        None
        if any(c is None for c in costs) or not costs
        else sum(c for c in costs if c is not None)
    )
    return {
        "images": len(outcomes),
        "answered": len(answered),
        "errors": [{"file": o.item.file, "error": o.error} for o in outcomes if o.error],
        "fields": stats,
        "confusions": {
            f: [
                {"label": a, "predicted": b, "count": c}
                for (a, b), c in confusions[f].most_common(5)
            ]
            for f in fields
            if confusions[f]
        },
        "calibration": {
            "high_confidence": {"n": high_n, "accuracy": high_ok / high_n if high_n else None},
            "low_confidence": {"n": low_n, "accuracy": low_ok / low_n if low_n else None},
        },
        "cost": {
            "input_tokens": sum(o.input_tokens for o in answered),
            "output_tokens": sum(o.output_tokens for o in answered),
            "usd": total_cost,
            "usd_per_1000_images": None
            if total_cost is None or not answered
            else total_cost / len(answered) * 1000,
        },
        "latency_ms": {
            "p50": statistics.median(latencies) if latencies else None,
            "p95": latencies[max(int(len(latencies) * 0.95) - 1, 0)] if latencies else None,
        },
        "targets": {
            k: {
                "target": t,
                "actual": stats[k]["accuracy"],
                "pass": (stats[k]["accuracy"] or 0) >= t,
            }
            for k, t in TARGETS.items()
        },
    }


def _pct(x: float | None) -> str:
    return "   n/a" if x is None else f"{x * 100:5.1f}%"


def render(report: dict[str, Any], provider: str, model: str) -> str:
    out = [
        f"Vision evaluation: provider={provider} model={model} images={report['images']} answered={report['answered']}",
        "",
    ]
    out.append(f"{'field':<20}{'n':>5}  {'accuracy':>9}  note")
    notes = {
        "formality_within_1": "within 1 point",
        "seasons": "exact set match",
        "secondary_color": "incl. 'none'",
    }
    for f, s in report["fields"].items():
        out.append(f"{f:<20}{s['n']:>5}  {_pct(s['accuracy']):>9}  {notes.get(f, '')}")
    out.append("")
    out.append("Targets:")
    for k, t in report["targets"].items():
        out.append(
            f"  {'PASS' if t['pass'] else 'FAIL'}  {k:<20} {_pct(t['actual'])} (target {t['target'] * 100:.0f}%)"
        )
    if report["confusions"]:
        out += ["", "Most common mistakes (label -> predicted):"]
        for f, rows in report["confusions"].items():
            if f in ("seasons", "secondary_color", "subcategory", "formality"):
                continue
            out.append(
                f"  {f}: "
                + ", ".join(f"{r['label']}->{r['predicted']} x{r['count']}" for r in rows)
            )
    cal = report["calibration"]
    out += ["", "Confidence is useful if high-confidence answers are right more often than low-confidence ones:",
            f"  >= {HIGH_CONFIDENCE}: {cal['high_confidence']['n']} answers, {_pct(cal['high_confidence']['accuracy'])} right",
            f"  <  {HIGH_CONFIDENCE}: {cal['low_confidence']['n']} answers, {_pct(cal['low_confidence']['accuracy'])} right"]  # fmt: skip
    c = report["cost"]
    usd = (
        "unknown (no price for this model)"
        if c["usd"] is None
        else f"${c['usd']:.4f}  (${c['usd_per_1000_images']:.2f} per 1000 photos)"
    )
    out += ["", f"Tokens: {c['input_tokens']} in / {c['output_tokens']} out   Cost: {usd}",
            f"Latency: p50 {report['latency_ms']['p50']} ms, p95 {report['latency_ms']['p95']} ms"]  # fmt: skip
    if report["errors"]:
        out += ["", f"{len(report['errors'])} image(s) failed:"] + [
            f"  {e['file']}: {e['error']}" for e in report["errors"][:10]
        ]
    return "\n".join(out)


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="python -m app.eval.vision_eval", description=__doc__.split("\n\n")[0]
    )
    p.add_argument("dataset", type=Path, help="folder with images + labels.json")
    p.add_argument("--provider", default="fake", choices=["fake", "claude"])
    p.add_argument("--limit", type=int, help="only the first N items")
    p.add_argument("--concurrency", type=int, default=4)
    p.add_argument("--raw", action="store_true", help="skip the production image pipeline")
    p.add_argument("--json", type=Path, help="also write the full report as JSON")
    p.add_argument(
        "--yes",
        action="store_true",
        help="required for --provider claude: confirms real, billed API calls",
    )
    p.add_argument("--no-fail", action="store_true", help="always exit 0 (just print)")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.provider == "claude" and not args.yes:
        print(
            "Refusing to call the real API without --yes: this uploads your photos to Anthropic and costs money.\nTry --limit 10 first.",
            file=sys.stderr,
        )
        return 2
    try:
        items = load_dataset(args.dataset)
    except DatasetError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    if args.limit:
        items = items[: args.limit]
    try:
        provider = build_provider(args.provider)
    except VisionError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    outcomes = asyncio.run(
        run(args.dataset, items, provider, concurrency=args.concurrency, use_pipeline=not args.raw)
    )
    report = score(outcomes)
    print(render(report, provider.name, provider.model))
    if args.json:
        args.json.write_text(json.dumps(report, indent=2))
    failed = [k for k, t in report["targets"].items() if not t["pass"]]
    return 0 if args.no_fail or not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
