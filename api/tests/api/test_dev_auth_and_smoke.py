"""AUTH_MODE=dev: works locally, is impossible in prod, and the smoke script passes end to end."""

import time
from collections.abc import AsyncIterator
from pathlib import Path

import fakeredis
import pytest
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app import smoke
from app.core import auth as auth_mod
from app.core import redis as redis_mod
from app.core.config import Settings, get_settings
from app.core.db import Base, get_session, get_sessionmaker
from app.core.errors import ApiError
from app.main import create_app
from app.services.storage import LocalStorage, set_storage

SECRET = "x" * 32


def settings(**kw: object) -> Settings:
    return Settings(_env_file=None, **kw)  # type: ignore[call-arg]


# ---- the guard: dev auth can never be switched on outside dev -------------------------------


@pytest.mark.parametrize("env", ["prod", "production", "PROD", "staging", "", "qa", "prod "])
def test_dev_auth_is_rejected_outside_dev_envs(env: str) -> None:
    with pytest.raises(ValidationError, match="AUTH_MODE=dev is not allowed"):
        settings(app_env=env, auth_mode="dev", dev_auth_secret=SECRET)


@pytest.mark.parametrize("env", ["dev", "local", "test", "DEV"])
def test_dev_auth_is_allowed_in_dev_envs(env: str) -> None:
    assert settings(app_env=env, auth_mode="dev", dev_auth_secret=SECRET).auth_mode == "dev"


def test_dev_auth_needs_a_real_secret() -> None:
    with pytest.raises(ValidationError, match="DEV_AUTH_SECRET"):
        settings(app_env="dev", auth_mode="dev", dev_auth_secret="short")


def test_env_alias_is_honoured(monkeypatch: pytest.MonkeyPatch) -> None:
    """`ENV=prod` (not just APP_ENV) must also block dev auth."""
    monkeypatch.delenv("APP_ENV", raising=False)
    monkeypatch.setenv("ENV", "prod")
    monkeypatch.setenv("AUTH_MODE", "dev")
    monkeypatch.setenv("DEV_AUTH_SECRET", SECRET)
    with pytest.raises(ValidationError, match="not allowed"):
        settings()


def test_verifier_itself_refuses_prod_even_if_settings_were_bypassed() -> None:
    forged = Settings.model_construct(app_env="prod", auth_mode="dev", dev_auth_secret=SECRET)
    with pytest.raises(RuntimeError, match="only available"):
        auth_mod.DevTokenVerifier(forged)


def test_firebase_mode_is_the_default() -> None:
    assert settings().auth_mode == "firebase"


def test_app_with_prod_env_and_dev_auth_does_not_start(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "prod")
    monkeypatch.setenv("AUTH_MODE", "dev")
    monkeypatch.setenv("DEV_AUTH_SECRET", SECRET)
    get_settings.cache_clear()
    try:
        with pytest.raises(ValidationError):
            create_app()
    finally:
        get_settings.cache_clear()


async def test_dev_token_route_is_absent_in_firebase_mode(client: AsyncClient) -> None:
    assert (await client.post("/dev/token", json={})).status_code == 404
    assert "/dev/token" not in (await client.get("/openapi.json")).text


# ---- the verifier ------------------------------------------------------------------------------


def dev_verifier() -> auth_mod.DevTokenVerifier:
    return auth_mod.DevTokenVerifier(
        settings(app_env="dev", auth_mode="dev", dev_auth_secret=SECRET)
    )


async def test_dev_tokens_round_trip_and_distinguish_guests() -> None:
    v = dev_verifier()
    member = await v.verify(v.mint("u1", "a@x.com", "Ada"))
    assert (member.uid, member.email, member.name, member.is_anonymous) == (
        "u1",
        "a@x.com",
        "Ada",
        False,
    )
    assert (await v.verify(v.mint("g1"))).is_anonymous


@pytest.mark.parametrize(
    "mutate", ["flip_sig", "other_secret", "expired", "garbage", "wrong_prefix", "tamper_payload"]
)
async def test_bad_dev_tokens_are_rejected(mutate: str) -> None:
    v = dev_verifier()
    token = v.mint("u1", "a@x.com")
    other = auth_mod.DevTokenVerifier(
        settings(app_env="dev", auth_mode="dev", dev_auth_secret="y" * 32)
    )
    bad = {
        "flip_sig": token[:-1] + ("0" if token[-1] != "0" else "1"),
        "other_secret": other.mint("u1", "a@x.com"),
        "expired": v.mint("u1", "a@x.com", ttl_seconds=-5),
        "garbage": "not-a-token",
        "wrong_prefix": "fake:" + token,
        "tamper_payload": token.split(".")[0]
        + "."
        + v.mint("admin", "x@x.com").split(".")[1]
        + "."
        + token.split(".")[2],
    }[mutate]
    with pytest.raises(ApiError) as exc:
        await v.verify(bad)
    assert exc.value.code == "invalid_token"
    assert time.time() > 0


# ---- the smoke script against an in-process dev-mode app ---------------------------------------


@pytest.fixture
async def dev_client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[AsyncClient]:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("AUTH_MODE", "dev")
    monkeypatch.setenv("DEV_AUTH_SECRET", SECRET)
    get_settings.cache_clear()
    auth_mod._verifier = None
    redis_mod.set_redis(fakeredis.FakeAsyncRedis(decode_responses=True))
    set_storage(LocalStorage(tmp_path / "exports"))
    engine = create_async_engine(
        "sqlite+aiosqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)

    async def _session() -> AsyncIterator:  # type: ignore[type-arg]
        async with maker() as s:
            yield s

    app = create_app()
    app.dependency_overrides[get_session] = _session
    app.dependency_overrides[get_sessionmaker] = lambda: maker
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    await engine.dispose()
    auth_mod._verifier = None
    get_settings.cache_clear()


async def test_smoke_script_passes_against_the_real_app(dev_client: AsyncClient) -> None:
    results = await smoke.run(dev_client)
    failures = [f"{r.name}: {r.detail}" for r in results if not r.ok]
    assert not failures, failures
    assert any(r.name == "every /v1 operation exercised" and r.ok for r in results)


async def test_smoke_fails_loudly_when_an_operation_is_not_covered(dev_client: AsyncClient) -> None:
    @dev_client._transport.app.get("/v1/_new_thing")  # type: ignore[attr-defined,untyped-decorator]
    async def _new() -> dict[str, str]:
        return {}

    results = await smoke.run(dev_client)
    cov = next(r for r in results if r.name == "every /v1 operation exercised")
    assert not cov.ok and "/v1/_new_thing" in cov.detail


def test_local_server_prepares_a_dev_only_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    from app import local_server

    monkeypatch.delenv("APP_ENV", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    local_server.prepare_environment()
    import os

    assert os.environ["AUTH_MODE"] == "dev" and os.environ["APP_ENV"] == "dev"
    assert os.environ["DATABASE_URL"].startswith("sqlite+aiosqlite:///")


def test_local_server_refuses_to_run_with_prod_env(monkeypatch: pytest.MonkeyPatch) -> None:
    from app import local_server

    monkeypatch.setenv("APP_ENV", "prod")
    get_settings.cache_clear()
    try:
        with pytest.raises(ValidationError):
            local_server.main()
    finally:
        get_settings.cache_clear()
