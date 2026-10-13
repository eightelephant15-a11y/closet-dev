import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, JsonType, UtcDateTime, utcnow


class UserStatus(enum.StrEnum):
    active = "active"
    pending_deletion = "pending_deletion"
    deleted = "deleted"


class Units(enum.StrEnum):
    imperial = "imperial"
    metric = "metric"


class ClothingDepartment(enum.StrEnum):
    menswear = "menswear"
    womenswear = "womenswear"
    both = "both"
    everything = "everything"


def _enum[E: enum.StrEnum](cls: type[E]) -> Enum:
    return Enum(cls, native_enum=False, length=32, values_callable=lambda e: [m.value for m in e])


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    auth_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(320))
    display_name: Mapped[str | None] = mapped_column(String(100))
    is_anonymous: Mapped[bool] = mapped_column(Boolean, default=True)
    locale: Mapped[str] = mapped_column(String(16), default="en-US")
    units: Mapped[Units] = mapped_column(_enum(Units), default=Units.imperial)
    city: Mapped[str | None] = mapped_column(String(120))
    clothing_department: Mapped[ClothingDepartment | None] = mapped_column(
        _enum(ClothingDepartment)
    )
    age_confirmed_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    daily_outfit_time: Mapped[str | None] = mapped_column(String(5))  # local "HH:MM"
    status: Mapped[UserStatus] = mapped_column(_enum(UserStatus), default=UserStatus.active)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow, onupdate=utcnow)
    deleted_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    purge_after: Mapped[datetime | None] = mapped_column(UtcDateTime)


class DeviceSession(Base):
    __tablename__ = "device_sessions"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    device_id: Mapped[str] = mapped_column(String(128))
    platform: Mapped[str] = mapped_column(String(16))
    app_version: Mapped[str] = mapped_column(String(32))
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    revoked_at: Mapped[datetime | None] = mapped_column(UtcDateTime)


class FeatureFlag(Base):
    __tablename__ = "feature_flags"

    key: Mapped[str] = mapped_column(String(100), primary_key=True)
    value: Mapped[object] = mapped_column(JsonType)
    updated_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow, onupdate=utcnow)
