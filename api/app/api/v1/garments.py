import uuid
from datetime import UTC, datetime
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Request, Response
from redis.asyncio import Redis
from sqlalchemy import delete, func, select

from app.core.auth import CurrentUser, DbSession
from app.core.config import Settings, get_settings
from app.core.errors import ApiError
from app.core.ratelimit import hit
from app.core.redis import get_redis
from app.data.sample_closet import SAMPLE_GARMENTS
from app.domain.taxonomy import TAXONOMY_VERSION
from app.models import (
    AnalysisJob,
    AnalysisStatus,
    Availability,
    Garment,
    GarmentCorrection,
    GarmentImage,
    ImageStatus,
)
from app.queue.core import JobQueue
from app.queue.deps import get_queue
from app.schemas.closet import (
    BulkCreateIn,
    BulkCreateOut,
    CategoryCounts,
    ClosetSummary,
    CreateGarmentIn,
    EntitlementsOut,
    GarmentOut,
    GarmentPage,
    GarmentPatch,
    UploadTicketOut,
)
from app.services import closet as svc
from app.services.closet_query import SORTS, Filters, list_garments
from app.services.entitlements import ensure_can_add, get_entitlements
from app.services.images import sniff_content_type
from app.services.storage import ALLOWED_UPLOAD_TYPES, ObjectStorage, garment_prefix, get_storage

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


@router.get("/garments", response_model=GarmentPage)
async def list_closet(
    request: Request,
    user: CurrentUser,
    session: DbSession,
    settings: SettingsDep,
    storage: StorageDep,
    category: str | None = None,
    subcategory: str | None = None,
    color: str | None = None,
    season: str | None = None,
    formality_min: Annotated[int | None, Query(ge=1, le=5)] = None,
    formality_max: Annotated[int | None, Query(ge=1, le=5)] = None,
    q: Annotated[str | None, Query(max_length=80)] = None,
    favorite: bool | None = None,
    availability: Availability | None = None,
    archived: Literal["exclude", "only", "include"] = "exclude",
    analysis_status: AnalysisStatus | None = None,
    reviewed: bool | None = None,
    sort: Annotated[str, Query(pattern="^(" + "|".join(SORTS) + ")$")] = "created_desc",
    thumb: Literal["s", "m", "l"] = "m",
    limit: Annotated[int, Query(ge=1, le=100)] = 40,
    cursor: str | None = None,
) -> GarmentPage:
    """The closet grid. Filters combine with AND; ``q`` searches names, colours, brand and notes.
    Keyset pagination: pass ``next_cursor`` back as ``cursor`` (it is tied to the sort order)."""
    f = Filters(
        category,
        subcategory,
        color,
        season,
        formality_min,
        formality_max,
        q,
        favorite,
        availability,
        archived,
        analysis_status,
        reviewed,
    )
    rows, next_cursor, total = await list_garments(
        session, user.id, f, sort=sort, limit=limit, cursor=cursor
    )
    covers = await svc.covers_of(session, rows)
    items = [
        svc.list_item(g, covers.get(g.id), storage, _base(request), settings, thumb) for g in rows
    ]
    return GarmentPage(items=items, next_cursor=next_cursor, total=total)


def _counts(rows: list[tuple[str | None, str | None, int]]) -> CategoryCounts:
    by_cat: dict[str, int] = {}
    by_sub: dict[str, int] = {}
    for cat, sub, n in rows:
        if cat:
            by_cat[cat] = by_cat.get(cat, 0) + n
        if sub:
            by_sub[sub] = by_sub.get(sub, 0) + n
    return CategoryCounts(by_category=by_cat, by_subcategory=by_sub)


@router.get("/garments/summary", response_model=ClosetSummary)
async def closet_summary(user: CurrentUser, session: DbSession, redis: RedisDep) -> ClosetSummary:
    """Counts for the browse header and the completeness meter (cheap: aggregates only)."""

    async def grouped(*where: object) -> list[tuple[str | None, str | None, int]]:
        stmt = (
            select(Garment.category, Garment.subcategory, func.count())
            .where(Garment.user_id == user.id, *where)  # type: ignore[arg-type]
            .group_by(Garment.category, Garment.subcategory)
        )
        return [(c, s, n) for c, s, n in (await session.execute(stmt)).all()]

    live = Garment.archived_at.is_(None)
    all_live = await grouped(live)
    available = await grouped(live, Garment.availability == Availability.available)

    async def count(*where: object) -> int:
        stmt = select(func.count()).select_from(Garment).where(Garment.user_id == user.id, *where)  # type: ignore[arg-type]
        return (await session.execute(stmt)).scalar_one()

    ent = await get_entitlements(session, redis, user)
    return ClosetSummary(
        total=await count(live),
        archived=await count(Garment.archived_at.is_not(None)),
        favorites=await count(live, Garment.favorite.is_(True)),
        needs_review=await count(live, Garment.reviewed_at.is_(None), Garment.is_sample.is_(False)),
        counts=_counts(all_live),
        available_counts=_counts(available),
        closet_item_limit=ent.closet_item_limit,
        closet_items_used=ent.closet_items_used,
        closet_items_remaining=ent.remaining,
    )


@router.post("/garments/sample", response_model=list[GarmentOut], status_code=201)
async def seed_sample_closet(
    request: Request,
    response: Response,
    user: CurrentUser,
    session: DbSession,
    settings: SettingsDep,
    storage: StorageDep,
) -> list[GarmentOut]:
    """The guest "try it" closet: 16 ready-made garments whose pictures ship inside the app (no upload,
    no AI call, not counted against the item limit). Idempotent."""
    existing = (
        (
            await session.execute(
                select(Garment)
                .where(Garment.user_id == user.id, Garment.is_sample.is_(True))
                .order_by(Garment.created_at, Garment.id)
            )
        )
        .scalars()
        .all()
    )
    if existing:
        response.status_code = 200
        garments = list(existing)
    else:
        now = datetime.now(UTC)
        garments = []
        for spec in SAMPLE_GARMENTS:
            g = Garment(
                user_id=user.id,
                client_id=f"sample-{spec['asset']}",
                is_sample=True,
                sample_asset=spec["asset"],
                analysis_status=AnalysisStatus.done,
                reviewed_at=now,
                category=spec["category"],
                subcategory=spec["subcategory"],
                primary_color=spec["primary_color"],
                pattern=spec["pattern"],
                formality=spec["formality"],
                seasons=spec["seasons"],
                taxonomy_version=TAXONOMY_VERSION,
            )
            session.add(g)
            garments.append(g)
        await session.commit()
    return [svc.serialize(g, [], storage, _base(request), settings) for g in garments]


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


@router.patch("/garments/{garment_id}", response_model=GarmentOut)
async def patch_garment(
    garment_id: uuid.UUID,
    body: GarmentPatch,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    redis: RedisDep,
    settings: SettingsDep,
    storage: StorageDep,
) -> GarmentOut:
    """Edit any field. Changing a value the AI filled in is stored as a correction (feedback data)."""
    garment = await svc.get_owned_garment(session, user, garment_id)
    changes = body.model_dump(exclude_unset=True)
    unarchiving = changes.get("archived") is False and garment.archived_at is not None
    if unarchiving:
        ensure_can_add(await get_entitlements(session, redis, user))  # coming back counts again
    svc.apply_patch(session, garment, changes)
    await session.commit()
    imgs = (await svc.images_of(session, [garment.id]))[garment.id]
    return svc.serialize(garment, imgs, storage, _base(request), settings)


@router.post("/garments/{garment_id}/reanalyse", response_model=GarmentOut, status_code=202)
async def reanalyse(
    garment_id: uuid.UUID,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    redis: RedisDep,
    settings: SettingsDep,
    storage: StorageDep,
    queue: QueueDep,
) -> GarmentOut:
    """Ask the AI to look again (the only way an existing analysis is ever redone).

    Details the user has already edited are kept; only values that still match the previous AI answer
    are replaced. Rate limited per user per day."""
    garment = await svc.get_owned_garment(session, user, garment_id)
    imgs = (await svc.images_of(session, [garment.id]))[garment.id]
    ready = next((i for i in imgs if i.status == ImageStatus.ready), None)
    if ready is None:
        raise ApiError(409, "image_not_ready", "There is no processed photo to analyse yet.")
    if garment.analysis_status in (AnalysisStatus.processing, AnalysisStatus.analysing):
        raise ApiError(409, "analysis_in_progress", "Analysis is already running.")
    await hit(
        redis,
        bucket="reanalyse",
        user_id=user.id,
        limit=settings.reanalyse_daily_cap,
        window_seconds=86400,
    )
    garment.analysis_status = AnalysisStatus.analysing
    await session.commit()
    await queue.enqueue(
        "analyse_garment", str(garment.id), str(ready.id), "reanalyse",
        job_id=f"reanalyse-{ready.id}-{int(datetime.now(UTC).timestamp())}",
    )  # fmt: skip
    await session.refresh(garment)
    imgs = (await svc.images_of(session, [garment.id]))[garment.id]
    return svc.serialize(garment, imgs, storage, _base(request), settings)


@router.delete("/garments/{garment_id}", status_code=204)
async def delete_garment(
    garment_id: uuid.UUID, user: CurrentUser, session: DbSession, storage: StorageDep
) -> Response:
    """Permanently deletes the garment and every stored image of it (original, full size, thumbnails)."""
    garment = await svc.get_owned_garment(session, user, garment_id)
    try:
        await storage.delete_prefix(garment_prefix(garment.id))
    except Exception as exc:  # keep the row so the user can retry: never orphan images
        raise ApiError(
            503, "storage_unavailable", "Could not delete the photos. Please try again."
        ) from exc
    for model in (GarmentImage, GarmentCorrection, AnalysisJob):
        await session.execute(delete(model).where(model.garment_id == garment.id))
    await session.delete(garment)
    await session.commit()
    return Response(status_code=204)
