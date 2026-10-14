"""Builds eval/sample_dataset: 50 tiny synthetic "photos" with labels. No real photos, no network.

    python3 eval/make_sample_dataset.py        # (re)generate

The first 48 file names carry hints the *fake* provider understands (``navy_jeans_f2.png``), so the fake
scores well; the last two are deliberately anonymous so the report shows real mistakes and the
confusion table. With a real provider these flat-colour rectangles are NOT meaningful: use real photos.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).parent / "sample_dataset"
HEX = {"black": "#1A1A1A", "white": "#F2F2F2", "grey": "#8E8E93", "navy": "#1B2A55", "blue": "#1976D2", "red": "#D32F2F",
       "green": "#388E3C", "beige": "#D9C7A3", "brown": "#6B4A32", "pink": "#F48FB1", "olive": "#6B6B2F", "yellow": "#FBC02D",
       "burgundy": "#7B1E3A", "cream": "#F5EFE0", "purple": "#7B1FA2", "orange": "#F57C00", "teal": "#00897B", "light_blue": "#90CAF9"}  # fmt: skip
ALL = ["spring", "summer", "autumn", "winter"]
# (colour, subcategory, category, formality, seasons, fit, material)
SPEC = [
    ("navy", "jeans", "bottom", 2, ALL, "slim", "denim"), ("white", "t_shirt", "top", 1, ["spring", "summer"], "regular", "cotton"),
    ("black", "trousers", "bottom", 4, ALL, "slim", None), ("grey", "sweater", "top", 2, ["autumn", "winter"], "relaxed", "wool"),
    ("red", "casual_dress", "dress", 3, ["spring", "summer"], None, None), ("beige", "chinos", "bottom", 3, ["spring", "summer", "autumn"], "regular", "cotton"),
    ("white", "sneakers", "footwear", 2, ALL, None, None), ("brown", "loafers", "footwear", 4, ALL, None, "leather"),
    ("navy", "blazer", "outerwear", 4, ["spring", "autumn", "winter"], "slim", "wool"), ("olive", "jacket", "outerwear", 2, ["spring", "autumn"], "regular", "cotton"),
    ("pink", "blouse", "top", 3, ["spring", "summer"], "regular", "silk"), ("black", "heels", "footwear", 4, ALL, None, None),
    ("blue", "shirt", "top", 3, ALL, "regular", "cotton"), ("green", "hoodie", "top", 1, ["autumn", "winter"], "oversized", "cotton"),
    ("cream", "cardigan", "top", 3, ["autumn", "winter"], "relaxed", "knit"), ("burgundy", "skirt", "bottom", 3, ["autumn", "winter"], None, None),
    ("yellow", "tank_top", "top", 2, ["summer"], "regular", "cotton"), ("brown", "boots", "footwear", 3, ["autumn", "winter"], None, "leather"),
    ("grey", "joggers", "bottom", 1, ALL, "relaxed", "cotton"), ("white", "shirt", "top", 4, ALL, "slim", "cotton"),
    ("navy", "coat", "outerwear", 4, ["winter"], "regular", "wool"), ("black", "puffer", "outerwear", 2, ["winter"], "oversized", "nylon"),
    ("purple", "scarf", "accessory", 3, ["autumn", "winter"], None, "wool"), ("beige", "belt", "accessory", 3, ALL, None, "leather"),
]  # fmt: skip


def swatch(path: Path, color: str, shape: str) -> None:
    img = Image.new("RGB", (96, 128), (246, 246, 248))
    d = ImageDraw.Draw(img)
    c = HEX[color]
    if shape in ("bottom", "dress"):
        d.polygon([(30, 14), (66, 14), (74, 114), (22, 114)], fill=c)
    elif shape == "footwear":
        d.ellipse([12, 56, 84, 100], fill=c)
    else:
        d.rectangle([22, 20, 74, 108], fill=c)
    img.save(path)


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for old in OUT.glob("*"):
        old.unlink()
    items = []
    n = 0
    for rep in range(2):
        for color, sub, cat, formality, seasons, fit, material in SPEC:
            n += 1
            if n > 48:
                break
            name = f"{n:02d}_{color}_{sub}_f{formality}" + (f"_{fit}" if fit else "") + (f"_{material}" if material else "")
            name += "_" + "_".join(seasons) if seasons != ALL else ""
            file = f"{name}.png"
            swatch(OUT / file, color, cat)
            items.append({"file": file, "labels": {"category": cat, "subcategory": sub, "primary_color": color, "secondary_color": None,
                                                   "pattern": "solid", "formality": formality, "seasons": seasons, "fit": fit, "material": material}})  # fmt: skip
    # two anonymous photos: the fake provider can only guess these
    for k, (color, sub, cat, f, seasons) in enumerate([("teal", "polo", "top", 3, ["spring", "summer"]), ("orange", "raincoat", "outerwear", 2, ["spring", "autumn"])], 49):
        file = f"IMG_{k:04d}.png"
        swatch(OUT / file, color, cat)
        items.append({"file": file, "labels": {"category": cat, "subcategory": sub, "primary_color": color, "secondary_color": None,
                                               "pattern": "solid", "formality": f, "seasons": seasons, "fit": None, "material": None}})  # fmt: skip
    (OUT / "labels.json").write_text(json.dumps({"taxonomy_version": 1, "items": items}, indent=2) + "\n")
    print(f"wrote {len(items)} images + labels.json to {OUT}")


if __name__ == "__main__":
    main()
