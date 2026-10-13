from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import CurrentUser, DbSession, TokenVerifier, get_verifier
from app.core.errors import ApiError
from app.core.redis import get_redis
from app.domain import preferences as prefs
from app.models import ClothingDepartment, OnboardingState, Preferences, User
from app.schemas.onboarding import (
    AgeConfirmation,
    OnboardingOut,
    OnboardingPut,
    PreferencesOut,
    PreferencesPut,
)
from app.services.flags import get_flags
from app.services.privacy import hard_delete_user

router = APIRouter(tags=["onboarding"])


async def _get_or_create_state(session: AsyncSession, redis: Redis, user: User) -> OnboardingState:
    state = await session.get(OnboardingState, user.id)
    if state is None:
        flags = await get_flags(session, redis)  # variant is pinned on first read
        state = OnboardingState(
            user_id=user.id,
            variant=str(flags["onboarding_variant"]),
            current_step="welcome",
            completed_steps=[],
        )
        session.add(state)
        await session.commit()
    return state


@router.get("/onboarding", response_model=OnboardingOut)
async def get_onboarding(
    user: CurrentUser, session: DbSession, redis: Annotated[Redis, Depends(get_redis)]
) -> OnboardingState:
    return await _get_or_create_state(session, redis, user)


@router.put("/onboarding", response_model=OnboardingOut)
async def put_onboarding(
    body: OnboardingPut,
    user: CurrentUser,
    session: DbSession,
    redis: Annotated[Redis, Depends(get_redis)],
) -> OnboardingState:
    state = await _get_or_create_state(session, redis, user)
    if body.current_step is not None:
        state.current_step = body.current_step
    if body.completed_steps is not None:
        # union: syncing from a stale offline device must never un-complete steps
        state.completed_steps = sorted(set(state.completed_steps) | set(body.completed_steps))
    if body.time_to_first_outfit_ms is not None and state.time_to_first_outfit_ms is None:
        state.time_to_first_outfit_ms = body.time_to_first_outfit_ms
    if body.completed and state.completed_at is None:
        state.completed_at = datetime.now(UTC)
        state.current_step = "done"
    await session.commit()
    return state


@router.post("/me/age-confirmation", status_code=204)
async def confirm_age(
    body: AgeConfirmation,
    user: CurrentUser,
    session: DbSession,
    verifier: Annotated[TokenVerifier, Depends(get_verifier)],
) -> None:
    if not body.confirmed_16_plus:
        uid = user.auth_uid
        await hard_delete_user(session, user)  # no account data kept for under-16
        await verifier.delete_user(uid)
        raise ApiError(403, "age_under_minimum", "You must be 16 or older to use this app")
    if user.age_confirmed_at is None:
        user.age_confirmed_at = datetime.now(UTC)
        await session.commit()


@router.get("/me/preferences", response_model=PreferencesOut)
async def get_preferences(user: CurrentUser, session: DbSession) -> PreferencesOut:
    row = await session.get(Preferences, user.id)
    if row is None:
        return PreferencesOut(
            model_version=prefs.MODEL_VERSION, answers={}, weights=prefs.compute_weights({})
        )
    return PreferencesOut(
        model_version=row.model_version,
        answers=row.answers,
        weights=row.weights,
        updated_at=row.updated_at,
    )


@router.put("/me/preferences", response_model=PreferencesOut)
async def put_preferences(
    body: PreferencesPut, user: CurrentUser, session: DbSession
) -> PreferencesOut:
    row = await session.get(Preferences, user.id)
    merged = {**(row.answers if row else {}), **body.answers}  # answers arrive progressively
    try:
        prefs.validate_answers(merged)
    except ValueError as exc:
        raise ApiError(422, "invalid_answers", f"Invalid quiz answer: {exc}") from exc
    weights = prefs.compute_weights(merged)
    if row is None:
        row = Preferences(user_id=user.id, model_version=prefs.MODEL_VERSION)
        session.add(row)
    row.answers, row.weights, row.model_version = merged, weights, prefs.MODEL_VERSION
    if merged.get("department"):
        user.clothing_department = ClothingDepartment(merged["department"])
    await session.commit()
    await session.refresh(row)
    return PreferencesOut(
        model_version=row.model_version,
        answers=row.answers,
        weights=row.weights,
        updated_at=row.updated_at,
    )
