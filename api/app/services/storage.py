"""Object storage seam: images, thumbnails and export files.

Images travel phone <-> storage directly through short-lived signed URLs; the API never carries image
bytes. Everything is private: reads also go through signed URLs with a short expiry, generated only after
the API has checked ownership. Two implementations:

* ``LocalDiskStorage``: files on disk, HMAC-signed URLs served by ``app/api/storage_local.py``
  (dev, tests and ``make api-local``; refused outside dev environments by ``Settings``).
* ``S3Storage``: presigned POST (with a ``content-length-range`` condition) and presigned GET.
  **Unverified**: built against boto3's offline signing but never run against a real bucket.
"""

import asyncio
import base64
import hashlib
import hmac
import json
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol

from app.core.config import get_settings

ALLOWED_UPLOAD_TYPES = ("image/jpeg", "image/png", "image/webp", "image/heic", "image/heif")


@dataclass(frozen=True)
class ObjectInfo:
    size: int
    content_type: str | None = None


@dataclass(frozen=True)
class UploadTicket:
    """What the client needs to upload one object: method + URL + headers/form fields."""

    key: str
    url: str
    method: str  # "PUT" (local) or "POST" (S3 presigned POST)
    headers: dict[str, str] = field(default_factory=dict)
    fields: dict[str, str] = field(default_factory=dict)
    expires_at: int = 0  # unix seconds
    max_bytes: int = 0


class ObjectStorage(Protocol):
    async def put(self, key: str, data: bytes, content_type: str | None = None) -> None: ...
    async def get(self, key: str) -> bytes | None: ...
    async def get_head(self, key: str, nbytes: int) -> bytes | None: ...
    async def head(self, key: str) -> ObjectInfo | None: ...
    async def delete(self, key: str) -> None: ...
    async def delete_prefix(self, prefix: str) -> int: ...

    def create_upload_ticket(
        self, key: str, *, content_type: str, max_bytes: int, expires_in: int, base_url: str = ""
    ) -> UploadTicket: ...

    def create_read_url(self, key: str, *, expires_in: int, base_url: str = "") -> str: ...


# Phase 1 name, kept so export code reads naturally.
ExportStorage = ObjectStorage


def image_key(garment_id: object, image_id: object, variant: str) -> str:
    """``g/<garment>/<image>/<variant>``: not tied to the user id, so account merges only move rows."""
    return f"g/{garment_id}/{image_id}/{variant}"


def garment_prefix(garment_id: object) -> str:
    return f"g/{garment_id}/"


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def _unb64(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


class SignedUrlError(Exception):
    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


class LocalDiskStorage:
    def __init__(self, root: Path, secret: str | None = None) -> None:
        self.root = root
        self.secret = (secret or get_settings().storage_signing_secret).encode()
        root.mkdir(parents=True, exist_ok=True)

    # ---- files ----------------------------------------------------------------------------
    def _path(self, key: str) -> Path:
        p = (self.root / key).resolve()
        if self.root.resolve() not in p.parents:
            raise ValueError("invalid key")
        return p

    async def put(self, key: str, data: bytes, content_type: str | None = None) -> None:
        p = self._path(key)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)

    async def get(self, key: str) -> bytes | None:
        p = self._path(key)
        return p.read_bytes() if p.is_file() else None

    async def get_head(self, key: str, nbytes: int) -> bytes | None:
        p = self._path(key)
        if not p.is_file():
            return None
        with p.open("rb") as f:
            return f.read(nbytes)

    async def head(self, key: str) -> ObjectInfo | None:
        p = self._path(key)
        return ObjectInfo(size=p.stat().st_size) if p.is_file() else None

    async def delete(self, key: str) -> None:
        self._path(key).unlink(missing_ok=True)

    async def delete_prefix(self, prefix: str) -> int:
        base = self._path(prefix.rstrip("/"))
        if not base.exists():
            return 0
        files = [p for p in base.rglob("*") if p.is_file()] if base.is_dir() else [base]
        for p in files:
            p.unlink(missing_ok=True)
        # prune now-empty directories
        for d in sorted((p for p in base.rglob("*") if p.is_dir()), reverse=True):
            d.rmdir()
        if base.is_dir():
            base.rmdir()
        return len(files)

    # ---- signed URLs ----------------------------------------------------------------------
    def _sign(self, payload: dict[str, Any]) -> str:
        body = _b64(json.dumps(payload, separators=(",", ":"), sort_keys=True).encode())
        sig = hmac.new(self.secret, body.encode(), hashlib.sha256).hexdigest()
        return f"{body}.{sig}"

    def verify(self, token: str, *, method: str, now: float | None = None) -> dict[str, Any]:
        """Returns the signed claims or raises ``SignedUrlError`` (tampered, expired, wrong method)."""
        try:
            body, sig = token.rsplit(".", 1)
        except ValueError as exc:
            raise SignedUrlError("malformed") from exc
        expected = hmac.new(self.secret, body.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, sig):
            raise SignedUrlError("bad_signature")
        try:
            claims: dict[str, Any] = json.loads(_unb64(body))
        except ValueError as exc:
            raise SignedUrlError("malformed") from exc
        if claims.get("m") != method:
            raise SignedUrlError("wrong_method")
        if claims.get("e", 0) < (now if now is not None else time.time()):
            raise SignedUrlError("expired")
        return claims

    def create_upload_ticket(
        self, key: str, *, content_type: str, max_bytes: int, expires_in: int, base_url: str = ""
    ) -> UploadTicket:
        self._path(key)  # validates the key
        expires = int(time.time()) + expires_in
        token = self._sign(
            {"k": key, "m": "PUT", "e": expires, "ct": content_type, "mb": max_bytes}
        )
        return UploadTicket(
            key=key,
            url=f"{base_url.rstrip('/')}/storage/upload/{token}",
            method="PUT",
            headers={"Content-Type": content_type},
            expires_at=expires,
            max_bytes=max_bytes,
        )

    def create_read_url(self, key: str, *, expires_in: int, base_url: str = "") -> str:
        self._path(key)
        token = self._sign({"k": key, "m": "GET", "e": int(time.time()) + expires_in})
        return f"{base_url.rstrip('/')}/storage/read/{token}"


class S3Storage:
    """UNVERIFIED against a real bucket. URL signing is offline and covered by tests."""

    def __init__(self, bucket: str, region: str | None = None, client: Any = None) -> None:
        import boto3
        from botocore.config import Config

        self.bucket = bucket
        self.client: Any = client or boto3.client(
            "s3",
            region_name=region or get_settings().aws_region,
            config=Config(signature_version="s3v4"),
        )

    async def put(self, key: str, data: bytes, content_type: str | None = None) -> None:
        extra = {"ContentType": content_type} if content_type else {}
        await asyncio.to_thread(
            self.client.put_object,
            Bucket=self.bucket,
            Key=key,
            Body=data,
            ServerSideEncryption="AES256",
            **extra,
        )

    async def get(self, key: str) -> bytes | None:
        try:
            obj = await asyncio.to_thread(self.client.get_object, Bucket=self.bucket, Key=key)
        except self.client.exceptions.NoSuchKey:
            return None
        return bytes(obj["Body"].read())

    async def get_head(self, key: str, nbytes: int) -> bytes | None:
        try:
            obj = await asyncio.to_thread(
                self.client.get_object, Bucket=self.bucket, Key=key, Range=f"bytes=0-{nbytes - 1}"
            )
        except self.client.exceptions.NoSuchKey:
            return None
        return bytes(obj["Body"].read())

    async def head(self, key: str) -> ObjectInfo | None:
        try:
            r = await asyncio.to_thread(self.client.head_object, Bucket=self.bucket, Key=key)
        except Exception as exc:  # botocore ClientError 404
            if getattr(exc, "response", {}).get("Error", {}).get("Code") in (
                "404",
                "NoSuchKey",
                "NotFound",
            ):
                return None
            raise
        return ObjectInfo(size=int(r["ContentLength"]), content_type=r.get("ContentType"))

    async def delete(self, key: str) -> None:
        await asyncio.to_thread(self.client.delete_object, Bucket=self.bucket, Key=key)

    async def delete_prefix(self, prefix: str) -> int:
        def run() -> int:
            deleted = 0
            paginator = self.client.get_paginator("list_objects_v2")
            for page in paginator.paginate(Bucket=self.bucket, Prefix=prefix):
                keys = [{"Key": o["Key"]} for o in page.get("Contents", [])]
                if keys:
                    self.client.delete_objects(Bucket=self.bucket, Delete={"Objects": keys})
                    deleted += len(keys)
            return deleted

        return await asyncio.to_thread(run)

    def create_upload_ticket(
        self, key: str, *, content_type: str, max_bytes: int, expires_in: int, base_url: str = ""
    ) -> UploadTicket:
        post = self.client.generate_presigned_post(
            Bucket=self.bucket,
            Key=key,
            Fields={"Content-Type": content_type},
            Conditions=[
                {"Content-Type": content_type},
                ["content-length-range", 1, max_bytes],
            ],
            ExpiresIn=expires_in,
        )
        return UploadTicket(
            key=key,
            url=post["url"],
            method="POST",
            fields=post["fields"],
            expires_at=int(time.time()) + expires_in,
            max_bytes=max_bytes,
        )

    def create_read_url(self, key: str, *, expires_in: int, base_url: str = "") -> str:
        return str(
            self.client.generate_presigned_url(
                "get_object", Params={"Bucket": self.bucket, "Key": key}, ExpiresIn=expires_in
            )
        )


# Phase 1 name for the disk implementation.
LocalStorage = LocalDiskStorage

_storage: ObjectStorage | None = None


def set_storage(s: ObjectStorage | None) -> None:
    global _storage
    _storage = s


def get_storage() -> ObjectStorage:
    global _storage
    if _storage is None:
        settings = get_settings()
        _storage = (
            S3Storage(settings.images_bucket)
            if settings.storage_backend == "s3"
            else LocalDiskStorage(Path(settings.storage_dir))
        )
    return _storage


def dumps(data: dict[str, Any]) -> bytes:
    return json.dumps(data, indent=2, sort_keys=True, default=str).encode()
