import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models import ClothingDepartment, Units, UserStatus


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str | None
    display_name: str | None
    is_anonymous: bool
    locale: str
    units: Units
    city: str | None
    clothing_department: ClothingDepartment | None
    age_confirmed_at: datetime | None
    daily_outfit_time: str | None
    status: UserStatus
    created_at: datetime


class UserPatch(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=100)
    units: Units | None = None
    city: str | None = Field(default=None, max_length=120)
    clothing_department: ClothingDepartment | None = None
    locale: str | None = Field(default=None, max_length=16)
    daily_outfit_time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")


class SessionRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=128)
    platform: str = Field(max_length=16)
    app_version: str = Field(max_length=32)


class SessionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    device_id: str
    platform: str
    app_version: str
    created_at: datetime
    last_seen_at: datetime
    revoked_at: datetime | None


class AuthSessionResponse(BaseModel):
    user: UserOut
    session: SessionOut
    is_new_user: bool


class UpgradeRequest(BaseModel):
    """After the client links Google to the anonymous account the UID is unchanged.

    If linking failed because the Google account already exists, the client signs in to it and
    passes the guest's ID token here so data can be merged.
    """

    merge_from_token: str | None = None
