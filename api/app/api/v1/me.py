from fastapi import APIRouter

from app.core.auth import CurrentUser, DbSession
from app.schemas.user import UserOut, UserPatch

router = APIRouter(prefix="/me", tags=["me"])


@router.get("", response_model=UserOut)
async def get_me(user: CurrentUser) -> UserOut:
    return UserOut.model_validate(user)


@router.patch("", response_model=UserOut)
async def patch_me(body: UserPatch, user: CurrentUser, session: DbSession) -> UserOut:
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    await session.commit()
    return UserOut.model_validate(user)
