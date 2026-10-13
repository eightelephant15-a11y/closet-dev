import sentry_sdk
from fastapi import FastAPI

from app.api.v1.router import router as v1_router
from app.core.config import get_settings
from app.core.errors import install_error_handlers
from app.core.idempotency import IdempotencyMiddleware
from app.core.logging import configure_logging
from app.core.middleware import RequestIdMiddleware


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging(settings.app_env)
    if settings.sentry_dsn:
        sentry_sdk.init(dsn=settings.sentry_dsn, environment=settings.app_env)
    app = FastAPI(title="Stylist API", version="0.1.0")
    app.add_middleware(IdempotencyMiddleware)
    app.add_middleware(RequestIdMiddleware)
    install_error_handlers(app)

    @app.get("/health", tags=["ops"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(v1_router, prefix="/v1")
    return app


app = create_app()
