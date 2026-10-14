import uuid
from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.models import AnalysisStatus, Availability, ImageStatus

UploadContentType = Literal["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"]


class UploadTicketOut(BaseModel):
    """Where and how to upload one image. ``method`` is PUT (local) or POST with form ``fields`` (S3)."""

    image_id: uuid.UUID
    url: str
    method: Literal["PUT", "POST"]
    headers: dict[str, str]
    fields: dict[str, str]
    expires_at: int
    max_bytes: int


class CreateGarmentIn(BaseModel):
    client_id: str = Field(min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")
    filename: str | None = Field(default=None, max_length=200)
    content_type: UploadContentType = "image/jpeg"
    size_bytes: int | None = Field(default=None, ge=1)


class BulkCreateIn(BaseModel):
    items: list[CreateGarmentIn] = Field(min_length=1, max_length=50)


class ImageUrls(BaseModel):
    s: str | None = None
    m: str | None = None
    l: str | None = None  # noqa: E741
    full: str | None = None


class ImageOut(BaseModel):
    id: uuid.UUID
    status: ImageStatus
    width: int | None
    height: int | None
    urls: ImageUrls
    error: str | None = None


class FieldValue(BaseModel):
    value: Any
    confidence: float


class AnalysisOut(BaseModel):
    status: AnalysisStatus
    fields: dict[str, FieldValue] | None = None
    low_confidence_fields: list[str] = []
    provider: str | None = None
    model: str | None = None
    version: str | None = None
    taxonomy_version: int


class GarmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    client_id: str
    category: str | None
    subcategory: str | None
    primary_color: str | None
    secondary_color: str | None
    pattern: str | None
    formality: int | None
    seasons: list[str] | None
    fit: str | None
    material: str | None
    brand: str | None
    notes: str | None
    favorite: bool
    availability: Availability
    unavailable_until: date | None
    archived: bool
    reviewed: bool
    # Phase 3 must not suggest these: laundry/lent/repair or archived.
    excluded_from_outfits: bool
    is_sample: bool
    sample_asset: str | None
    analysis: AnalysisOut
    images: list[ImageOut]
    cover_image_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime
    upload: UploadTicketOut | None = None


class BulkCreateOut(BaseModel):
    items: list[GarmentOut]
    remaining: int


class CompleteUploadIn(BaseModel):
    pass


class EntitlementsOut(BaseModel):
    plan: str
    closet_item_limit: int
    closet_items_used: int
    closet_items_remaining: int
    bulk_add_enabled: bool
    bulk_max: int
