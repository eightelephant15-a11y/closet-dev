import time
from pathlib import Path

import pytest

from app.services.storage import (
    LocalDiskStorage,
    S3Storage,
    SignedUrlError,
    garment_prefix,
    image_key,
)
from tests.conftest import Env


@pytest.fixture
def disk(tmp_path: Path) -> LocalDiskStorage:
    return LocalDiskStorage(tmp_path / "store", secret="s" * 32)


def token_of(url: str) -> str:
    return url.split("/storage/", 1)[1].split("/", 1)[1]


async def test_files_round_trip_head_and_delete(disk: LocalDiskStorage) -> None:
    key = image_key("g1", "i1", "full.webp")
    assert await disk.head(key) is None
    await disk.put(key, b"hello world")
    info = await disk.head(key)
    assert info and info.size == 11
    assert await disk.get(key) == b"hello world"
    assert await disk.get_head(key, 5) == b"hello"
    await disk.delete(key)
    assert await disk.get(key) is None


async def test_delete_prefix_removes_only_that_garment(disk: LocalDiskStorage) -> None:
    await disk.put(image_key("g1", "i1", "a"), b"1")
    await disk.put(image_key("g1", "i2", "b"), b"2")
    await disk.put(image_key("g2", "i3", "c"), b"3")
    assert await disk.delete_prefix(garment_prefix("g1")) == 2
    assert await disk.get(image_key("g1", "i1", "a")) is None
    assert await disk.get(image_key("g2", "i3", "c")) == b"3"
    assert await disk.delete_prefix(garment_prefix("nope")) == 0


@pytest.mark.parametrize("key", ["../etc/passwd", "g/../../x", "/abs/path"])
async def test_keys_cannot_escape_the_root(disk: LocalDiskStorage, key: str) -> None:
    with pytest.raises(ValueError):
        await disk.put(key, b"x")
    with pytest.raises(ValueError):
        disk.create_read_url(key, expires_in=60)


def test_signed_urls_verify_and_expire(disk: LocalDiskStorage) -> None:
    url = disk.create_read_url("g/a/b/c", expires_in=60, base_url="http://h")
    assert url.startswith("http://h/storage/read/")
    claims = disk.verify(token_of(url), method="GET")
    assert claims["k"] == "g/a/b/c"
    with pytest.raises(SignedUrlError, match="expired"):
        disk.verify(token_of(url), method="GET", now=time.time() + 61)


def test_signed_urls_reject_tampering_wrong_method_and_other_secrets(
    disk: LocalDiskStorage, tmp_path: Path
) -> None:
    token = token_of(disk.create_read_url("g/a/b/c", expires_in=60))
    body, sig = token.rsplit(".", 1)
    with pytest.raises(SignedUrlError, match="bad_signature"):
        disk.verify(body + "." + ("0" * len(sig)), method="GET")
    other_body = token_of(disk.create_read_url("g/other/key", expires_in=60)).split(".")[0]
    with pytest.raises(SignedUrlError, match="bad_signature"):  # swap payload, keep signature
        disk.verify(other_body + "." + sig, method="GET")
    with pytest.raises(SignedUrlError, match="wrong_method"):  # a read URL cannot upload
        disk.verify(token, method="PUT")
    with pytest.raises(SignedUrlError, match="malformed"):
        disk.verify("garbage", method="GET")
    elsewhere = LocalDiskStorage(tmp_path / "other", secret="t" * 32)
    with pytest.raises(SignedUrlError, match="bad_signature"):
        elsewhere.verify(token, method="GET")


# ---- the HTTP endpoints (what the phone talks to) ---------------------------------------------


async def test_upload_then_read_over_http(env: Env) -> None:
    storage = env.storage
    ticket = storage.create_upload_ticket(
        "g/x/y/raw", content_type="image/png", max_bytes=1000, expires_in=60, base_url="http://test"
    )
    assert ticket.method == "PUT" and ticket.headers == {"Content-Type": "image/png"}
    path = ticket.url.removeprefix("http://test")
    r = await env.client.put(path, content=b"\x89PNG-bytes", headers=ticket.headers)
    assert r.status_code == 200
    read = storage.create_read_url("g/x/y/raw", expires_in=60, base_url="http://test")
    got = await env.client.get(read.removeprefix("http://test"))
    assert got.status_code == 200 and got.content == b"\x89PNG-bytes"
    assert got.headers["cache-control"].startswith("private")


async def test_upload_enforces_size_content_type_and_signature(env: Env) -> None:
    t = env.storage.create_upload_ticket(
        "g/x/y/raw", content_type="image/png", max_bytes=10, expires_in=60, base_url=""
    )
    too_big = await env.client.put(t.url, content=b"x" * 11, headers=t.headers)
    assert too_big.status_code == 413 and too_big.json()["error"]["code"] == "file_too_large"
    wrong_type = await env.client.put(t.url, content=b"x", headers={"Content-Type": "text/html"})
    assert wrong_type.status_code == 415
    empty = await env.client.put(t.url, content=b"", headers=t.headers)
    assert empty.status_code == 422
    forged = await env.client.put(t.url[:-3] + "abc", content=b"x", headers=t.headers)
    assert forged.status_code == 403 and forged.json()["error"]["code"] == "invalid_signature"
    assert await env.storage.get("g/x/y/raw") is None


async def test_expired_upload_and_read_urls_are_rejected(env: Env) -> None:
    t = env.storage.create_upload_ticket(
        "g/x/y/raw", content_type="image/png", max_bytes=100, expires_in=-1, base_url=""
    )
    r = await env.client.put(t.url, content=b"x", headers=t.headers)
    assert r.status_code == 403 and "expired" in r.json()["error"]["message"]
    await env.storage.put("g/x/y/raw", b"data")
    url = env.storage.create_read_url("g/x/y/raw", expires_in=-1)
    assert (await env.client.get(url)).status_code == 403


async def test_a_read_url_cannot_be_used_to_upload_or_the_reverse(env: Env) -> None:
    read = env.storage.create_read_url("g/x/y/raw", expires_in=60)
    r = await env.client.put(
        read.replace("/read/", "/upload/"), content=b"x", headers={"Content-Type": "image/png"}
    )
    assert r.status_code == 403
    up = env.storage.create_upload_ticket(
        "g/x/y/raw", content_type="image/png", max_bytes=9, expires_in=60
    )
    assert (await env.client.get(up.url.replace("/upload/", "/read/"))).status_code == 403


# ---- S3 (unverified against AWS; signing is offline) -----------------------------------------


def test_s3_presigned_post_pins_size_and_content_type() -> None:
    import boto3
    from botocore.config import Config

    client = boto3.client(
        "s3",
        region_name="us-east-1",
        aws_access_key_id="AKIAEXAMPLE",
        aws_secret_access_key="secret",
        config=Config(signature_version="s3v4"),
    )
    s3 = S3Storage("bucket-x", client=client)
    t = s3.create_upload_ticket(
        "g/a/b/raw", content_type="image/jpeg", max_bytes=5000, expires_in=300
    )
    assert t.method == "POST" and "bucket-x" in t.url
    assert t.fields["key"] == "g/a/b/raw" and t.fields["Content-Type"] == "image/jpeg"
    import base64
    import json

    policy = json.loads(base64.b64decode(t.fields["policy"]))
    assert ["content-length-range", 1, 5000] in policy["conditions"]
    read = s3.create_read_url("g/a/b/full.webp", expires_in=120)
    assert "X-Amz-Expires=120" in read and "X-Amz-Signature=" in read
