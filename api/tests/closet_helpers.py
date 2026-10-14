"""Shared helpers for closet API tests."""

from typing import Any

from tests.conftest import Env, auth
from tests.imagegen import garment_image

DEVICE = {"device_id": "dev1", "platform": "ios", "app_version": "1.0.0"}


async def signin(env: Env, uid: str = "u1", email: str | None = "u1@example.com") -> dict[str, str]:
    h = auth(uid, email)
    r = await env.client.post("/v1/auth/session", json=DEVICE, headers=h)
    assert r.status_code == 200, r.text
    return h


async def create(
    env: Env, h: dict[str, str], client_id: str = "client-0001", filename: str | None = "navy_jeans.jpg",
    content_type: str = "image/jpeg", **extra: Any,
) -> dict[str, Any]:  # fmt: skip
    r = await env.client.post(
        "/v1/garments",
        headers=h,
        json={"client_id": client_id, "filename": filename, "content_type": content_type, **extra},
    )
    assert r.status_code in (200, 201), r.text
    return r.json()


async def upload(env: Env, ticket: dict[str, Any], data: bytes) -> int:
    """Performs the direct-to-storage upload exactly as the phone does."""
    assert ticket["method"] == "PUT"
    r = await env.client.put(ticket["url"], content=data, headers=ticket["headers"])
    return r.status_code


async def complete(
    env: Env, h: dict[str, str], garment: dict[str, Any], image_id: str | None = None
):  # type: ignore[no-untyped-def]
    iid = image_id or garment["images"][0]["id"]
    return await env.client.post(f"/v1/garments/{garment['id']}/images/{iid}/complete", headers=h)


async def add_garment(
    env: Env, h: dict[str, str], client_id: str = "client-0001", filename: str = "navy_jeans.jpg",
    data: bytes | None = None,
) -> dict[str, Any]:  # fmt: skip
    """create -> upload -> complete -> (inline worker) -> final garment."""
    g = await create(env, h, client_id, filename)
    assert await upload(env, g["upload"], data or garment_image()) == 200
    r = await complete(env, h, g)
    assert r.status_code == 202, r.text
    return (await env.client.get(f"/v1/garments/{g['id']}", headers=h)).json()
