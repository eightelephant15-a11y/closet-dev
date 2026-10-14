"""Closet service layer: ownership, serialisation (with signed URLs) and creation."""

import re
import uuid
from datetime import UTC, datetime
from pathlib import PurePosixPath
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.errors import ApiError
from app.domain.taxonomy import AI_FIELDS, TAXONOMY_VERSION
from app.models import (
    AnalysisStatus,
    Availability,
    Garment,
    GarmentImage,
    ImageStatus,
    User,
)
from app.schemas.closet import (
    AnalysisOut,
    CreateGarmentIn,
    FieldValue,
    GarmentOut,
    ImageOut,
    ImageUrls,
    UploadTicketOut,
)
from app.services.storage import ObjectStorage, image_key

LOW_CONFIDENCE = 0.7
BULK_MAX = 20
_SAFE = re.compile(r"[^A-Za-z0-9._ -]")


def sanitize_filename(name: str | None) -> str | None:
    """Keeps a harmless display/hint name: no path, no control characters, bounded length."""
    if not name:
        return None
    base = PurePosixPath(name.replace("\\", "/")).name
    base = _SAFE.sub("", base).strip(" .")[:120]
    return base or None


def not_found() -> ApiError:
    # Same answer for "doesn't exist" and "belongs to someone else": no existence leak.
    return ApiError(404, "garment_not_found", "Garment not found")


async def get_owned_garment(session: AsyncSession, user: User, garment_id: uuid.UUID) -> Garment:
    g = (
        await session.execute(
            select(Garment).where(Garment.id == garment_id, Garment.user_id == user.id)
        )
    ).scalar_one_or_none()
    if g is None:
        raise not_found()
    return g


async def get_owned_image(
    session: AsyncSession, user: User, garment_id: uuid.UUID, image_id: uuid.UUID
) -> tuple[Garment, GarmentImage]:
    garment = await get_owned_garment(session, user, garment_id)
    img = (
        await session.execute(
            select(GarmentImage).where(
                GarmentImage.id == image_id,
                GarmentImage.garment_id == garment.id,
                GarmentImage.user_id == user.id,
            )
        )
    ).scalar_one_or_none()
    if img is None:
        raise not_found()
    return garment, img


async def images_of(
    session: AsyncSession, garment_ids: list[uuid.UUID]
) -> dict[uuid.UUID, list[GarmentImage]]:
    out: dict[uuid.UUID, list[GarmentImage]] = {gid: [] for gid in garment_ids}
    if not garment_ids:
        return out
    rows = (
        await session.execute(
            select(GarmentImage)
            .where(GarmentImage.garment_id.in_(garment_ids))
            .order_by(GarmentImage.created_at, GarmentImage.id)
        )
    ).scalars()
    for r in rows:
        out[r.garment_id].append(r)
    return out


def is_excluded(g: Garment) -> bool:
    return g.archived_at is not None or g.availability != Availability.available


def low_confidence_fields(ai_fields: dict[str, Any] | None) -> list[str]:
    if not ai_fields:
        return []
    return [f for f in AI_FIELDS if f in ai_fields and ai_fields[f]["confidence"] < LOW_CONFIDENCE]


def image_urls(img: GarmentImage, storage: ObjectStorage, base_url: str, ttl: int) -> ImageUrls:
    def sign(key: str | None) -> str | None:
        return storage.create_read_url(key, expires_in=ttl, base_url=base_url) if key else None

    if img.status != ImageStatus.ready:
        return ImageUrls()
    return ImageUrls(
        s=sign(img.thumb_s_key),
        m=sign(img.thumb_m_key),
        l=sign(img.thumb_l_key),
        full=sign(img.full_key),
    )


def serialize(
    g: Garment,
    images: list[GarmentImage],
    storage: ObjectStorage,
    base_url: str,
    settings: Settings,
    *,
    upload: UploadTicketOut | None = None,
) -> GarmentOut:
    ai = g.ai_fields
    return GarmentOut(
        id=g.id,
        client_id=g.client_id,
        category=g.category,
        subcategory=g.subcategory,
        primary_color=g.primary_color,
        secondary_color=g.secondary_color,
        pattern=g.pattern,
        formality=g.formality,
        seasons=g.seasons,
        fit=g.fit,
        material=g.material,
        brand=g.brand,
        notes=g.notes,
        favorite=g.favorite,
        availability=g.availability,
        unavailable_until=g.unavailable_until,
        archived=g.archived_at is not None,
        reviewed=g.reviewed_at is not None,
        excluded_from_outfits=is_excluded(g),
        is_sample=g.is_sample,
        sample_asset=g.sample_asset,
        analysis=AnalysisOut(
            status=g.analysis_status,
            fields={k: FieldValue(**v) for k, v in ai.items()} if ai else None,
            low_confidence_fields=low_confidence_fields(ai),
            provider=g.analysis_provider,
            model=g.analysis_model,
            version=g.analysis_version,
            taxonomy_version=g.taxonomy_version,
        ),
        images=[
            ImageOut(
                id=i.id,
                status=i.status,
                width=i.width,
                height=i.height,
                urls=image_urls(i, storage, base_url, settings.read_url_ttl_seconds),
                error=i.error,
            )
            for i in images
        ],
        cover_image_id=g.cover_image_id,
        created_at=g.created_at,
        updated_at=g.updated_at,
        upload=upload,
    )


def make_ticket(
    img: GarmentImage, storage: ObjectStorage, settings: Settings, base_url: str, content_type: str
) -> UploadTicketOut:
    assert img.raw_key  # noqa: S101
    t = storage.create_upload_ticket(
        img.raw_key,
        content_type=content_type,
        max_bytes=settings.upload_max_bytes,
        expires_in=settings.upload_url_ttl_seconds,
        base_url=base_url,
    )
    return UploadTicketOut(
        image_id=img.id,
        url=t.url,
        method=t.method,
        headers=t.headers,
        fields=t.fields,
        expires_at=t.expires_at,
        max_bytes=t.max_bytes,
    )


def new_garment(
    user: User, body: CreateGarmentIn, settings: Settings
) -> tuple[Garment, GarmentImage]:
    if body.size_bytes is not None and body.size_bytes > settings.upload_max_bytes:
        raise ApiError(
            413,
            "file_too_large",
            "That photo is too large.",
            {"max_bytes": settings.upload_max_bytes},
        )
    gid, iid = uuid.uuid4(), uuid.uuid4()
    now = datetime.now(UTC)
    garment = Garment(
        id=gid,
        user_id=user.id,
        client_id=body.client_id,
        analysis_status=AnalysisStatus.pending,
        taxonomy_version=TAXONOMY_VERSION,
        created_at=now,
        updated_at=now,
    )
    image = GarmentImage(
        id=iid,
        garment_id=gid,
        user_id=user.id,
        status=ImageStatus.awaiting_upload,
        raw_key=image_key(gid, iid, "raw"),
        source_name=sanitize_filename(body.filename),
        content_type=body.content_type,
    )
    return garment, image
