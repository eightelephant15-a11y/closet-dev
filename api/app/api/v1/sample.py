from typing import Annotated, Any

from fastapi import APIRouter, Query

from app.core.auth import CurrentUser
from app.data import places as places_data
from app.data.sample_closet import SAMPLE_ITEMS

router = APIRouter(tags=["sample"])


@router.get("/places/autocomplete", response_model=list[str])
async def autocomplete(_: CurrentUser, q: Annotated[str, Query(max_length=60)] = "") -> list[str]:
    """Stub for the PlacesService seam: canned US city names, no coordinates."""
    return places_data.autocomplete(q)


@router.get("/sample/closet", response_model=list[dict[str, Any]])
async def sample_closet(_: CurrentUser) -> list[dict[str, Any]]:
    """Read-only sample items for guests. Phase 2 replaces this with the real closet."""
    return SAMPLE_ITEMS
