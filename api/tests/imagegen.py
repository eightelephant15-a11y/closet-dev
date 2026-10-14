"""Builds small test images in memory (no binary fixtures in git)."""

import io

from PIL import Image, ImageDraw
from pillow_heif import register_heif_opener

register_heif_opener()


def garment_image(
    size: tuple[int, int] = (320, 480),
    *,
    fmt: str = "JPEG",
    color: tuple[int, int, int] = (30, 60, 140),
    background: tuple[int, int, int] = (250, 250, 250),
    exif_orientation: int | None = None,
    gps: bool = False,
    alpha: bool = False,
) -> bytes:
    mode = "RGBA" if alpha else "RGB"
    img = Image.new(mode, size, (*background, 0) if alpha else background)
    d = ImageDraw.Draw(img)
    w, h = size
    d.rectangle([w * 0.2, h * 0.15, w * 0.8, h * 0.85], fill=(*color, 255) if alpha else color)
    out = io.BytesIO()
    kwargs: dict[str, object] = {}
    if fmt in ("JPEG", "WEBP", "PNG", "HEIF"):
        exif = Image.Exif()
        if exif_orientation:
            exif[0x0112] = exif_orientation
        if gps:
            exif[0x010F] = "SecretPhoneMaker"  # Make
            exif[0x0110] = "SecretModel"
            exif.get_ifd(0x8825)  # create GPS IFD
            exif[0x8825] = {1: "N", 2: (30.0, 15.0, 0.0), 3: "W", 4: (97.0, 44.0, 0.0)}
        if exif_orientation or gps:
            kwargs["exif"] = exif.tobytes()
    if fmt == "JPEG":
        img = img.convert("RGB")
    if fmt == "HEIF":
        img.convert("RGB").save(out, format="HEIF", **kwargs)
    else:
        img.save(out, format=fmt, **kwargs)
    return out.getvalue()
