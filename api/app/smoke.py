"""Smoke test: exercises every /v1 operation against a running server and prints PASS/FAIL.

    python -m app.smoke [base_url]          # default http://127.0.0.1:8000, needs AUTH_MODE=dev

The list of operations is read from the server's own OpenAPI document, and any operation the script
did not call is reported as UNCOVERED (and fails), so new endpoints cannot skip the smoke test.
"""

import asyncio
import io
import sys
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

import httpx
from PIL import Image, ImageDraw

DEVICE = {"device_id": "smoke-device", "platform": "ios", "app_version": "smoke"}


def test_png(color: tuple[int, int, int] = (30, 60, 140)) -> bytes:
    img = Image.new("RGB", (400, 600), (250, 250, 250))
    ImageDraw.Draw(img).rectangle([80, 90, 320, 510], fill=color)
    out = io.BytesIO()
    img.save(out, format="PNG")
    return out.getvalue()


async def upload_via_ticket(
    client: httpx.AsyncClient, ticket: dict[str, object], data: bytes
) -> httpx.Response:
    """Uploads the way the phone does: straight to the signed URL, never through /v1."""
    url = str(ticket["url"])
    if ticket["method"] == "PUT":
        return await client.put(url, content=data, headers=ticket["headers"])  # type: ignore[arg-type]
    return await client.post(url, data=ticket["fields"], files={"file": ("photo", data)})  # type: ignore[arg-type]


@dataclass
class Result:
    name: str
    ok: bool
    detail: str = ""


class Smoke:
    def __init__(self, client: httpx.AsyncClient) -> None:
        self.c = client
        self.results: list[Result] = []
        self.called: set[str] = set()

    async def req(
        self, method: str, path: str, template: str | None = None, **kw: object
    ) -> httpx.Response:
        self.called.add(f"{method.upper()} {template or path}")
        return await self.c.request(method, path, **kw)  # type: ignore[arg-type]

    async def check(self, name: str, fn: Callable[[], Awaitable[None]]) -> None:
        try:
            await fn()
        except AssertionError as exc:
            self.results.append(Result(name, False, str(exc) or "assertion failed"))
        except Exception as exc:
            self.results.append(Result(name, False, f"{type(exc).__name__}: {exc}"))
        else:
            self.results.append(Result(name, True))

    async def token(self, uid: str, email: str | None, name: str | None = None) -> dict[str, str]:
        r = await self.c.post("/dev/token", json={"uid": uid, "email": email, "name": name})
        assert r.status_code == 200, f"/dev/token {r.status_code} (is AUTH_MODE=dev on?)"
        return {"Authorization": f"Bearer {r.json()['token']}", "X-Device-Id": "smoke-device"}


def expect(r: httpx.Response, *codes: int) -> httpx.Response:
    assert r.status_code in codes, (
        f"{r.request.method} {r.request.url.path} -> {r.status_code} {r.text[:200]}"
    )
    return r


async def run(client: httpx.AsyncClient) -> list[Result]:
    s = Smoke(client)
    run_id = uuid.uuid4().hex[:8]
    guest_uid, member_uid, other_uid = (
        f"smoke-guest-{run_id}",
        f"smoke-ada-{run_id}",
        f"smoke-other-{run_id}",
    )
    state: dict[str, object] = {}

    async def health() -> None:
        expect(await client.get("/health"), 200)

    async def config() -> None:
        body = expect(await s.req("GET", "/v1/config"), 200).json()
        assert body["flags"]["onboarding_variant"] in ("quiz_first", "closet_first")
        assert body["min_age"] == 16
        tax = expect(await s.req("GET", "/v1/taxonomy"), 200).json()
        assert tax["version"] == body["taxonomy_version"]

    async def unauthenticated() -> None:
        r = await s.req("GET", "/v1/me")
        assert r.status_code == 401 and r.json()["error"]["code"] == "missing_token"

    async def guest_session() -> None:
        h = await s.token(guest_uid, None)
        state["guest"] = h
        body = expect(await s.req("POST", "/v1/auth/session", json=DEVICE, headers=h), 200).json()
        assert body["user"]["is_anonymous"] and body["is_new_user"]
        state["guest_id"] = body["user"]["id"]

    async def me_and_patch() -> None:
        h = state["guest"]
        me = expect(await s.req("GET", "/v1/me", headers=h), 200).json()
        assert me["id"] == state["guest_id"]
        patched = expect(
            await s.req(
                "PATCH",
                "/v1/me",
                headers=h,
                json={"city": "Austin, TX", "units": "imperial", "daily_outfit_time": "08:00"},
            ),
            200,
        ).json()
        assert patched["city"] == "Austin, TX"

    async def sample_and_places() -> None:
        h = state["guest"]
        items = expect(await s.req("GET", "/v1/sample/closet", headers=h), 200).json()
        assert len(items) >= 10
        cities = expect(
            await s.req("GET", "/v1/places/autocomplete", headers=h, params={"q": "aus"}), 200
        ).json()
        assert "Austin, TX" in cities

    async def age_onboarding_prefs() -> None:
        h = state["guest"]
        expect(
            await s.req(
                "POST", "/v1/me/age-confirmation", headers=h, json={"confirmed_16_plus": True}
            ),
            204,
        )
        ob = expect(await s.req("GET", "/v1/onboarding", headers=h), 200).json()
        assert ob["current_step"] == "welcome"
        ob = expect(
            await s.req(
                "PUT",
                "/v1/onboarding",
                headers=h,
                json={"current_step": "quiz", "completed_steps": ["welcome", "age"]},
            ),
            200,
        ).json()
        assert ob["current_step"] == "quiz"
        prefs = expect(
            await s.req(
                "PUT",
                "/v1/me/preferences",
                headers=h,
                json={
                    "answers": {
                        "department": "womenswear",
                        "fit": "slim",
                        "colors": ["navy"],
                        "dress_code": 2,
                    }
                },
            ),
            200,
        ).json()
        assert prefs["weights"]["fit"]["slim"] == 1.0
        got = expect(await s.req("GET", "/v1/me/preferences", headers=h), 200).json()
        assert got["answers"]["department"] == "womenswear"
        bad = await s.req(
            "PUT", "/v1/me/preferences", headers=h, json={"answers": {"fit": "baggy"}}
        )
        assert bad.status_code == 422

    async def consents() -> None:
        h = state["guest"]
        c = expect(await s.req("GET", "/v1/me/consents", headers=h), 200).json()
        assert c["no_ai_training"] is True and c["analytics_opt_in"] is None
        c = expect(
            await s.req("PUT", "/v1/me/consents", headers=h, json={"analytics_opt_in": True}), 200
        ).json()
        assert c["analytics_opt_in"] is True

    async def idempotency() -> None:
        h = {**state["guest"], "Idempotency-Key": f"smoke-{run_id}"}  # type: ignore[dict-item]
        a = expect(
            await s.req("PUT", "/v1/onboarding", headers=h, json={"current_step": "basics"}), 200
        )
        b = expect(
            await s.req("PUT", "/v1/onboarding", headers=h, json={"current_step": "basics"}), 200
        )
        assert b.headers.get("Idempotent-Replayed") == "true" and a.json() == b.json()

    async def guest_upgrade_keeps_data() -> None:
        h = await s.token(guest_uid, "ada@example.com", "Ada")  # same uid + email == link Google
        up = expect(await s.req("POST", "/v1/auth/upgrade", headers=h, json={}), 200).json()
        assert up["id"] == state["guest_id"] and not up["is_anonymous"], (
            "upgrade must keep the same user"
        )
        assert up["city"] == "Austin, TX"
        prefs = expect(await s.req("GET", "/v1/me/preferences", headers=h), 200).json()
        assert prefs["answers"]["fit"] == "slim", "preferences lost in upgrade"
        state["member"] = h

    async def sessions_and_privacy() -> None:
        h = state["member"]
        page = expect(await s.req("GET", "/v1/auth/sessions", headers=h), 200).json()
        assert page["items"] and "next_cursor" in page
        other = await s.token(other_uid, "other@example.com", "Other")
        expect(await s.req("POST", "/v1/auth/session", json=DEVICE, headers=other), 200)
        assert (
            expect(await s.req("GET", "/v1/me/preferences", headers=other), 200).json()["answers"]
            == {}
        ), "leak!"
        sid = page["items"][0]["id"]
        r = await s.req(
            "DELETE", f"/v1/auth/sessions/{sid}", "/v1/auth/sessions/{session_id}", headers=other
        )
        assert r.status_code == 404, "another user's session must not be revocable"

    async def export_flow() -> None:
        h = state["member"]
        job = expect(await s.req("POST", "/v1/me/export", headers=h), 202).json()
        status = job
        for _ in range(40):
            status = expect(
                await s.req(
                    "GET", f"/v1/me/export/{job['id']}", "/v1/me/export/{job_id}", headers=h
                ),
                200,
            ).json()
            if status["status"] != "pending":
                break
            await asyncio.sleep(0.25)
        assert status["status"] == "completed", status
        dl = expect(
            await s.req(
                "GET", status["download_url"], "/v1/me/export/{job_id}/download", headers=h
            ),
            200,
        )
        assert dl.json()["profile"]["city"] == "Austin, TX"

    async def closet_add_garment() -> None:
        h = state["member"]
        ent = expect(await s.req("GET", "/v1/entitlements", headers=h), 200).json()
        assert ent["closet_item_limit"] >= 1 and ent["plan"] == "free"
        g = expect(
            await s.req(
                "POST", "/v1/garments", headers=h,
                json={"client_id": f"smoke-{run_id}-1", "filename": "navy_jeans_casual.png", "content_type": "image/png"},
            ),
            201,
        ).json()  # fmt: skip
        assert g["upload"]["url"] and g["analysis"]["status"] == "pending"
        again = expect(
            await s.req("POST", "/v1/garments", headers=h, json={"client_id": f"smoke-{run_id}-1"}),
            200,
        ).json()
        assert again["id"] == g["id"], "create must be idempotent on client_id"
        iid = g["images"][0]["id"]
        fresh = expect(
            await s.req(
                "POST",
                f"/v1/garments/{g['id']}/images/{iid}/upload-url",
                "/v1/garments/{garment_id}/images/{image_id}/upload-url",
                headers=h,
            ),
            200,
        ).json()
        up = await upload_via_ticket(client, fresh, test_png())
        assert up.status_code in (200, 204), f"upload -> {up.status_code} {up.text[:120]}"
        expect(
            await s.req(
                "POST",
                f"/v1/garments/{g['id']}/images/{iid}/complete",
                "/v1/garments/{garment_id}/images/{image_id}/complete",
                headers=h,
            ),
            202,
        )
        late = await s.req(
            "POST",
            f"/v1/garments/{g['id']}/images/{iid}/upload-url",
            "/v1/garments/{garment_id}/images/{image_id}/upload-url",
            headers=h,
        )
        assert late.status_code == 409, "no new upload URL once the photo is in"
        detail = g
        for _ in range(120):  # the worker is a separate process locally: poll
            detail = expect(
                await s.req(
                    "GET", f"/v1/garments/{g['id']}", "/v1/garments/{garment_id}", headers=h
                ),
                200,
            ).json()
            if detail["analysis"]["status"] in ("done", "needs_manual"):
                break
            await asyncio.sleep(0.25)
        assert detail["analysis"]["status"] == "done", detail["analysis"]
        assert (detail["category"], detail["subcategory"], detail["primary_color"]) == (
            "bottom",
            "jeans",
            "navy",
        )
        assert detail["images"][0]["status"] == "ready"
        thumb = await client.get(detail["images"][0]["urls"]["m"])
        assert thumb.status_code == 200 and thumb.headers["content-type"] == "image/webp"
        state["garment_id"] = detail["id"]
        bulk = expect(
            await s.req(
                "POST",
                "/v1/garments/bulk",
                headers=h,
                json={
                    "items": [
                        {"client_id": f"smoke-{run_id}-b1"},
                        {"client_id": f"smoke-{run_id}-b2"},
                    ]
                },
            ),
            201,
        ).json()
        assert len(bulk["items"]) == 2 and all(i["upload"] for i in bulk["items"])

    async def sign_out_and_session_revoked() -> None:
        h = await s.token(other_uid, "other@example.com", "Other")
        h2 = {**h, "X-Device-Id": "smoke-device"}
        expect(await s.req("POST", "/v1/auth/sign-out", headers=h2), 204)
        r = await s.req("GET", "/v1/me", headers=h2)
        assert r.status_code == 401 and r.json()["error"]["code"] == "session_revoked"

    async def delete_and_restore() -> None:
        h = state["member"]
        d = expect(await s.req("DELETE", "/v1/me", headers=h), 200).json()
        assert d["purge_after"]
        blocked = await s.req("GET", "/v1/me", headers=h)
        assert blocked.status_code in (401, 403)
        expect(await s.req("POST", "/v1/auth/session", json=DEVICE, headers=h), 200)  # sign back in
        expect(await s.req("POST", "/v1/me/restore", headers=h), 204)
        assert expect(await s.req("GET", "/v1/me", headers=h), 200).json()["status"] == "active"

    async def under_16_deletes_everything() -> None:
        h = await s.token(f"smoke-kid-{run_id}", "kid@example.com")
        expect(await s.req("POST", "/v1/auth/session", json=DEVICE, headers=h), 200)
        r = await s.req(
            "POST", "/v1/me/age-confirmation", headers=h, json={"confirmed_16_plus": False}
        )
        assert r.status_code == 403 and r.json()["error"]["code"] == "age_under_minimum"
        again = await s.req("GET", "/v1/me", headers=h)
        assert again.status_code == 401, "account must be gone"

    async def merge_guest_into_existing() -> None:
        existing = await s.token(member_uid, "merge@example.com", "Merge")
        expect(await s.req("POST", "/v1/auth/session", json=DEVICE, headers=existing), 200)
        guest = await s.token(f"smoke-guest2-{run_id}", None)
        expect(
            await s.req(
                "POST", "/v1/auth/session", json={**DEVICE, "device_id": "d2"}, headers=guest
            ),
            200,
        )
        expect(await s.req("PATCH", "/v1/me", headers=guest, json={"city": "Boston, MA"}), 200)
        guest_token = guest["Authorization"].removeprefix("Bearer ")
        merged = expect(
            await s.req(
                "POST", "/v1/auth/upgrade", headers=existing, json={"merge_from_token": guest_token}
            ),
            200,
        ).json()
        assert merged["city"] == "Boston, MA"
        assert (await s.req("GET", "/v1/me", headers=guest)).status_code in (401, 404), (
            "guest should be gone"
        )

    steps = [
        ("health", health), ("GET /v1/config", config), ("auth required", unauthenticated),
        ("guest session", guest_session), ("me + patch", me_and_patch),
        ("sample closet + places", sample_and_places),
        ("age, onboarding, preferences", age_onboarding_prefs), ("consents", consents),
        ("idempotency replay", idempotency), ("guest upgrade keeps data", guest_upgrade_keeps_data),
        ("sessions + cross-user privacy", sessions_and_privacy), ("export", export_flow),
        ("closet: add garment end to end", closet_add_garment), ("sign-out revokes session", sign_out_and_session_revoked),
        ("delete + restore", delete_and_restore), ("under-16 removes account", under_16_deletes_everything),
        ("merge guest into existing account", merge_guest_into_existing),
    ]  # fmt: skip
    for name, fn in steps:
        await s.check(name, fn)

    async def coverage() -> None:
        spec = (await client.get("/openapi.json")).json()
        declared = {
            f"{m.upper()} {p}"
            for p, ops in spec["paths"].items()
            if p.startswith("/v1")
            for m in ops
            if m in {"get", "post", "put", "patch", "delete"}
        }
        missing = sorted(declared - s.called)
        assert not missing, f"UNCOVERED operations: {missing}"

    await s.check("every /v1 operation exercised", coverage)
    return s.results


async def main(base_url: str) -> int:
    async with httpx.AsyncClient(base_url=base_url, timeout=15) as client:
        try:
            results = await run(client)
        except httpx.ConnectError:
            print(f"cannot reach {base_url}. Start it with: make api-local")
            return 2
    width = max(len(r.name) for r in results)
    for r in results:
        print(f"{'PASS' if r.ok else 'FAIL'}  {r.name.ljust(width)}  {r.detail}")
    failed = [r for r in results if not r.ok]
    print(f"\n{len(results) - len(failed)}/{len(results)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(
        asyncio.run(main(sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000"))
    )
