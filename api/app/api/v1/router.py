from fastapi import APIRouter

from app.api.v1 import auth, config, me, onboarding

router = APIRouter()
router.include_router(config.router)
router.include_router(auth.router)
router.include_router(me.router)
router.include_router(onboarding.router)
