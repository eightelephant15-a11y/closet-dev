"""Dev-only routes, mounted only when AUTH_MODE=dev (Settings forbids that in prod)."""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.auth import DevTokenVerifier, get_verifier

router = APIRouter(prefix="/dev", tags=["dev"], include_in_schema=False)


class DevTokenRequest(BaseModel):
    uid: str | None = None
    email: str | None = None  # no email => anonymous (guest) identity
    name: str | None = None


class DevTokenResponse(BaseModel):
    token: str
    uid: str
    email: str | None
    name: str | None
    is_anonymous: bool


def _dev_verifier(verifier: Annotated[object, Depends(get_verifier)]) -> DevTokenVerifier:
    assert isinstance(verifier, DevTokenVerifier)  # noqa: S101
    return verifier


@router.post("/token", response_model=DevTokenResponse)
async def mint_token(
    body: DevTokenRequest, verifier: Annotated[DevTokenVerifier, Depends(_dev_verifier)]
) -> DevTokenResponse:
    """Stand-in for Google / anonymous sign-in. Same uid + an email == "link Google to guest"."""
    uid = body.uid or f"dev-{uuid.uuid4().hex[:12]}"
    token = verifier.mint(uid, body.email, body.name)
    return DevTokenResponse(
        token=token, uid=uid, email=body.email, name=body.name, is_anonymous=not body.email
    )
