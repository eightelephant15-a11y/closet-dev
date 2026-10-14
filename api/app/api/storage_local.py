"""Signed-URL endpoints for ``LocalDiskStorage`` (dev, tests, ``make api-local``). Not in OpenAPI.

``PUT /storage/upload/<token>``  upload one object (the token pins key, content type and max size)
``GET /storage/read/<token>``    read one object (short-lived)
"""

import mimetypes
from typing import Annotated

from fastapi import APIRouter, Depends, Request, Response

from app.core.errors import ApiError
from app.services.storage import LocalDiskStorage, SignedUrlError, get_storage

router = APIRouter(prefix="/storage", include_in_schema=False)


def _local() -> LocalDiskStorage:
    s = get_storage()
    if not isinstance(s, LocalDiskStorage):
        raise ApiError(404, "not_found", "Not found")
    return s


@router.put("/upload/{token:path}", status_code=200)
async def upload(
    token: str, request: Request, storage: Annotated[LocalDiskStorage, Depends(_local)]
) -> Response:
    try:
        claims = storage.verify(token, method="PUT")
    except SignedUrlError as exc:
        raise ApiError(403, "invalid_signature", f"Upload URL rejected ({exc.reason})") from exc
    if request.headers.get("content-type") != claims["ct"]:
        raise ApiError(415, "unsupported_media", "Content-Type does not match the upload URL")
    declared = request.headers.get("content-length")
    if declared and int(declared) > claims["mb"]:
        raise ApiError(413, "file_too_large", "File exceeds the allowed size")
    body = bytearray()
    async for chunk in request.stream():
        body.extend(chunk)
        if len(body) > claims["mb"]:
            raise ApiError(413, "file_too_large", "File exceeds the allowed size")
    if not body:
        raise ApiError(422, "image_invalid", "Empty upload")
    await storage.put(claims["k"], bytes(body), claims["ct"])
    return Response(status_code=200)


@router.get("/read/{token:path}")
async def read(token: str, storage: Annotated[LocalDiskStorage, Depends(_local)]) -> Response:
    try:
        claims = storage.verify(token, method="GET")
    except SignedUrlError as exc:
        raise ApiError(403, "invalid_signature", f"URL rejected ({exc.reason})") from exc
    data = await storage.get(claims["k"])
    if data is None:
        raise ApiError(404, "not_found", "Object not found")
    media = mimetypes.guess_type(claims["k"])[0] or "application/octet-stream"
    return Response(data, media_type=media, headers={"Cache-Control": "private, max-age=300"})
