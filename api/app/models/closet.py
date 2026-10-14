import enum
import uuid
from datetime import date, datetime
from typing import Any

from sqlalchemy import (
    Boolean,
    Date,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, JsonType, UtcDateTime, utcnow


def _enum[E: enum.StrEnum](cls: type[E]) -> Enum:
    return Enum(cls, native_enum=False, length=24, values_callable=lambda e: [m.value for m in e])


class Availability(enum.StrEnum):
    available = "available"
    laundry = "laundry"
    lent = "lent"
    repair = "repair"


class AnalysisStatus(enum.StrEnum):
    pending = "pending"  # created, no photo uploaded yet
    processing = "processing"  # photo uploaded, image pipeline running
    analysing = "analysing"  # waiting for / running the vision model
    done = "done"
    needs_manual = "needs_manual"  # analysis failed or capped: the user types the details


class ImageStatus(enum.StrEnum):
    awaiting_upload = "awaiting_upload"
    uploaded = "uploaded"
    processing = "processing"
    ready = "ready"
    failed = "failed"


class JobStatus(enum.StrEnum):
    queued = "queued"
    running = "running"
    succeeded = "succeeded"
    failed = "failed"
    dead = "dead"


class Garment(Base):
    __tablename__ = "garments"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="uq_garments_user_client"),
        Index("ix_garments_user_category", "user_id", "category"),
        Index("ix_garments_user_color", "user_id", "primary_color"),
        Index("ix_garments_user_created", "user_id", "created_at", "id"),
        Index("ix_garments_user_updated", "user_id", "updated_at", "id"),
        Index("ix_garments_user_formality", "user_id", "formality", "id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    client_id: Mapped[str] = mapped_column(String(64))  # app-generated; makes creation idempotent

    category: Mapped[str | None] = mapped_column(String(24))
    subcategory: Mapped[str | None] = mapped_column(String(32))
    primary_color: Mapped[str | None] = mapped_column(String(24))
    secondary_color: Mapped[str | None] = mapped_column(String(24))
    pattern: Mapped[str | None] = mapped_column(String(24))
    formality: Mapped[int | None] = mapped_column(Integer)
    seasons: Mapped[list[str] | None] = mapped_column(JsonType)
    fit: Mapped[str | None] = mapped_column(String(24))
    material: Mapped[str | None] = mapped_column(String(24))
    brand: Mapped[str | None] = mapped_column(String(60))
    notes: Mapped[str | None] = mapped_column(String(500))

    favorite: Mapped[bool] = mapped_column(Boolean, default=False)
    availability: Mapped[Availability] = mapped_column(
        _enum(Availability), default=Availability.available
    )
    unavailable_until: Mapped[date | None] = mapped_column(Date)
    archived_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    reviewed_at: Mapped[datetime | None] = mapped_column(UtcDateTime)

    analysis_status: Mapped[AnalysisStatus] = mapped_column(
        _enum(AnalysisStatus), default=AnalysisStatus.pending
    )
    # {field: {"value": ..., "confidence": 0..1}} exactly as the model returned it (post-validation).
    ai_fields: Mapped[dict[str, Any] | None] = mapped_column(JsonType)
    analysis_provider: Mapped[str | None] = mapped_column(String(32))
    analysis_model: Mapped[str | None] = mapped_column(String(64))
    analysis_version: Mapped[str | None] = mapped_column(String(32))
    taxonomy_version: Mapped[int] = mapped_column(Integer, default=1)

    is_sample: Mapped[bool] = mapped_column(Boolean, default=False)
    sample_asset: Mapped[str | None] = mapped_column(String(64))
    cover_image_id: Mapped[uuid.UUID | None] = mapped_column()

    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow, onupdate=utcnow)


class GarmentImage(Base):
    __tablename__ = "garment_images"
    __table_args__ = (Index("ix_garment_images_garment", "garment_id"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    garment_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("garments.id", ondelete="CASCADE"))
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    status: Mapped[ImageStatus] = mapped_column(
        _enum(ImageStatus), default=ImageStatus.awaiting_upload
    )
    raw_key: Mapped[str | None] = mapped_column(String(200))
    full_key: Mapped[str | None] = mapped_column(String(200))
    thumb_s_key: Mapped[str | None] = mapped_column(String(200))
    thumb_m_key: Mapped[str | None] = mapped_column(String(200))
    thumb_l_key: Mapped[str | None] = mapped_column(String(200))
    width: Mapped[int | None] = mapped_column(Integer)
    height: Mapped[int | None] = mapped_column(Integer)
    bytes: Mapped[int | None] = mapped_column(Integer)
    content_type: Mapped[str | None] = mapped_column(String(48))
    source_name: Mapped[str | None] = mapped_column(
        String(120)
    )  # sanitised client filename (hint for the fake vision provider)
    sha256: Mapped[str | None] = mapped_column(String(64))
    error: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    uploaded_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    processed_at: Mapped[datetime | None] = mapped_column(UtcDateTime)


class GarmentCorrection(Base):
    """Every time a user changes a value the AI filled in: ground truth for evaluating the model."""

    __tablename__ = "garment_corrections"
    __table_args__ = (Index("ix_garment_corrections_garment", "garment_id"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    garment_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("garments.id", ondelete="CASCADE"))
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    field: Mapped[str] = mapped_column(String(24))
    ai_value: Mapped[Any] = mapped_column(JsonType)
    user_value: Mapped[Any] = mapped_column(JsonType)
    taxonomy_version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)


class AnalysisJob(Base):
    __tablename__ = "analysis_jobs"
    __table_args__ = (Index("ix_analysis_jobs_user_created", "user_id", "created_at"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    garment_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("garments.id", ondelete="CASCADE"))
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    image_id: Mapped[uuid.UUID | None] = mapped_column()
    kind: Mapped[str] = mapped_column(String(16), default="analyse")  # analyse | reanalyse
    status: Mapped[JobStatus] = mapped_column(_enum(JobStatus), default=JobStatus.queued)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    provider: Mapped[str | None] = mapped_column(String(32))
    model: Mapped[str | None] = mapped_column(String(64))
    latency_ms: Mapped[int | None] = mapped_column(Integer)
    input_tokens: Mapped[int | None] = mapped_column(Integer)
    output_tokens: Mapped[int | None] = mapped_column(Integer)
    cost_usd: Mapped[float | None] = mapped_column(Float)
    error: Mapped[str | None] = mapped_column(String(300))
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, default=utcnow)
    finished_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
