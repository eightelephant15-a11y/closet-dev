import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Request, Response
from redis.asyncio import Redis
from sqlalchemy import select

from app.core.auth import CurrentUser, DbSession
from app.core.config import Settings, get_settings
from app.core.errors import ApiError
from app.core.ratelimit import hit
from app.core.redis import get_redis
from app.models import AnalysisStatus, Garment, GarmentImage, ImageStatus
from app.queue.core import JobQueue
from app.queue.deps import get_queue
from app.schemas.closet import (
    BulkCreateIn,
    BulkCreateOut,
    CreateGarmentIn,
    EntitlementsOut,
    GarmentOut,
    UploadTicketOut,
)
from app.services import closet as svc
from app.services.entitlements import ensure_can_add, get_entitlements
from app.services.images import sniff_content_type
from app.services.storage import ALLOWED_UPLOAD_TYPES, ObjectStorage, get_storage

router = APIRouter(tags=["closet"])

SettingsDep = Annotated[Settings, Depends(get_settings)]
RedisDep = Annotated[Redis, Depends(get_redis)]
StorageDep = Annotated[ObjectStorage, Depends(get_storage)]
QueueDep = Annotated[JobQueue, Depends(get_queue)]


def _base(request: Request) -> str:
    return str(request.base_url).rstrip("/")


@router.get("/entitlements", response_model=EntitlementsOut)
async def entitlements(user: CurrentUser, session: DbSession, redis: RedisDep) -> EntitlementsOut:
    ent = await get_entitlements(session, redis, user)
    return EntitlementsOut(
        plan=ent.plan,
        closet_item_limit=ent.closet_item_limit,
        closet_items_used=ent.closet_items_used,
        closet_items_remaining=ent.remaining,
        bulk_add_enabled=ent.bulk_add_enabled,
        bulk_max=svc.BULK_MAX,
    )


async def _existing(session: DbSession, user_id: uuid.UUID, client_id: str) -> Garment | None:
    return (
        await session.execute(
            select(Garment).where(Garment.user_id == user_id, Garment.client_id == client_id)
        )
    ).scalar_one_or_none()


@router.post("/garments", response_model=GarmentOut, status_code=201)
async def create_garment(
    body: CreateGarmentIn,
    request: Request,
    response: Response,
    user: CurrentUser,
    session: DbSession,
    redis: RedisDep,
    settings: SettingsDep,
    storage: StorageDep,
) -> GarmentOut:
    """Creates a garment and hands back the signed URL to upload its photo to.

    Idempotent on ``client_id``: a retry after a lost response returns the same garment (and a fresh
    upload URL while the photo has not arrived), never a duplicate.
    """
    await hit(
        redis,
        bucket="garment_create",
        user_id=user.id,
        limit=settings.upload_rate_per_hour,
        window_seconds=3600,
    )
    existing = await _existing(session, user.id, body.client_id)
    if existing is not None:
        response.status_code = 200
        imgs = (await svc.images_of(session, [existing.id]))[existing.id]
        waiting = next((i for i in imgs if i.status == ImageStatus.awaiting_upload), None)
        ticket = (
            svc.make_ticket(
                waiting, storage, settings, _base(request), waiting.content_type or "image/jpeg"
            )
            if waiting
            else None
        )
        return svc.serialize(existing, imgs, storage, _base(request), settings, upload=ticket)

    ensure_can_add(await get_entitlements(session, redis, user))
    garment, image = svc.new_garment(user, body, settings)
    session.add(garment)
    await session.flush()  # the garment row must exist before the image that references it
    session.add(image)
    await session.commit()
    ticket = svc.make_ticket(image, storage, settings, _base(request), body.content_type)
    return svc.serialize(garment, [image], storage, _base(request), settings, upload=ticket)


@router.post("/garments/bulk", response_model=BulkCreateOut, status_code=201)
async def create_garments_bulk(
    body: BulkCreateIn,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    redis: RedisDep,
    settings: SettingsDep,
    storage: StorageDep,
) -> BulkCreateOut:
    """Up to 20 garments at once (the multi-select flow). All or nothing against the item limit."""
    ent = await get_entitlements(session, redis, user)
    if not ent.bulk_add_enabled:
        raise ApiError(
            403, "bulk_disabled", "Adding several items at once is not available right now."
        )
    if len(body.items) > svc.BULK_MAX:
        raise ApiError(
            422,
            "bulk_too_large",
            f"Add at most {svc.BULK_MAX} items at a time.",
            {"max": svc.BULK_MAX},
        )
    await hit(
        redis,
        bucket="garment_create",
        user_id=user.id,
        limit=settings.upload_rate_per_hour,
        window_seconds=3600,
        cost=len(body.items),
    )

    out: list[GarmentOut] = []
    fresh: list[tuple[Garment, GarmentImage, str]] = []
    seen: set[str] = set()
    for item in body.items:
        if item.client_id in seen:
            raise ApiError(422, "duplicate_client_id", "Each item needs a unique client_id")
        seen.add(item.client_id)
    new_items = []
    existing_by_id: dict[str, Garment] = {}
    for item in body.items:
        found = await _existing(session, user.id, item.client_id)
        if found is not None:
            existing_by_id[item.client_id] = found
        else:
            new_items.append(item)
    ensure_can_add(ent, len(new_items))  # retries of already-created items never count twice

    for item in new_items:
        garment, image = svc.new_garment(user, item, settings)
        session.add(garment)
        await session.flush()
        session.add(image)
        fresh.append((garment, image, item.content_type))
    await session.commit()

    fresh_by_client = {g.client_id: (g, i, ct) for g, i, ct in fresh}
    for item in body.items:
        if item.client_id in fresh_by_client:
            g, i, ct = fresh_by_client[item.client_id]
            new_ticket = svc.make_ticket(i, storage, settings, _base(request), ct)
            out.append(svc.serialize(g, [i], storage, _base(request), settings, upload=new_ticket))
        else:
            g = existing_by_id[item.client_id]
            imgs = (await svc.images_of(session, [g.id]))[g.id]
            waiting = next((i for i in imgs if i.status == ImageStatus.awaiting_upload), None)
            ticket = (
                svc.make_ticket(
                    waiting, storage, settings, _base(request), waiting.content_type or "image/jpeg"
                )
                if waiting
                else None
            )
            out.append(svc.serialize(g, imgs, storage, _base(request), settings, upload=ticket))
    ent_after = await get_entitlements(session, redis, user)
    return BulkCreateOut(items=out, remaining=ent_after.remaining)


@router.post("/garments/{garment_id}/images/{image_id}/upload-url", response_model=UploadTicketOut)
async def new_upload_url(
    garment_id: uuid.UUID,
    image_id: uuid.UUID,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    redis: RedisDep,
    settings: SettingsDep,
    storage: StorageDep,
) -> UploadTicketOut:
    """A fresh signed URL (the first one expires after 15 minutes; a queued upload may outlive it)."""
    _, img = await svc.get_owned_image(session, user, garment_id, image_id)
    if img.status != ImageStatus.awaiting_upload:
        raise ApiError(409, "upload_already_completed", "This photo was already uploaded")
    await hit(
        redis,
        bucket="upload_ticket",
        user_id=user.id,
        limit=settings.upload_rate_per_hour * 2,
        window_seconds=3600,
    )
    return svc.make_ticket(img, storage, settings, _base(request), img.content_type or "image/jpeg")


@router.post(
    "/garments/{garment_id}/images/{image_id}/complete", response_model=GarmentOut, status_code=202
)
async def complete_upload(
    garment_id: uuid.UUID,
    image_id: uuid.UUID,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    settings: SettingsDep,
    storage: StorageDep,
    queue: QueueDep,
) -> GarmentOut:
    """The phone says "the upload finished". We check the object really is a supported image of an
    acceptable size (by content, not by what the client claims), then queue processing. Idempotent."""
    garment, img = await svc.get_owned_image(session, user, garment_id, image_id)
    if img.status == ImageStatus.awaiting_upload:
        assert img.raw_key  # noqa: S101
        info = await storage.head(img.raw_key)
        if info is None:
            raise ApiError(
                409, "upload_missing", "We haven't received the photo yet. Please retry the upload."
            )
        if info.size > settings.upload_max_bytes:
            await storage.delete(img.raw_key)
            raise ApiError(
                413,
                "file_too_large",
                "That photo is too large.",
                {"max_bytes": settings.upload_max_bytes},
            )
        head = await storage.get_head(img.raw_key, 32) or b""
        sniffed = sniff_content_type(head)
        if sniffed is None or sniffed not in {*ALLOWED_UPLOAD_TYPES, "image/heic"}:
            await storage.delete(img.raw_key)
            img.status, img.error = ImageStatus.failed, "unsupported_media: not a supported image"
            garment.analysis_status = AnalysisStatus.needs_manual
            await session.commit()
            raise ApiError(
                415, "unsupported_media", "Only JPEG, PNG, WebP and HEIC photos are supported."
            )
        img.status, img.bytes, img.content_type = ImageStatus.uploaded, info.size, sniffed
        img.uploaded_at = datetime.now(UTC)
        garment.analysis_status = AnalysisStatus.processing
        await session.commit()
        await queue.enqueue("process_image", str(img.id), job_id=f"process-{img.id}")
        await session.refresh(garment)
        await session.refresh(img)
    imgs = (await svc.images_of(session, [garment.id]))[garment.id]
    return svc.serialize(garment, imgs, storage, _base(request), settings)


@router.get("/garments/{garment_id}", response_model=GarmentOut)
async def get_garment(
    garment_id: uuid.UUID,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    settings: SettingsDep,
    storage: StorageDep,
) -> GarmentOut:
    garment = await svc.get_owned_garment(session, user, garment_id)
    imgs = (await svc.images_of(session, [garment.id]))[garment.id]
    return svc.serialize(garment, imgs, storage, _base(request), settings)
