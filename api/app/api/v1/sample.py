from typing import Annotated

from fastapi import APIRouter, Query

from app.core.auth import CurrentUser
from app.data import places as places_data

router = APIRouter(tags=["sample"])


@router.get("/places/autocomplete", response_model=list[str])
async def autocomplete(_: CurrentUser, q: Annotated[str, Query(max_length=60)] = "") -> list[str]:
    """Stub for the PlacesService seam: canned US city names, no coordinates."""
    return places_data.autocomplete(q)
