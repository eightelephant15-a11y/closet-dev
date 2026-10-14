"""Background removal seam. ``PassThroughRemover`` is the default; ``RembgRemover`` is optional."""

import asyncio
from typing import Protocol

from PIL import Image

from app.core.config import get_settings


class BackgroundRemover(Protocol):
    name: str

    async def remove(self, image: Image.Image) -> Image.Image: ...


class PassThroughRemover:
    name = "passthrough"

    async def remove(self, image: Image.Image) -> Image.Image:
        return image


class RembgRemover:
    """UNVERIFIED: needs ``pip install -e '.[rembg]'`` and downloads a model on first use."""

    name = "rembg"

    def __init__(self) -> None:
        from rembg import new_session

        self._session = new_session()

    async def remove(self, image: Image.Image) -> Image.Image:
        from rembg import remove

        def run() -> Image.Image:
            out = remove(image, session=self._session)
            return out if isinstance(out, Image.Image) else image

        return await asyncio.to_thread(run)


def build_remover(name: str | None = None) -> BackgroundRemover:
    chosen = name or get_settings().background_remover
    return RembgRemover() if chosen == "rembg" else PassThroughRemover()
