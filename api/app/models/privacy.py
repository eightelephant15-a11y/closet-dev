import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, UtcDateTime, register_mergeable, utcnow


@register_mergeable
class Consents(Base):
    __tablename__ = "consents"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    # None = not decided yet (no analytics until the user opts in)
    analytics_opt_in: Mapped[bool | None] = mapped_column(Boolean)
    analytics_updated_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    # ON by default: photos are never used to train models unless the user turns this off
    no_ai_training: Mapped[bool] = mapped_column(Boolean, default=True)
    ai_training_updated_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    location_explained_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    policy_version: Mapped[str] = mapped_column(String(32))


class ExportStatus(enum.StrEnum):
    pending = "pending"
    completed = "completed"
    failed = "failed"


class ExportJob(Base):
    __tablename__ = "export_jobs"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    status: Mapped[ExportStatus] = mapped_column(
        Enum(
            ExportStatus,
            native_enum=False,
            length=16,
            values_callable=lambda e: [m.value for m in e],
        ),
        default=ExportStatus.pending,
    )
    file_key: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    expires_at: Mapped[datetime | None] = mapped_column(UtcDateTime)


class AuditLog(Base):
    """Evidence that deletion/export happened, without keeping personal data."""

    __tablename__ = "audit_log"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    event: Mapped[str] = mapped_column(String(64))
    user_ref: Mapped[str] = mapped_column(String(64))  # sha256 of the user id
    at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
