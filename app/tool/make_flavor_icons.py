"""Creates AppIcon-dev / AppIcon-staging from the base iOS icon set by adding a coloured band.

Placeholder art: replace ios/Runner/Assets.xcassets/AppIcon.appiconset with the real icon, then
re-run `python3 tool/make_flavor_icons.py` to regenerate the badged dev/staging variants.
"""

import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ASSETS = Path(__file__).resolve().parents[1] / "ios/Runner/Assets.xcassets"
BASE = ASSETS / "AppIcon.appiconset"
FLAVORS = {"dev": ("DEV", (230, 126, 34)), "staging": ("STG", (41, 128, 185))}


def badge(src: Path, dst: Path, label: str, color: tuple[int, int, int]) -> None:
    img = Image.open(src).convert("RGB")
    w, h = img.size
    band_h = max(round(h * 0.26), 4)
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, h - band_h, w, h], fill=color)
    size = max(round(band_h * 0.7), 6)
    font = ImageFont.load_default(size=size)
    bbox = draw.textbbox((0, 0), label, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((w - tw) / 2 - bbox[0], h - band_h + (band_h - th) / 2 - bbox[1]), label,
              fill=(255, 255, 255), font=font)
    img.save(dst)


for flavor, (label, color) in FLAVORS.items():
    out = ASSETS / f"AppIcon-{flavor}.appiconset"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir()
    shutil.copy(BASE / "Contents.json", out / "Contents.json")
    for png in BASE.glob("*.png"):
        badge(png, out / png.name, label, color)
    contents = json.loads((out / "Contents.json").read_text())
    assert contents["images"], "empty icon set"
    print("wrote", out.relative_to(ASSETS.parent.parent))
