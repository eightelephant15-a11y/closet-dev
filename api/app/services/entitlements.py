"""Entitlements: what the user's plan allows. Limits come from remote config so they can change without
a release. Enforced on the server; the app only shows a friendly upgrade prompt (payments are Phase 6)."""

from dataclasses import dataclass

from redis.asyncio import Redis
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models import Garment, User
from app.services.flags import get_flags


@dataclass(frozen=True)
class Entitlements:
    plan: str
    closet_item_limit: int
    closet_items_used: int
    bulk_add_enabled: bool

    @property
    def remaining(self) -> int:
        return max(self.closet_item_limit - self.closet_items_used, 0)


async def count_closet_items(session: AsyncSession, user: User) -> int:
    """Items that count towards the limit: not archived, not the bundled guest sample."""
    stmt = (
        select(func.count())
        .select_from(Garment)
        .where(
            Garment.user_id == user.id, Garment.archived_at.is_(None), Garment.is_sample.is_(False)
        )
    )
    return (await session.execute(stmt)).scalar_one()


async def get_entitlements(session: AsyncSession, redis: Redis, user: User) -> Entitlements:
    flags = await get_flags(session, redis)
    return Entitlements(
        plan="free",  # Phase 6 introduces paid plans
        closet_item_limit=int(flags["closet_item_limit_free"]),
        closet_items_used=await count_closet_items(session, user),
        bulk_add_enabled=bool(flags["closet_bulk_add_enabled"]),
    )


def ensure_can_add(ent: Entitlements, count: int = 1) -> None:
    if ent.remaining < count:
        raise ApiError(
            403,
            "item_limit_reached",
            "Your closet is full on the free plan.",
            {
                "limit": ent.closet_item_limit,
                "used": ent.closet_items_used,
                "remaining": ent.remaining,
                "requested": count,
                "plan": ent.plan,
            },
        )
