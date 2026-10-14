"""Background jobs for the closet: image processing and garment analysis.

Both are idempotent: they look at the database first, so a retry, a duplicate delivery or a re-enqueue
never repeats work or creates a second result.
"""

import asyncio
import hashlib
import logging
import time
import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.taxonomy import AI_FIELDS, TAXONOMY_VERSION
from app.models import (
    AnalysisJob,
    AnalysisStatus,
    Garment,
    GarmentImage,
    ImageStatus,
    JobStatus,
    User,
)
from app.queue.core import JobDeps, RetryJob, job
from app.services import images as imgs
from app.services.flags import get_flags
from app.services.storage import image_key
from app.vision.base import VisionError, validate_result

log = logging.getLogger("app.closet")
WEBP = "image/webp"


def _short(value: object) -> str:
    return hashlib.sha256(str(value).encode()).hexdigest()[:8]


# ---- process_image ------------------------------------------------------------------------------


async def _processing_dead(deps: JobDeps, args: tuple[Any, ...], error: str) -> None:
    async with deps.maker() as s:
        img = await s.get(GarmentImage, uuid.UUID(args[0]))
        if img is not None and img.status != ImageStatus.ready:
            img.status, img.error = ImageStatus.failed, error[:200]
            g = await s.get(Garment, img.garment_id)
            if g is not None and g.analysis_status in (
                AnalysisStatus.pending,
                AnalysisStatus.processing,
            ):
                g.analysis_status = AnalysisStatus.needs_manual
            await s.commit()


@job("process_image", on_dead=_processing_dead)
async def process_image(deps: JobDeps, image_id: str) -> None:
    started = time.perf_counter()
    async with deps.maker() as s:
        img = await s.get(GarmentImage, uuid.UUID(image_id))
        if img is None or img.status in (ImageStatus.ready, ImageStatus.failed):
            return  # deleted meanwhile, or already done: idempotent
        garment = await s.get(Garment, img.garment_id)
        if garment is None or img.raw_key is None:
            return
        if img.status == ImageStatus.awaiting_upload:
            raise RetryJob("upload not completed yet")
        img.status = ImageStatus.processing
        await s.commit()

        try:
            raw = await deps.storage.get(img.raw_key)
        except Exception as exc:
            raise RetryJob(f"storage read failed: {exc}") from exc
        if raw is None:
            await _fail_image(s, img, garment, "upload_missing", "The uploaded file is gone")
            return

        settings = deps.settings
        try:
            clean, source_type, oriented = await asyncio.to_thread(
                imgs.normalise,
                raw,
                max_pixels=settings.image_max_pixels,
                max_dimension=settings.image_max_dimension,
            )
            clean = await deps.remover.remove(clean)
            processed = await asyncio.to_thread(imgs.render, clean, source_type, oriented)
        except imgs.ImageRejected as exc:
            await _fail_image(s, img, garment, exc.code, exc.message)
            return

        keys = {
            "full": image_key(img.garment_id, img.id, "full.webp"),
            **{k: image_key(img.garment_id, img.id, f"thumb_{k}.webp") for k in processed.thumbs},
        }
        try:
            await deps.storage.put(keys["full"], processed.full, WEBP)
            for k, data in processed.thumbs.items():
                await deps.storage.put(keys[k], data, WEBP)
            await deps.storage.delete(
                img.raw_key
            )  # the raw upload (with its original metadata) goes away
        except Exception as exc:
            raise RetryJob(f"storage write failed: {exc}") from exc

        img.full_key, img.thumb_s_key, img.thumb_m_key, img.thumb_l_key = (
            keys["full"],
            keys["s"],
            keys["m"],
            keys["l"],
        )
        img.raw_key = None
        img.width, img.height, img.bytes = processed.width, processed.height, len(processed.full)
        img.content_type = WEBP
        img.sha256 = hashlib.sha256(raw).hexdigest()
        img.status, img.error = ImageStatus.ready, None
        img.processed_at = datetime.now(UTC)
        if garment.cover_image_id is None:
            garment.cover_image_id = img.id
        if garment.analysis_status in (AnalysisStatus.pending, AnalysisStatus.processing):
            garment.analysis_status = AnalysisStatus.analysing
        await s.commit()
        garment_id = str(garment.id)

    log.info(
        "image_processed image=%s ms=%d bytes_in=%d bytes_out=%d",
        image_id,
        (time.perf_counter() - started) * 1000,
        len(raw),
        len(processed.full),
    )
    await deps.queue.enqueue(
        "analyse_garment", garment_id, image_id, "analyse", job_id=f"analyse-{image_id}"
    )


async def _fail_image(
    s: AsyncSession, img: GarmentImage, g: Garment, code: str, message: str
) -> None:
    log.warning("image_rejected image=%s code=%s", img.id, code)
    img.status, img.error = ImageStatus.failed, f"{code}: {message}"[:200]
    g.analysis_status = AnalysisStatus.needs_manual
    await s.commit()


# ---- analyse_garment ------------------------------------------------------------------------------


async def _analysis_dead(deps: JobDeps, args: tuple[Any, ...], error: str) -> None:
    async with deps.maker() as s:
        g = await s.get(Garment, uuid.UUID(args[0]))
        if g is not None and g.analysis_status != AnalysisStatus.done:
            g.analysis_status = AnalysisStatus.needs_manual
        rows = (
            await s.execute(
                select(AnalysisJob).where(
                    AnalysisJob.garment_id == uuid.UUID(args[0]),
                    AnalysisJob.status.in_([JobStatus.queued, JobStatus.running]),
                )
            )
        ).scalars()
        for r in rows:
            r.status, r.error, r.finished_at = JobStatus.dead, error[:300], datetime.now(UTC)
        await s.commit()


async def used_today(s: AsyncSession, user_id: uuid.UUID) -> int:
    start = datetime.now(UTC).replace(hour=0, minute=0, second=0, microsecond=0)
    stmt = (
        select(func.count())
        .select_from(AnalysisJob)
        .where(
            AnalysisJob.user_id == user_id,
            AnalysisJob.created_at >= start,
            AnalysisJob.status.in_([JobStatus.running, JobStatus.succeeded]),
        )
    )
    return (await s.execute(stmt)).scalar_one()


def apply_ai_fields(
    g: Garment, fields: dict[str, dict[str, Any]], previous: dict[str, Any] | None
) -> None:
    """First analysis fills every field. A re-analysis only overwrites values the user has not edited
    (a field whose current value still equals what the AI said last time)."""
    for f in AI_FIELDS:
        new = fields[f]["value"]
        if previous is None or f not in previous or getattr(g, f) == previous[f]["value"]:
            setattr(g, f, new)


@job("analyse_garment", on_dead=_analysis_dead)
async def analyse_garment(
    deps: JobDeps, garment_id: str, image_id: str, kind: str = "analyse"
) -> None:
    gid, iid = uuid.UUID(garment_id), uuid.UUID(image_id)
    async with deps.maker() as s:
        g = await s.get(Garment, gid)
        img = await s.get(GarmentImage, iid)
        if g is None or img is None:
            return  # deleted while queued
        if kind == "analyse" and g.analysis_status == AnalysisStatus.done and g.ai_fields:
            return  # never re-analyse unless the user asks (kind == "reanalyse")
        if img.status == ImageStatus.failed:
            g.analysis_status = AnalysisStatus.needs_manual
            await s.commit()
            return
        if img.status != ImageStatus.ready or not img.full_key:
            raise RetryJob("image not ready yet")

        if await used_today(s, g.user_id) >= deps.settings.vision_daily_cap:
            g.analysis_status = AnalysisStatus.needs_manual
            s.add(
                AnalysisJob(
                    garment_id=gid,
                    user_id=g.user_id,
                    image_id=iid,
                    kind=kind,
                    status=JobStatus.failed,
                    error="usage_cap_reached",
                    finished_at=datetime.now(UTC),
                )
            )
            await s.commit()
            log.warning("vision_cap_reached user=%s", _short(g.user_id))
            return

        user = await s.get(User, g.user_id)
        department = user.clothing_department.value if user and user.clothing_department else None
        flags = await get_flags(s, deps.redis())
        provider_name = str(flags["vision_provider"])
        row = AnalysisJob(
            garment_id=gid,
            user_id=g.user_id,
            image_id=iid,
            kind=kind,
            status=JobStatus.running,
            attempts=1,
            provider=provider_name,
        )
        s.add(row)
        await s.commit()
        image_bytes = await deps.storage.get(img.full_key)
        if image_bytes is None:
            raise RetryJob("processed image missing from storage")
        hint = img.source_name

        provider = deps.vision(provider_name)
        try:
            result = await provider.analyse(
                image_bytes, media_type=WEBP, hint=hint, department=department
            )
            fields = validate_result(result.fields)
        except VisionError as exc:
            row.status, row.error, row.finished_at = (
                JobStatus.failed,
                str(exc)[:300],
                datetime.now(UTC),
            )
            await s.commit()
            if exc.retryable:
                raise RetryJob(str(exc)) from exc
            raise

        previous = g.ai_fields if kind == "reanalyse" else None
        apply_ai_fields(g, fields, previous)
        g.ai_fields = fields
        g.analysis_status = AnalysisStatus.done
        g.analysis_provider, g.analysis_model, g.analysis_version = (
            result.provider,
            result.model,
            result.version,
        )
        g.taxonomy_version = TAXONOMY_VERSION
        row.status, row.model, row.finished_at = (
            JobStatus.succeeded,
            result.model,
            datetime.now(UTC),
        )
        row.latency_ms = result.latency_ms
        row.input_tokens, row.output_tokens = result.usage.input_tokens, result.usage.output_tokens
        row.cost_usd = result.usage.cost_usd
        await s.commit()
        # One cost line per vision call (grep "vision_call" to total spend).
        log.info(
            "vision_call provider=%s model=%s in_tokens=%d out_tokens=%d cost_usd=%s latency_ms=%d user=%s kind=%s",
            result.provider,
            result.model,
            result.usage.input_tokens,
            result.usage.output_tokens,
            "unknown" if result.usage.cost_usd is None else f"{result.usage.cost_usd:.6f}",
            result.latency_ms,
            _short(g.user_id),
            kind,
        )
