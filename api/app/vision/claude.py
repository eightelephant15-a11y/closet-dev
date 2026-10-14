"""Placeholder; the real adapter lands in slice g."""

from typing import Any

from app.vision.base import VisionError


class ClaudeVisionProvider:
    name = "claude"
    model = "unset"
    version = "0"

    @classmethod
    def from_settings(cls) -> Any:
        raise VisionError("ClaudeVisionProvider is not implemented yet")
