"""Image pipeline (pure, CPU-bound; run it in a thread).

Validate by *content* (magic bytes, then a real decode), fix EXIF orientation, drop all metadata (EXIF,
GPS, ICC, XMP: we re-encode, never copy), convert HEIC/PNG/JPEG to WebP, optionally remove the background,
and produce three consistently presented square thumbnails.
"""

import io
from dataclasses import dataclass

from PIL import Image, ImageOps, UnidentifiedImageError

try:  # HEIC / HEIF support
    from pillow_heif import register_heif_opener

    register_heif_opener()
    HEIF_AVAILABLE = True
except ImportError:  # pragma: no cover
    HEIF_AVAILABLE = False

THUMB_SIZES: dict[str, int] = {"s": 200, "m": 600, "l": 1200}  # px, square
FULL_MAX_SIDE = 2048
THUMB_BACKGROUND = (244, 244, 246)  # neutral
THUMB_PADDING = 0.08  # fraction of the canvas left empty around the garment
WEBP_QUALITY = 82

_HEIF_BRANDS = {
    b"heic",
    b"heix",
    b"hevc",
    b"hevx",
    b"heim",
    b"heis",
    b"hevm",
    b"hevs",
    b"mif1",
    b"msf1",
}


class ImageRejected(Exception):
    """The upload is not an acceptable image. ``code`` is an API error code."""

    def __init__(self, code: str, message: str, status: int = 422) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status


def sniff_content_type(head: bytes) -> str | None:
    """Content type from the first bytes. The file extension and declared type are never trusted."""
    if head.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "image/webp"
    if head[4:8] == b"ftyp" and head[8:12] in _HEIF_BRANDS:
        return "image/heic"
    return None


@dataclass(frozen=True)
class ProcessedImage:
    full: bytes  # sanitised WebP, longest side <= FULL_MAX_SIDE
    thumbs: dict[str, bytes]  # "s" | "m" | "l" -> square WebP
    width: int
    height: int
    source_type: str


def _decode(raw: bytes, max_pixels: int, max_dimension: int) -> Image.Image:
    sniffed = sniff_content_type(raw[:32])
    if sniffed is None:
        raise ImageRejected(
            "unsupported_media", "Only JPEG, PNG, WebP and HEIC photos are supported", 415
        )
    if sniffed == "image/heic" and not HEIF_AVAILABLE:  # pragma: no cover
        raise ImageRejected("unsupported_media", "HEIC is not supported on this server", 415)
    Image.MAX_IMAGE_PIXELS = max_pixels  # Pillow raises DecompressionBombError past 2x this
    try:
        img = Image.open(io.BytesIO(raw))
        w, h = img.size  # header only: reject before decoding pixels
        if w < 16 or h < 16:
            raise ImageRejected("image_invalid", "Image is too small")
        if w > max_dimension or h > max_dimension or w * h > max_pixels:
            raise ImageRejected("image_invalid", f"Image is too large ({w}x{h})")
        img.load()
    except ImageRejected:
        raise
    except (
        UnidentifiedImageError,
        OSError,
        SyntaxError,
        ValueError,
        Image.DecompressionBombError,
    ) as exc:
        raise ImageRejected("image_invalid", "Could not read the image") from exc
    return img


def _webp(img: Image.Image) -> bytes:
    out = io.BytesIO()
    img.save(out, format="WEBP", quality=WEBP_QUALITY, method=4, exif=b"", icc_profile=None)
    return out.getvalue()


def _square_thumb(img: Image.Image, side: int) -> Image.Image:
    canvas = Image.new("RGB", (side, side), THUMB_BACKGROUND)
    inner = round(side * (1 - 2 * THUMB_PADDING))
    fitted = ImageOps.contain(img, (inner, inner), method=Image.Resampling.LANCZOS)
    x, y = (side - fitted.width) // 2, (side - fitted.height) // 2
    if fitted.mode == "RGBA":
        canvas.paste(fitted, (x, y), fitted)
    else:
        canvas.paste(fitted.convert("RGB"), (x, y))
    return canvas


def normalise(
    raw: bytes, *, max_pixels: int, max_dimension: int
) -> tuple[Image.Image, str, tuple[int, int]]:
    """Decode + orient + strip. Returns (clean RGB/RGBA image, source type, oriented size)."""
    sniffed = sniff_content_type(raw[:32]) or ""
    img = _decode(raw, max_pixels, max_dimension)
    img = ImageOps.exif_transpose(img)  # apply the camera's rotation, then forget the tag
    oriented = img.size
    has_alpha = img.mode in ("RGBA", "LA", "PA") or "transparency" in img.info
    clean = Image.new("RGBA" if has_alpha else "RGB", img.size)
    clean.paste(img.convert(clean.mode))  # copies pixels only: EXIF/GPS/ICC/XMP do not survive
    if max(clean.size) > FULL_MAX_SIDE:
        clean = ImageOps.contain(
            clean, (FULL_MAX_SIDE, FULL_MAX_SIDE), method=Image.Resampling.LANCZOS
        )
    return clean, sniffed, oriented


def render(img: Image.Image, source_type: str, original_size: tuple[int, int]) -> ProcessedImage:
    return ProcessedImage(
        full=_webp(img),
        thumbs={k: _webp(_square_thumb(img, side)) for k, side in THUMB_SIZES.items()},
        width=original_size[0],
        height=original_size[1],
        source_type=source_type,
    )
