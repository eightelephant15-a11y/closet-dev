"""Draws the bundled sample-closet pictures (flat illustrations, no photos, no network).

    api/.venv/bin/python tool/make_sample_images.py

Reads `api/app/data/sample_closet.py` and writes `app/assets/sample_closet/<asset>.webp` (400x400).
Re-running produces identical files.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "api"))

from app.data.sample_closet import SAMPLE_GARMENTS  # noqa: E402

OUT = ROOT / "app" / "assets" / "sample_closet"
S = 400
BG = (244, 243, 240)


def hex_rgb(h: str) -> tuple[int, int, int]:
    return int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)


def shade(c: tuple[int, int, int], f: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(v * f))) for v in c)  # type: ignore[return-value]


def draw(category: str, sub: str, col: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (S, S), BG)
    d = ImageDraw.Draw(img)
    dark = shade(col, 0.78)
    if category == "top":
        sleeve = 0 if sub in ("tank_top",) else 70
        short = sub in ("t_shirt", "polo", "crop_top")
        bottom = 250 if sub == "crop_top" else 330
        d.polygon([(130, 70), (270, 70), (330 if not short else 310, 130 if not short else 120),
                   (300 if not short else 290, 165), (270, 150), (270, bottom), (130, bottom), (130, 150),
                   (100 if not short else 110, 165), (70 if not short else 90, 130 if not short else 120)], fill=col)
        if sleeve == 0:
            d.rectangle([130, 70, 270, bottom], fill=col)
        d.ellipse([170, 56, 230, 100], fill=BG)
        d.line([(130, 150), (130, bottom)], fill=dark, width=3)
    elif category == "bottom":
        if sub == "skirt":
            d.polygon([(140, 80), (260, 80), (320, 320), (80, 320)], fill=col)
        elif sub == "shorts":
            d.polygon([(130, 80), (270, 80), (285, 230), (210, 230), (200, 150), (190, 230), (115, 230)], fill=col)
        else:
            d.polygon([(130, 70), (270, 70), (290, 340), (215, 340), (200, 160), (185, 340), (110, 340)], fill=col)
        d.rectangle([130, 70, 270, 92], fill=dark)
    elif category == "footwear":
        if sub == "heels":
            d.polygon([(90, 250), (220, 210), (310, 250), (310, 290), (90, 290)], fill=col)
            d.polygon([(95, 270), (125, 270), (125, 330), (105, 330)], fill=dark)
        else:
            d.rounded_rectangle([70, 190, 330, 290], radius=40, fill=col)
            d.rectangle([70, 270, 330, 300], fill=dark)
    elif category == "dress":
        d.polygon([(165, 60), (235, 60), (250, 160), (320, 350), (80, 350), (150, 160)], fill=col)
        d.rectangle([150, 150, 250, 172], fill=dark)
    elif category == "outerwear":
        d.polygon([(120, 60), (280, 60), (340, 140), (310, 190), (280, 160), (280, 345), (120, 345), (120, 160),
                   (90, 190), (60, 140)], fill=col)
        d.line([(200, 60), (200, 345)], fill=dark, width=4)
        d.polygon([(200, 60), (160, 60), (200, 120)], fill=dark)
        d.polygon([(200, 60), (240, 60), (200, 120)], fill=dark)
    else:
        d.ellipse([110, 110, 290, 290], fill=col)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = {c["id"]: hex_rgb(c["hex"]) for c in COLORS_DOC()}
    for g in SAMPLE_GARMENTS:
        draw(g["category"], g["subcategory"], palette[g["primary_color"]]).save(
            OUT / f"{g['asset']}.webp", quality=82, method=6
        )
    print(f"wrote {len(SAMPLE_GARMENTS)} images to {OUT}")


def COLORS_DOC() -> list[dict[str, str]]:  # noqa: N802
    import json

    doc = json.loads((ROOT / "taxonomy" / "garment_taxonomy.v1.json").read_text())
    return doc["palette"]  # type: ignore[no-any-return]


if __name__ == "__main__":
    main()
