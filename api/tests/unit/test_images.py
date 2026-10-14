import io

import pytest
from PIL import Image

from app.services import images as im
from tests.imagegen import garment_image

LIMITS = {"max_pixels": 50_000_000, "max_dimension": 8000}


def run(raw: bytes) -> im.ProcessedImage:
    img, src, oriented = im.normalise(raw, **LIMITS)
    return im.render(img, src, oriented)


def metadata_keys(data: bytes) -> set[str]:
    img = Image.open(io.BytesIO(data))
    keys = set(img.info) & {"exif", "icc_profile", "xmp", "XML:com.adobe.xmp", "photoshop"}
    if img.getexif():
        keys.add("exif-tags")
    return keys


# ---- content sniffing (never trust the name or declared type) -------------------------------


@pytest.mark.parametrize(
    ("fmt", "expected"),
    [("JPEG", "image/jpeg"), ("PNG", "image/png"), ("WEBP", "image/webp"), ("HEIF", "image/heic")],
)
def test_sniff_recognises_real_formats(fmt: str, expected: str) -> None:
    assert im.sniff_content_type(garment_image(fmt=fmt)[:32]) == expected


@pytest.mark.parametrize(
    "payload",
    [
        b"",
        b"GIF89a....",
        b"<html><script>alert(1)</script></html>",
        b"%PDF-1.7",
        b"MZ\x90\x00",
        b"\x00" * 64,
    ],
)
def test_sniff_rejects_everything_else(payload: bytes) -> None:
    assert im.sniff_content_type(payload) is None


def test_non_images_are_rejected_regardless_of_name() -> None:
    with pytest.raises(im.ImageRejected) as exc:
        run(b"<svg onload=alert(1)>" + b"x" * 100)
    assert exc.value.code == "unsupported_media" and exc.value.status == 415


def test_corrupt_and_truncated_images_are_rejected() -> None:
    good = garment_image()
    with pytest.raises(im.ImageRejected) as exc:
        run(good[: len(good) // 2])
    assert exc.value.code == "image_invalid"
    with pytest.raises(im.ImageRejected):
        run(good[:3] + b"\x00" * 200)  # right magic bytes, garbage body


def test_oversize_dimensions_and_tiny_images_are_rejected() -> None:
    huge = garment_image((9000, 100), fmt="PNG")
    with pytest.raises(im.ImageRejected, match="too large"):
        run(huge)
    with pytest.raises(im.ImageRejected, match="too small"):
        run(garment_image((8, 8), fmt="PNG"))


def test_decompression_bomb_guard_uses_the_configured_pixel_limit() -> None:
    raw = garment_image((1200, 1200), fmt="PNG")
    with pytest.raises(im.ImageRejected):
        im.normalise(raw, max_pixels=1_000_000, max_dimension=8000)


# ---- orientation, metadata stripping, format conversion ----------------------------------------


def test_exif_orientation_is_applied_and_size_reflects_it() -> None:
    # 320x480 portrait stored with orientation 6 (rotate 90 CW) must come out landscape 480x320
    out = run(garment_image((320, 480), exif_orientation=6))
    assert (out.width, out.height) == (480, 320)
    full = Image.open(io.BytesIO(out.full))
    assert full.size == (480, 320)


@pytest.mark.parametrize("fmt", ["JPEG", "PNG", "WEBP", "HEIF"])
def test_gps_and_all_metadata_are_stripped_from_every_output(fmt: str) -> None:
    raw = garment_image(fmt=fmt, gps=True, exif_orientation=3)
    if fmt == "JPEG":
        assert b"SecretPhoneMaker" in raw, "fixture should actually contain EXIF"
    out = run(raw)
    for blob in (out.full, *out.thumbs.values()):
        assert metadata_keys(blob) == set()
        assert b"SecretPhoneMaker" not in blob and b"SecretModel" not in blob
        assert b"Exif" not in blob[:200] and b"GPS" not in blob


def test_everything_is_webp() -> None:
    out = run(garment_image(fmt="JPEG"))
    for blob in (out.full, *out.thumbs.values()):
        assert Image.open(io.BytesIO(blob)).format == "WEBP"


def test_heic_is_converted_to_webp() -> None:
    out = run(garment_image(fmt="HEIF"))
    assert out.source_type == "image/heic"
    assert Image.open(io.BytesIO(out.full)).format == "WEBP"


def test_png_with_transparency_keeps_alpha_in_full_and_composites_thumbs_on_neutral() -> None:
    out = run(garment_image(fmt="PNG", alpha=True))
    assert Image.open(io.BytesIO(out.full)).mode == "RGBA"
    thumb = Image.open(io.BytesIO(out.thumbs["m"])).convert("RGB")
    assert thumb.getpixel((2, 2)) == pytest.approx(
        im.THUMB_BACKGROUND, abs=6
    )  # transparent -> neutral


# ---- thumbnails ---------------------------------------------------------------------------------


def test_three_square_thumbnails_with_padding() -> None:
    out = run(garment_image((300, 900)))  # a very tall item
    assert set(out.thumbs) == {"s", "m", "l"}
    for key, side in im.THUMB_SIZES.items():
        t = Image.open(io.BytesIO(out.thumbs[key]))
        assert t.size == (side, side)
        rgb = t.convert("RGB")
        # padded: the corners and the edge midpoints are neutral background, not garment
        for xy in [(0, 0), (side - 1, side - 1), (side // 2, 0), (0, side // 2)]:
            assert rgb.getpixel(xy) == pytest.approx(im.THUMB_BACKGROUND, abs=8), (key, xy)


def test_small_images_are_not_upscaled_beyond_the_canvas_logic() -> None:
    out = run(garment_image((64, 64)))
    assert Image.open(io.BytesIO(out.full)).size == (64, 64)


def test_full_image_is_capped_to_2048() -> None:
    out = run(garment_image((4000, 3000), fmt="JPEG"))
    assert max(Image.open(io.BytesIO(out.full)).size) == im.FULL_MAX_SIDE
    assert (out.width, out.height) == (4000, 3000)  # original dimensions are still reported
