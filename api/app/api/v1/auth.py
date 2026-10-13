import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Header, Response
from sqlalchemy import select

from app.core.auth import (
    CurrentUser,
    DbSession,
    TokenVerifier,
    VerifiedToken,
    get_verifier,
    verified_token,
)
from app.core.errors import ApiError
from app.core.pagination import Page, PageParams, decode_cursor, encode_cursor, page_params
from app.models import DeviceSession
from app.schemas.user import (
    AuthSessionResponse,
    SessionOut,
    SessionRequest,
    UpgradeRequest,
    UserOut,
)
from app.services import accounts

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/session", response_model=AuthSessionResponse)
async def create_session(
    body: SessionRequest,
    vt: Annotated[VerifiedToken, Depends(verified_token)],
    session: DbSession,
) -> AuthSessionResponse:
    user, ds, is_new = await accounts.provision_user(session, vt, body)
    return AuthSessionResponse(
        user=UserOut.model_validate(user), session=SessionOut.model_validate(ds), is_new_user=is_new
    )


@router.post("/upgrade", response_model=UserOut)
async def upgrade(
    body: UpgradeRequest,
    vt: Annotated[VerifiedToken, Depends(verified_token)],
    user: CurrentUser,
    session: DbSession,
    verifier: Annotated[TokenVerifier, Depends(get_verifier)],
) -> UserOut:
    guest = None
    if body.merge_from_token:
        gvt = await verifier.verify(body.merge_from_token)
        guest = await accounts.find_user(session, gvt.uid)
        if guest is None:
            raise ApiError(404, "guest_not_found", "Guest session not found")
    await accounts.upgrade_guest(session, user, vt, guest)
    return UserOut.model_validate(user)


@router.get("/sessions", response_model=Page[SessionOut])
async def list_sessions(
    user: CurrentUser,
    session: DbSession,
    params: Annotated[PageParams, Depends(page_params)],
) -> Page[SessionOut]:
    offset = decode_cursor(params.cursor)
    rows = (
        (
            await session.execute(
                select(DeviceSession)
                .where(DeviceSession.user_id == user.id)
                .order_by(DeviceSession.last_seen_at.desc(), DeviceSession.id)
                .offset(offset)
                .limit(params.limit + 1)
            )
        )
        .scalars()
        .all()
    )
    has_more = len(rows) > params.limit
    items = [SessionOut.model_validate(r) for r in rows[: params.limit]]
    return Page[SessionOut](
        items=items, next_cursor=encode_cursor(offset + params.limit) if has_more else None
    )


@router.delete("/sessions/{session_id}", status_code=204)
async def revoke(session_id: uuid.UUID, user: CurrentUser, session: DbSession) -> Response:
    await accounts.revoke_session(session, user, session_id)
    return Response(status_code=204)


@router.post("/sign-out", status_code=204)
async def sign_out(
    user: CurrentUser,
    session: DbSession,
    x_device_id: Annotated[str | None, Header()] = None,
) -> Response:
    if x_device_id:
        ds = (
            await session.execute(
                select(DeviceSession).where(
                    DeviceSession.user_id == user.id, DeviceSession.device_id == x_device_id
                )
            )
        ).scalar_one_or_none()
        if ds is not None:
            await accounts.revoke_session(session, user, ds.id)
    return Response(status_code=204)
