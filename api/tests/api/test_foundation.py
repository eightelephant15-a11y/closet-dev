from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.errors import ApiError
from app.main import create_app


async def test_health_and_request_id(client: AsyncClient) -> None:
    r = await client.get("/health", headers={"X-Request-ID": "abc"})
    assert r.status_code == 200
    assert r.headers["X-Request-ID"] == "abc"
    r2 = await client.get("/health")
    assert len(r2.headers["X-Request-ID"]) == 32


async def test_error_model_for_unknown_route(client: AsyncClient) -> None:
    r = await client.get("/v1/nope")
    assert r.status_code == 404
    err = r.json()["error"]
    assert set(err) == {"code", "message", "details"}


def _app_with_counter() -> tuple[FastAPI, list[int]]:
    app = create_app()
    calls: list[int] = []

    @app.post("/v1/_t")
    async def _t(payload: dict[str, int]) -> dict[str, int]:
        calls.append(1)
        return {"n": len(calls)}

    @app.get("/v1/_boom")
    async def _boom() -> None:
        raise ApiError(409, "conflict_test", "nope", {"x": 1})

    return app, calls


async def test_api_error_shape() -> None:
    app, _ = _app_with_counter()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as c:
        r = await c.get("/v1/_boom")
    assert r.status_code == 409
    assert r.json()["error"] == {"code": "conflict_test", "message": "nope", "details": {"x": 1}}


async def test_idempotency_replay_and_reuse() -> None:
    app, calls = _app_with_counter()
    h = {"Idempotency-Key": "k1", "Authorization": "Bearer a"}
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as c:
        r1 = await c.post("/v1/_t", json={"a": 1}, headers=h)
        r2 = await c.post("/v1/_t", json={"a": 1}, headers=h)
        r3 = await c.post("/v1/_t", json={"a": 2}, headers=h)
        r4 = await c.post("/v1/_t", json={"a": 1}, headers={**h, "Authorization": "Bearer other"})
    assert r1.json() == r2.json() == {"n": 1}
    assert r2.headers["Idempotent-Replayed"] == "true"
    assert len(calls) == 2  # r1 and r4 (different user scope)
    assert r3.status_code == 422 and r3.json()["error"]["code"] == "idempotency_key_reuse"
    assert r4.json() == {"n": 2}
