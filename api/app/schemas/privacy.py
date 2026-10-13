import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models import ExportStatus


class ConsentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    analytics_opt_in: bool | None
    no_ai_training: bool
    policy_version: str
    analytics_updated_at: datetime | None
    ai_training_updated_at: datetime
    location_explained_at: datetime | None


class ConsentPut(BaseModel):
    analytics_opt_in: bool | None = None
    no_ai_training: bool | None = None
    location_explained: bool | None = None


class ExportOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    status: ExportStatus
    created_at: datetime
    completed_at: datetime | None
    expires_at: datetime | None
    download_url: str | None = None


class DeletionOut(BaseModel):
    purge_after: datetime
