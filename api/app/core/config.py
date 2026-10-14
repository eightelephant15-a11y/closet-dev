from functools import lru_cache
from typing import Literal

from pydantic import AliasChoices, Field, SecretStr, model_validator
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

    # ---- closet (phase 2) ------------------------------------------------------------------
    # Object storage: "local" (disk + HMAC-signed URLs served by this API; dev/test only) or "s3".
    storage_backend: Literal["local", "s3"] = "local"
    storage_dir: str = ".storage"
    storage_signing_secret: str = "local-storage-secret-not-for-production"  # noqa: S105
    images_bucket: str = ""
    aws_region: str = "us-east-1"
    upload_url_ttl_seconds: int = 900
    read_url_ttl_seconds: int = 600
    upload_max_bytes: int = 12 * 1024 * 1024
    image_max_dimension: int = 8000  # px, either side, after decoding
    image_max_pixels: int = 50_000_000
    upload_rate_per_hour: int = 120  # garment creations / upload tickets per user
    # Job queue: "arq" (Redis; production and local worker) or "eager" (inline; tests).
    queue_backend: Literal["arq", "eager"] = "arq"
    queue_max_tries: int = 3
    # Vision. The provider *name* is a remote-config flag (`vision_provider`); these are its settings.
    vision_model: str = "claude-opus-5-5"
    vision_effort: str = "low"  # empty = omit; see app/vision/claude.py
    anthropic_api_key: SecretStr = SecretStr("")
    vision_price_input_per_mtok: float = 0.0  # USD per million tokens; 0 = unknown
    vision_price_output_per_mtok: float = 0.0
    vision_daily_cap: int = 200  # analyses per user per UTC day
    reanalyse_daily_cap: int = 10
    background_remover: Literal["passthrough", "rembg"] = "passthrough"
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

    @model_validator(mode="after")
    def _local_storage_only_in_dev(self) -> "Settings":
        if self.storage_backend == "local" and self.app_env.strip().lower() not in DEV_AUTH_ENVS:
            raise ValueError(
                f"STORAGE_BACKEND=local is only for dev/test (APP_ENV={self.app_env!r}); use s3"
            )
        if self.storage_backend == "s3" and not self.images_bucket:
            raise ValueError("STORAGE_BACKEND=s3 requires IMAGES_BUCKET")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
