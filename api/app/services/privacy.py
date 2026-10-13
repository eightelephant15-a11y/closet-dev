"""Consents, data export, account deletion and the 30-day purge."""

import hashlib
import uuid
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import structlog
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import TokenVerifier
from app.core.config import get_settings
from app.core.db import MERGEABLE
from app.models import (
    AuditLog,
    Consents,
    DeviceSession,
    ExportJob,
    ExportStatus,
    OnboardingState,
    Preferences,
    User,
    UserStatus,
)
from app.services.storage import ExportStorage, dumps

log = structlog.get_logger()

# Phase 2 registers a hook that deletes the user's images/objects.
PurgeHook = Callable[[uuid.UUID], Awaitable[None]]
PURGE_HOOKS: list[PurgeHook] = []


def register_purge_hook(hook: PurgeHook) -> None:
    if hook not in PURGE_HOOKS:
        PURGE_HOOKS.append(hook)


def _ref(user_id: uuid.UUID) -> str:
    return hashlib.sha256(user_id.bytes).hexdigest()


async def audit(session: AsyncSession, event: str, user_id: uuid.UUID) -> None:
    session.add(AuditLog(event=event, user_ref=_ref(user_id)))


# ---- consents -----------------------------------------------------------------------------


async def default_consents(session: AsyncSession, user: User) -> Consents:
    row = Consents(
        user_id=user.id,
        analytics_opt_in=None,
        no_ai_training=True,
        policy_version=get_settings().policy_version,
    )
    session.add(row)
    return row


async def get_consents(session: AsyncSession, user: User) -> Consents:
    row = await session.get(Consents, user.id)
    if row is None:
        row = await default_consents(session, user)
        await session.commit()
    return row


async def update_consents(
    session: AsyncSession,
    user: User,
    *,
    analytics_opt_in: bool | None,
    no_ai_training: bool | None,
    location_explained: bool | None,
) -> Consents:
    row = await get_consents(session, user)
    now = datetime.now(UTC)
    version = get_settings().policy_version
    if analytics_opt_in is not None and analytics_opt_in != row.analytics_opt_in:
        row.analytics_opt_in, row.analytics_updated_at = analytics_opt_in, now
    if no_ai_training is not None and no_ai_training != row.no_ai_training:
        row.no_ai_training, row.ai_training_updated_at = no_ai_training, now
    if location_explained and row.location_explained_at is None:
        row.location_explained_at = now
    row.policy_version = version
    await session.commit()
    return row


# ---- export -------------------------------------------------------------------------------


def _iso(v: datetime | None) -> str | None:
    return v.isoformat() if v else None


async def build_export(session: AsyncSession, user: User) -> dict[str, Any]:
    onboarding = await session.get(OnboardingState, user.id)
    prefs = await session.get(Preferences, user.id)
    consents = await session.get(Consents, user.id)
    sessions = (
        (await session.execute(select(DeviceSession).where(DeviceSession.user_id == user.id)))
        .scalars()
        .all()
    )
    return {
        "exported_at": datetime.now(UTC).isoformat(),
        "format_version": 1,
        "profile": {
            "id": str(user.id),
            "email": user.email,
            "display_name": user.display_name,
            "locale": user.locale,
            "units": user.units.value,
            "city": user.city,
            "clothing_department": user.clothing_department.value
            if user.clothing_department
            else None,
            "daily_outfit_time": user.daily_outfit_time,
            "age_confirmed_at": _iso(user.age_confirmed_at),
            "created_at": _iso(user.created_at),
        },
        "onboarding": None
        if onboarding is None
        else {
            "variant": onboarding.variant,
            "current_step": onboarding.current_step,
            "completed_steps": onboarding.completed_steps,
            "started_at": _iso(onboarding.started_at),
            "completed_at": _iso(onboarding.completed_at),
            "time_to_first_outfit_ms": onboarding.time_to_first_outfit_ms,
        },
        "preferences": None
        if prefs is None
        else {
            "model_version": prefs.model_version,
            "answers": prefs.answers,
            "weights": prefs.weights,
        },
        "consents": None
        if consents is None
        else {
            "analytics_opt_in": consents.analytics_opt_in,
            "no_ai_training": consents.no_ai_training,
            "policy_version": consents.policy_version,
            "analytics_updated_at": _iso(consents.analytics_updated_at),
            "ai_training_updated_at": _iso(consents.ai_training_updated_at),
        },
        "devices": [
            {
                "platform": s.platform,
                "app_version": s.app_version,
                "created_at": _iso(s.created_at),
                "last_seen_at": _iso(s.last_seen_at),
            }
            for s in sessions
        ],
        # Phase 2+: closet items and image references are appended here.
    }


async def create_export_job(session: AsyncSession, user: User) -> ExportJob:
    job = ExportJob(user_id=user.id, status=ExportStatus.pending)
    session.add(job)
    await session.commit()
    return job


async def run_export_job(session: AsyncSession, storage: ExportStorage, job_id: uuid.UUID) -> None:
    job = await session.get(ExportJob, job_id)
    if job is None or job.status != ExportStatus.pending:
        return
    try:
        user = await session.get(User, job.user_id)
        if user is None:
            raise LookupError("user gone")
        key = f"exports/{user.id}/{job.id}.json"
        await storage.put(key, dumps(await build_export(session, user)))
        job.file_key = key
        job.status = ExportStatus.completed
        job.completed_at = datetime.now(UTC)
        job.expires_at = job.completed_at + timedelta(hours=get_settings().export_ttl_hours)
        await audit(session, "data_exported", user.id)
    except Exception:
        log.exception("export_failed", job_id=str(job_id))
        job.status = ExportStatus.failed
    await session.commit()


# ---- deletion ------------------------------------------------------------------------------


async def hard_delete_user(session: AsyncSession, user: User, storage: ExportStorage) -> None:
    """Removes every row, file and object belonging to the user."""
    jobs = (
        (await session.execute(select(ExportJob).where(ExportJob.user_id == user.id)))
        .scalars()
        .all()
    )
    for job in jobs:
        if job.file_key:
            await storage.delete(job.file_key)
    await session.execute(delete(ExportJob).where(ExportJob.user_id == user.id))
    for hook in PURGE_HOOKS:
        await hook(user.id)
    for model in MERGEABLE:
        await session.execute(delete(model).where(model.__table__.c.user_id == user.id))
    await session.execute(delete(DeviceSession).where(DeviceSession.user_id == user.id))
    await session.delete(user)
    await session.commit()


async def request_deletion(session: AsyncSession, user: User, verifier: TokenVerifier) -> datetime:
    """Soft delete: sign the user out everywhere now, purge all data after 30 days."""
    now = datetime.now(UTC)
    user.status = UserStatus.pending_deletion
    user.deleted_at = now
    user.purge_after = now + timedelta(days=get_settings().purge_after_days)
    for ds in (
        await session.execute(select(DeviceSession).where(DeviceSession.user_id == user.id))
    ).scalars():
        ds.revoked_at = now
    await audit(session, "deletion_requested", user.id)
    await session.commit()
    await verifier.revoke_all(user.auth_uid)
    return user.purge_after


async def restore_account(session: AsyncSession, user: User) -> None:
    if user.status != UserStatus.pending_deletion:
        return
    user.status, user.deleted_at, user.purge_after = UserStatus.active, None, None
    await audit(session, "deletion_cancelled", user.id)
    await session.commit()


async def purge_due_users(
    session: AsyncSession,
    storage: ExportStorage,
    verifier: TokenVerifier,
    now: datetime | None = None,
) -> int:
    """Hard-deletes accounts whose 30-day window has passed. Idempotent; run daily."""
    now = now or datetime.now(UTC)
    due = (
        (
            await session.execute(
                select(User).where(
                    User.status == UserStatus.pending_deletion, User.purge_after <= now
                )
            )
        )
        .scalars()
        .all()
    )
    for user in due:
        uid, user_id = user.auth_uid, user.id
        await hard_delete_user(session, user, storage)
        await verifier.delete_user(uid)
        await audit(session, "account_purged", user_id)
        await session.commit()
    return len(due)


async def run_pending_exports(session: AsyncSession, storage: ExportStorage) -> int:
    """Worker path: picks up export jobs the API process did not finish (e.g. it restarted)."""
    ids = (
        (
            await session.execute(
                select(ExportJob.id).where(ExportJob.status == ExportStatus.pending)
            )
        )
        .scalars()
        .all()
    )
    for job_id in ids:
        await run_export_job(session, storage, job_id)
    return len(ids)
