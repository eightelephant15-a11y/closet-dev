"""User provisioning, device sessions, guest->account upgrade/merge."""

import uuid
from datetime import UTC, datetime

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import VerifiedToken
from app.core.db import MERGEABLE, register_mergeable
from app.core.errors import ApiError
from app.models import DeviceSession, User, UserStatus
from app.schemas.user import SessionRequest

__all__ = ["MERGEABLE", "register_mergeable"]


async def find_user(session: AsyncSession, uid: str) -> User | None:
    return (await session.execute(select(User).where(User.auth_uid == uid))).scalar_one_or_none()


async def provision_user(
    session: AsyncSession, vt: VerifiedToken, req: SessionRequest
) -> tuple[User, DeviceSession, bool]:
    user = await find_user(session, vt.uid)
    is_new = user is None
    if user is None:
        user = User(
            auth_uid=vt.uid, email=vt.email, display_name=vt.name, is_anonymous=vt.is_anonymous
        )
        session.add(user)
        await session.flush()
    elif user.status != UserStatus.active:
        raise ApiError(403, "account_inactive", "This account is scheduled for deletion")

    ds = (
        await session.execute(
            select(DeviceSession).where(
                DeviceSession.user_id == user.id, DeviceSession.device_id == req.device_id
            )
        )
    ).scalar_one_or_none()
    if ds is None:
        ds = DeviceSession(
            user_id=user.id,
            device_id=req.device_id,
            platform=req.platform,
            app_version=req.app_version,
        )
        session.add(ds)
    else:
        # A fresh sign-in on this device re-opens a previously signed-out session.
        ds.revoked_at = None
        ds.app_version = req.app_version
        ds.last_seen_at = datetime.now(UTC)
    await session.commit()
    return user, ds, is_new


def _apply_profile(user: User, vt: VerifiedToken) -> None:
    user.is_anonymous = vt.is_anonymous
    user.email = vt.email or user.email
    if vt.name and not user.display_name:
        user.display_name = vt.name


async def upgrade_guest(
    session: AsyncSession, user: User, vt: VerifiedToken, guest: User | None
) -> User:
    """Mark ``user`` as a full account. ``guest`` (optional) is merged into ``user``."""
    if vt.is_anonymous:
        raise ApiError(400, "not_upgraded", "Token is still anonymous; link Google first")
    _apply_profile(user, vt)
    if guest is not None and guest.id != user.id:
        await merge_users(session, source=guest, target=user)
    await session.commit()
    return user


async def merge_users(session: AsyncSession, source: User, target: User) -> None:
    if not source.is_anonymous:
        raise ApiError(400, "merge_not_allowed", "Only guest accounts can be merged")
    for model in MERGEABLE:
        user_id_col = model.__table__.c.user_id
        has_target = (
            await session.execute(select(user_id_col).where(user_id_col == target.id))
        ).first()
        if has_target:
            await session.execute(delete(model).where(user_id_col == source.id))
        else:
            await session.execute(
                update(model).where(user_id_col == source.id).values(user_id=target.id)
            )
    # Carry over profile answers the existing account hasn't set.
    for field in ("city", "clothing_department", "age_confirmed_at", "display_name"):
        if getattr(target, field) is None and getattr(source, field) is not None:
            setattr(target, field, getattr(source, field))
    await session.execute(delete(DeviceSession).where(DeviceSession.user_id == source.id))
    await session.delete(source)
    await session.flush()


async def revoke_session(session: AsyncSession, user: User, session_id: uuid.UUID) -> None:
    ds = await session.get(DeviceSession, session_id)
    if ds is None or ds.user_id != user.id:
        raise ApiError(404, "session_not_found", "Session not found")
    ds.revoked_at = datetime.now(UTC)
    await session.commit()
