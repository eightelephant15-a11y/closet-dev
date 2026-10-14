import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.auth import CurrentUser, DbSession, PendingOkUser, TokenVerifier, get_verifier
from app.core.db import get_sessionmaker
from app.core.errors import ApiError
from app.models import ExportJob, ExportStatus, User
from app.schemas.privacy import ConsentOut, ConsentPut, DeletionOut, ExportOut
from app.services import privacy
from app.services.storage import ExportStorage, get_storage

router = APIRouter(tags=["privacy"])


@router.get("/me/consents", response_model=ConsentOut)
async def get_consents(user: CurrentUser, session: DbSession) -> ConsentOut:
    return ConsentOut.model_validate(await privacy.get_consents(session, user))


@router.put("/me/consents", response_model=ConsentOut)
async def put_consents(body: ConsentPut, user: CurrentUser, session: DbSession) -> ConsentOut:
    row = await privacy.update_consents(
        session,
        user,
        analytics_opt_in=body.analytics_opt_in,
        no_ai_training=body.no_ai_training,
        location_explained=body.location_explained,
    )
    return ConsentOut.model_validate(row)


# ---- export -----------------------------------------------------------------------------


def _out(job: ExportJob) -> ExportOut:
    out = ExportOut.model_validate(job)
    if job.status == ExportStatus.completed:
        out.download_url = f"/v1/me/export/{job.id}/download"
    return out


@router.post("/me/export", response_model=ExportOut, status_code=202)
async def request_export(
    user: CurrentUser,
    session: DbSession,
    background: BackgroundTasks,
    maker: Annotated[async_sessionmaker[AsyncSession], Depends(get_sessionmaker)],
    storage: Annotated[ExportStorage, Depends(get_storage)],
) -> ExportOut:
    job = await privacy.create_export_job(session, user)

    async def run() -> None:
        # Own session: the request session is closed by the time background tasks run.
        async with maker() as bg_session:
            await privacy.run_export_job(bg_session, storage, job.id)

    background.add_task(run)
    return _out(job)


async def _owned_job(session: AsyncSession, user: User, job_id: uuid.UUID) -> ExportJob:
    job = await session.get(ExportJob, job_id)
    if job is None or job.user_id != user.id:
        raise ApiError(404, "export_not_found", "Export not found")
    return job


@router.get("/me/export/{job_id}", response_model=ExportOut)
async def export_status(job_id: uuid.UUID, user: CurrentUser, session: DbSession) -> ExportOut:
    return _out(await _owned_job(session, user, job_id))


@router.get("/me/export/{job_id}/download")
async def export_download(
    job_id: uuid.UUID,
    user: CurrentUser,
    session: DbSession,
    storage: Annotated[ExportStorage, Depends(get_storage)],
) -> Response:
    job = await _owned_job(session, user, job_id)
    if job.status != ExportStatus.completed or not job.file_key:
        raise ApiError(409, "export_not_ready", "Export is not ready yet")
    if job.expires_at and job.expires_at < datetime.now(UTC):
        raise ApiError(410, "export_expired", "This export has expired; request a new one")
    data = await storage.get(job.file_key)
    if data is None:
        raise ApiError(410, "export_expired", "This export has expired; request a new one")
    return Response(
        data,
        media_type="application/zip",
        headers={"Content-Disposition": 'attachment; filename="my-data.zip"'},
    )


# ---- deletion ---------------------------------------------------------------------------


@router.delete("/me", response_model=DeletionOut)
async def delete_account(
    user: CurrentUser,
    session: DbSession,
    verifier: Annotated[TokenVerifier, Depends(get_verifier)],
) -> DeletionOut:
    return DeletionOut(purge_after=await privacy.request_deletion(session, user, verifier))


@router.post("/me/restore", status_code=204)
async def restore(user: PendingOkUser, session: DbSession) -> Response:
    await privacy.restore_account(session, user)
    return Response(status_code=204)
