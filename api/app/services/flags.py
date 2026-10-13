import json
from typing import Any

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import FeatureFlag

CACHE_KEY = "flags:v1"
CACHE_TTL = 60

FLAG_DEFAULTS: dict[str, bool | str | int] = {
    "guest_mode_enabled": True,
    "onboarding_variant": "quiz_first",
}
ALLOWED: dict[str, set[Any] | None] = {
    "onboarding_variant": {"quiz_first", "closet_first"},
}


def _valid(key: str, value: object) -> bool:
    default = FLAG_DEFAULTS.get(key)
    if default is None or type(value) is not type(default):
        return False
    allowed = ALLOWED.get(key)
    return allowed is None or value in allowed


async def get_flags(session: AsyncSession, redis: Redis) -> dict[str, bool | str | int]:
    cached = await redis.get(CACHE_KEY)
    if cached:
        return json.loads(cached)  # type: ignore[no-any-return]
    flags = dict(FLAG_DEFAULTS)
    for row in (await session.execute(select(FeatureFlag))).scalars():
        if _valid(row.key, row.value):
            flags[row.key] = row.value  # type: ignore[assignment]
    await redis.set(CACHE_KEY, json.dumps(flags), ex=CACHE_TTL)
    return flags


async def set_flag(session: AsyncSession, redis: Redis, key: str, value: bool | str | int) -> None:
    """Write path for a future admin panel."""
    if not _valid(key, value):
        raise ValueError(f"invalid flag {key}={value!r}")
    row = await session.get(FeatureFlag, key)
    if row is None:
        session.add(FeatureFlag(key=key, value=value))
    else:
        row.value = value
    await session.commit()
    await redis.delete(CACHE_KEY)
