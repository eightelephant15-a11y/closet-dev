"""Token verification (interface + Firebase and fake implementations) and auth dependencies."""

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Annotated, Protocol

from fastapi import Depends, Header
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.errors import ApiError
from app.models import DeviceSession, User, UserStatus


@dataclass(frozen=True)
class VerifiedToken:
    uid: str
    email: str | None
    name: str | None
    is_anonymous: bool


class TokenVerifier(Protocol):
    async def verify(self, token: str) -> VerifiedToken: ...

    async def revoke_all(self, uid: str) -> None: ...

    async def delete_user(self, uid: str) -> None: ...


class FirebaseTokenVerifier:
    """Verifies Firebase ID tokens with the Admin SDK (checks revocation)."""

    def __init__(self) -> None:
        import json

        import firebase_admin
        from firebase_admin import credentials

        from app.core.config import get_settings

        settings = get_settings()
        if not firebase_admin._apps:
            if settings.firebase_credentials_json:
                cred = credentials.Certificate(json.loads(settings.firebase_credentials_json))
                firebase_admin.initialize_app(cred, {"projectId": settings.firebase_project_id})
            else:  # local: GOOGLE_APPLICATION_CREDENTIALS or the Auth emulator
                firebase_admin.initialize_app(options={"projectId": settings.firebase_project_id})

    async def verify(self, token: str) -> VerifiedToken:
        import asyncio

        from firebase_admin import auth

        try:
            claims = await asyncio.to_thread(auth.verify_id_token, token, check_revoked=True)
        except Exception as exc:
            raise ApiError(401, "invalid_token", "Invalid or expired credentials") from exc
        provider = claims.get("firebase", {}).get("sign_in_provider")
        return VerifiedToken(
            uid=claims["uid"],
            email=claims.get("email"),
            name=claims.get("name"),
            is_anonymous=provider == "anonymous",
        )

    async def revoke_all(self, uid: str) -> None:
        import asyncio

        from firebase_admin import auth

        await asyncio.to_thread(auth.revoke_refresh_tokens, uid)

    async def delete_user(self, uid: str) -> None:
        import asyncio

        from firebase_admin import auth

        await asyncio.to_thread(auth.delete_user, uid)


class FakeTokenVerifier:
    """Test/dev verifier. Token format: ``fake:<uid>[:<email>[:<name>]]``; no email => anonymous."""

    def __init__(self) -> None:
        self.revoked: list[str] = []
        self.deleted: list[str] = []

    async def verify(self, token: str) -> VerifiedToken:
        parts = token.split(":")
        if len(parts) < 2 or parts[0] != "fake":
            raise ApiError(401, "invalid_token", "Invalid or expired credentials")
        email = parts[2] if len(parts) > 2 and parts[2] else None
        name = parts[3] if len(parts) > 3 else None
        return VerifiedToken(uid=parts[1], email=email, name=name, is_anonymous=email is None)

    async def revoke_all(self, uid: str) -> None:
        self.revoked.append(uid)

    async def delete_user(self, uid: str) -> None:
        self.deleted.append(uid)


_verifier: TokenVerifier | None = None


def set_verifier(v: TokenVerifier) -> None:
    global _verifier
    _verifier = v


def get_verifier() -> TokenVerifier:
    global _verifier
    if _verifier is None:
        _verifier = FirebaseTokenVerifier()
    return _verifier


async def bearer_token(authorization: Annotated[str | None, Header()] = None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise ApiError(401, "missing_token", "Authentication required")
    return authorization[7:]


async def verified_token(
    token: Annotated[str, Depends(bearer_token)],
    verifier: Annotated[TokenVerifier, Depends(get_verifier)],
) -> VerifiedToken:
    return await verifier.verify(token)


async def _load_user(
    vt: VerifiedToken, session: AsyncSession, x_device_id: str | None, *, allow_pending: bool
) -> User:
    user = (await session.execute(select(User).where(User.auth_uid == vt.uid))).scalar_one_or_none()
    if user is None:
        raise ApiError(401, "no_session", "Call POST /v1/auth/session first")
    if user.status != UserStatus.active and not allow_pending:
        raise ApiError(403, "account_inactive", "This account is scheduled for deletion")
    if x_device_id:
        ds = (
            await session.execute(
                select(DeviceSession).where(
                    DeviceSession.user_id == user.id, DeviceSession.device_id == x_device_id
                )
            )
        ).scalar_one_or_none()
        if ds is not None:
            if ds.revoked_at is not None:
                raise ApiError(401, "session_revoked", "This session was signed out")
            ds.last_seen_at = datetime.now(UTC)
            await session.commit()
    return user


async def current_user(
    vt: Annotated[VerifiedToken, Depends(verified_token)],
    session: Annotated[AsyncSession, Depends(get_session)],
    x_device_id: Annotated[str | None, Header()] = None,
) -> User:
    return await _load_user(vt, session, x_device_id, allow_pending=False)


async def user_allowing_pending_deletion(
    vt: Annotated[VerifiedToken, Depends(verified_token)],
    session: Annotated[AsyncSession, Depends(get_session)],
    x_device_id: Annotated[str | None, Header()] = None,
) -> User:
    return await _load_user(vt, session, x_device_id, allow_pending=True)


CurrentUser = Annotated[User, Depends(current_user)]
PendingOkUser = Annotated[User, Depends(user_allowing_pending_deletion)]
DbSession = Annotated[AsyncSession, Depends(get_session)]

__all__ = ["CurrentUser", "DbSession", "PendingOkUser"]
