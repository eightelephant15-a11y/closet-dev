"""Fixed-window per-user rate limits in Redis (cheap and good enough for abuse control)."""

import time

from redis.asyncio import Redis

from app.core.errors import ApiError


async def hit(
    redis: Redis, *, bucket: str, user_id: object, limit: int, window_seconds: int, cost: int = 1
) -> None:
    """Counts ``cost`` against ``bucket`` for the user; raises 429 ``rate_limited`` past ``limit``."""
    now = int(time.time())
    window = now // window_seconds
    key = f"rl:{bucket}:{user_id}:{window}"
    count = await redis.incrby(key, cost)
    if count == cost:
        await redis.expire(key, window_seconds + 5)
    if count > limit:
        retry_after = (window + 1) * window_seconds - now
        raise ApiError(
            429,
            "rate_limited",
            "Too many requests. Please slow down.",
            {"bucket": bucket, "limit": limit, "retry_after_seconds": retry_after},
            headers={"Retry-After": str(max(retry_after, 1))},
        )
