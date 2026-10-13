from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

Step = Literal[
    "welcome", "age", "quiz", "basics", "permissions", "first_items", "first_outfit",
    "optional", "done",
]  # fmt: skip


class OnboardingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    variant: Literal["quiz_first", "closet_first"]
    current_step: Step
    completed_steps: list[Step]
    started_at: datetime
    completed_at: datetime | None
    time_to_first_outfit_ms: int | None


class OnboardingPut(BaseModel):
    current_step: Step | None = None
    completed_steps: list[Step] | None = None
    completed: bool | None = None
    time_to_first_outfit_ms: int | None = Field(default=None, ge=0)


class AgeConfirmation(BaseModel):
    confirmed_16_plus: bool


class PreferencesPut(BaseModel):
    answers: dict[str, Any]


class PreferencesOut(BaseModel):
    model_version: int
    answers: dict[str, Any]
    weights: dict[str, Any]
    updated_at: datetime | None = None
