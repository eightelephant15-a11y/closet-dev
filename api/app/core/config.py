from functools import lru_cache
from typing import Literal

from pydantic import AliasChoices, Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# The dev token verifier skips Firebase entirely, so it may only ever run in these environments.
# Anything else (prod, staging, a typo, an empty string) refuses to start.
DEV_AUTH_ENVS = frozenset({"dev", "local", "test"})


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", populate_by_name=True)

    app_env: str = Field(default="dev", validation_alias=AliasChoices("APP_ENV", "ENV"))
    # "firebase" verifies real Firebase ID tokens. "dev" accepts HMAC-signed dev tokens minted by
    # POST /dev/token, for running the API locally with no Firebase project.
    # It is impossible outside DEV_AUTH_ENVS (see the validator below).
    auth_mode: Literal["firebase", "dev"] = "firebase"
    dev_auth_secret: str = ""
    database_url: str = "postgresql+asyncpg://stylist:stylist@localhost:5432/stylist"
    redis_url: str = "redis://localhost:6379/0"
    sentry_dsn: str = ""
    firebase_project_id: str = "stylist-dev"
    firebase_credentials_json: str = ""  # service-account JSON from Secrets Manager (never in git)
    privacy_policy_url: str = "https://example.com/privacy"
    terms_url: str = "https://example.com/terms"
    policy_version: str = "2026-01"
    purge_after_days: int = 30
    export_bucket: str = ""  # empty => local disk (dev/tests)
    export_dir: str = ".exports"
    export_ttl_hours: int = 24
    idempotency_ttl_seconds: int = 86400

    @model_validator(mode="after")
    def _dev_auth_only_in_dev(self) -> "Settings":
        if self.auth_mode == "dev":
            if self.app_env.strip().lower() not in DEV_AUTH_ENVS:
                raise ValueError(
                    f"AUTH_MODE=dev is not allowed when APP_ENV={self.app_env!r} "
                    f"(allowed: {sorted(DEV_AUTH_ENVS)})"
                )
            if len(self.dev_auth_secret) < 16:
                raise ValueError("AUTH_MODE=dev requires DEV_AUTH_SECRET (at least 16 characters)")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
