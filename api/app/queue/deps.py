"""Wiring: the singletons the API and the worker share, with setters for tests."""

from typing import Any

from app.core.config import get_settings
from app.core.db import get_sessionmaker
from app.core.redis import get_redis
from app.queue.core import JobDeps, JobQueue
from app.services.background import build_remover
from app.services.storage import get_storage

_queue: JobQueue | None = None
_vision_factory: Any = None


def set_queue(q: JobQueue | None) -> None:
    global _queue
    _queue = q


def get_queue() -> JobQueue:
    global _queue
    if _queue is None:
        settings = get_settings()
        if settings.queue_backend == "eager":
            from app.queue.eager import EagerQueue

            eager = EagerQueue()
            eager.deps = build_deps(eager)
            _queue = eager
        else:
            from app.queue.arq_queue import ArqJobQueue

            _queue = ArqJobQueue(settings.redis_url)
    return _queue


def set_vision_factory(factory: Any) -> None:
    """Tests inject their own provider factory (name -> provider)."""
    global _vision_factory
    _vision_factory = factory


def vision_for(name: str) -> Any:
    if _vision_factory is not None:
        return _vision_factory(name)
    from app.vision import build_provider

    return build_provider(name)


def build_deps(queue: JobQueue | None = None) -> JobDeps:
    return JobDeps(
        maker=get_sessionmaker(),
        storage=get_storage(),
        queue=queue or get_queue(),
        redis=get_redis,
        settings=get_settings(),
        remover=build_remover(),
        vision=vision_for,
    )
