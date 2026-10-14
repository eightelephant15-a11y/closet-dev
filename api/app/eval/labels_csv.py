"""Turns a spreadsheet of labels into labels.json:  python -m app.eval.labels_csv labels.csv > labels.json

CSV columns: file,category,subcategory,primary_color,secondary_color,pattern,formality,seasons,fit,material
(seasons separated by | e.g. ``spring|summer``; leave secondary_color / fit / material empty when none).
"""

import csv
import json
import sys
from pathlib import Path

from app.domain import taxonomy as tx


def convert(path: Path) -> dict[str, object]:
    items = []
    with path.open(newline="") as f:
        for n, row in enumerate(csv.DictReader(f), start=2):
            labels: dict[str, object] = {
                "category": row["category"].strip(),
                "subcategory": row["subcategory"].strip(),
                "primary_color": row["primary_color"].strip(),
                "secondary_color": row.get("secondary_color", "").strip() or None,
                "pattern": row["pattern"].strip(),
                "formality": int(row["formality"]),
                "seasons": [s.strip() for s in row["seasons"].split("|") if s.strip()],
                "fit": row.get("fit", "").strip() or None,
                "material": row.get("material", "").strip() or None,
            }
            _, errors = tx.validate_fields(labels, require_core=True)
            if errors:
                raise ValueError(
                    f"row {n} ({row['file']}): "
                    + "; ".join(f"{e.field}: {e.message}" for e in errors)
                )
            items.append({"file": row["file"].strip(), "labels": labels})
    return {"taxonomy_version": tx.TAXONOMY_VERSION, "items": items}


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        print(json.dumps(convert(Path(sys.argv[1])), indent=2))
    except (ValueError, KeyError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
