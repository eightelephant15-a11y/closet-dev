from fastapi import APIRouter

from app.api.v1 import auth, config, garments, me, onboarding, privacy, sample

router = APIRouter()
router.include_router(config.router)
router.include_router(auth.router)
router.include_router(me.router)
router.include_router(onboarding.router)
router.include_router(sample.router)
router.include_router(privacy.router)
router.include_router(garments.router)
