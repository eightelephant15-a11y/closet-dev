"""Object storage seam for export files (local disk in dev/tests, S3 in AWS)."""

import asyncio
import json
from pathlib import Path
from typing import Any, Protocol

from app.core.config import get_settings


class ExportStorage(Protocol):
    async def put(self, key: str, data: bytes) -> None: ...
    async def get(self, key: str) -> bytes | None: ...
    async def delete(self, key: str) -> None: ...


class LocalStorage:
    def __init__(self, root: Path) -> None:
        self.root = root
        root.mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        p = (self.root / key).resolve()
        if self.root.resolve() not in p.parents:
            raise ValueError("invalid key")
        return p

    async def put(self, key: str, data: bytes) -> None:
        p = self._path(key)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)

    async def get(self, key: str) -> bytes | None:
        p = self._path(key)
        return p.read_bytes() if p.exists() else None

    async def delete(self, key: str) -> None:
        self._path(key).unlink(missing_ok=True)


class S3Storage:
    def __init__(self, bucket: str) -> None:
        import boto3

        self.bucket = bucket
        self.client: Any = boto3.client("s3")

    async def put(self, key: str, data: bytes) -> None:
        await asyncio.to_thread(
            self.client.put_object,
            Bucket=self.bucket,
            Key=key,
            Body=data,
            ServerSideEncryption="AES256",
        )

    async def get(self, key: str) -> bytes | None:
        try:
            obj = await asyncio.to_thread(self.client.get_object, Bucket=self.bucket, Key=key)
        except self.client.exceptions.NoSuchKey:
            return None
        return bytes(obj["Body"].read())

    async def delete(self, key: str) -> None:
        await asyncio.to_thread(self.client.delete_object, Bucket=self.bucket, Key=key)


_storage: ExportStorage | None = None


def set_storage(s: ExportStorage) -> None:
    global _storage
    _storage = s


def get_storage() -> ExportStorage:
    global _storage
    if _storage is None:
        bucket = get_settings().export_bucket
        _storage = S3Storage(bucket) if bucket else LocalStorage(Path(get_settings().export_dir))
    return _storage


def dumps(data: dict[str, Any]) -> bytes:
    return json.dumps(data, indent=2, sort_keys=True, default=str).encode()
