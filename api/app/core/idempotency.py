"""Idempotency-Key support for mutating requests.

Same key + same request  -> replay stored response (header Idempotent-Replayed: true).
Same key + other request -> 422 idempotency_key_reuse.
Same key while in flight -> 409 idempotency_in_progress.
Scoped per Authorization header so users never share keys.
"""

import hashlib
import json

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.core.config import get_settings
from app.core.errors import ErrorBody, ErrorResponse
from app.core.redis import get_redis

MUTATING = {"POST", "PUT", "PATCH", "DELETE"}


def _err(status: int, code: str, message: str) -> JSONResponse:
    body = ErrorResponse(error=ErrorBody(code=code, message=message))
    return JSONResponse(status_code=status, content=body.model_dump(mode="json"))


class IdempotencyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        key = request.headers.get("Idempotency-Key")
        if request.method not in MUTATING or not key:
            return await call_next(request)

        body = await request.body()
        scope = hashlib.sha256(request.headers.get("Authorization", "").encode()).hexdigest()[:16]
        fingerprint = hashlib.sha256(
            request.method.encode() + request.url.path.encode() + body
        ).hexdigest()
        rkey = f"idem:{scope}:{key}"
        redis = get_redis()
        ttl = get_settings().idempotency_ttl_seconds

        claimed = await redis.set(
            rkey, json.dumps({"state": "pending", "fp": fingerprint}), nx=True, ex=ttl
        )
        if not claimed:
            raw = await redis.get(rkey)
            stored = json.loads(raw) if raw else {"state": "pending", "fp": fingerprint}
            if stored["fp"] != fingerprint:
                return _err(
                    422,
                    "idempotency_key_reuse",
                    "Idempotency-Key was used with a different request",
                )
            if stored["state"] == "pending":
                return _err(
                    409, "idempotency_in_progress", "A request with this key is in progress"
                )
            return Response(
                content=stored["body"].encode(),
                status_code=int(stored["status"]),
                media_type=stored["media_type"],
                headers={"Idempotent-Replayed": "true"},
            )

        response = await call_next(request)
        chunks = [chunk async for chunk in response.body_iterator]  # type: ignore[attr-defined]
        payload = b"".join(c if isinstance(c, bytes) else c.encode() for c in chunks)
        if response.status_code >= 500:
            await redis.delete(rkey)  # allow retry after server errors
        else:
            await redis.set(
                rkey,
                json.dumps(
                    {
                        "state": "done",
                        "fp": fingerprint,
                        "status": response.status_code,
                        "body": payload.decode(),
                        "media_type": response.media_type or "application/json",
                    }
                ),
                ex=ttl,
            )
        headers = {k: v for k, v in response.headers.items() if k.lower() != "content-length"}
        return Response(
            payload,
            status_code=response.status_code,
            headers=headers,
            media_type=response.media_type,
        )
