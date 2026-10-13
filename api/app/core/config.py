from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "dev"
    database_url: str = "postgresql+asyncpg://stylist:stylist@localhost:5432/stylist"
    redis_url: str = "redis://localhost:6379/0"
    sentry_dsn: str = ""
    firebase_project_id: str = "stylist-dev"
    privacy_policy_url: str = "https://example.com/privacy"
    terms_url: str = "https://example.com/terms"
    policy_version: str = "2026-01"
    purge_after_days: int = 30
    idempotency_ttl_seconds: int = 86400


@lru_cache
def get_settings() -> Settings:
    return Settings()
