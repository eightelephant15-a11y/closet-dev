"""Vision providers. Select by the ``vision_provider`` remote-config flag; nothing else in the code
base knows which one is active."""

from app.vision.base import VisionError, VisionProvider, VisionResult, VisionUsage, validate_result
from app.vision.fake import FakeVisionProvider

__all__ = [
    "FakeVisionProvider",
    "VisionError",
    "VisionProvider",
    "VisionResult",
    "VisionUsage",
    "build_provider",
    "validate_result",
]

_fake: FakeVisionProvider | None = None


def build_provider(name: str) -> VisionProvider:
    global _fake
    if name == "claude":
        from app.vision.claude import ClaudeVisionProvider

        provider: VisionProvider = ClaudeVisionProvider.from_settings()
        return provider
    if _fake is None:  # one instance so "flaky" attempt counting works across retries
        _fake = FakeVisionProvider()
    return _fake
