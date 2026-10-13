"""Hard-delete of a user's data (also used for under-16 rejection and the 30-day purge)."""

from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import MERGEABLE
from app.models import DeviceSession, User


async def hard_delete_user(session: AsyncSession, user: User) -> None:
    for model in MERGEABLE:
        await session.execute(delete(model).where(model.__table__.c.user_id == user.id))
    await session.execute(delete(DeviceSession).where(DeviceSession.user_id == user.id))
    await session.delete(user)
    await session.commit()
