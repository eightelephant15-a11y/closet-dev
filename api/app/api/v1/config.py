from typing import Annotated, Any

from fastapi import APIRouter, Depends
from redis.asyncio import Redis

from app.core.auth import DbSession
from app.core.config import Settings, get_settings
from app.core.redis import get_redis
from app.domain.taxonomy import TAXONOMY_VERSION
from app.domain.taxonomy_data import TAXONOMY
from app.schemas.config import ConfigResponse
from app.services.flags import get_flags

router = APIRouter(tags=["config"])

MIN_AGE = 16


@router.get("/taxonomy", response_model=dict[str, Any])
async def get_taxonomy() -> dict[str, Any]:
    """The garment taxonomy document (public; the app also bundles it)."""
    return TAXONOMY


@router.get("/config", response_model=ConfigResponse)
async def get_config(
    session: DbSession,
    redis: Annotated[Redis, Depends(get_redis)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> ConfigResponse:
    return ConfigResponse(
        flags=await get_flags(session, redis),
        policy_version=settings.policy_version,
        privacy_policy_url=settings.privacy_policy_url,
        terms_url=settings.terms_url,
        min_age=MIN_AGE,
        taxonomy_version=TAXONOMY_VERSION,
    )
