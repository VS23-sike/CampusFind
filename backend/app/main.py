
from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.rate_limit import limiter
from app.config import settings
from app.database import engine, Base
from app.auth.firebase import initialize_firebase

from app.routers import (
    auth,
    users,
    lost_items,
    found_items,
    matches,
    claims,
    messages,
    notifications,
    reports,
    search,
    admin,
    uploads,
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables initialized")
    except Exception:
        logger.exception("Database initialization failed")
        raise

    try:
        initialize_firebase()
        logger.info("Firebase initialized successfully")
    except RuntimeError:
        logger.warning(
            "Firebase is not configured. "
            "Firebase-dependent features will be unavailable."
        )
    except Exception:
        logger.exception(
            "Unexpected Firebase initialization error"
        )

    try:
        from app.ai.embedding_service import embedding_service
        logger.info("AI embedding service initialized successfully")
    except Exception:
        logger.exception(
            "AI embedding service failed to initialize"
        )

    logger.info("CampusFind API startup completed")
    yield
    logger.info("CampusFind API shutting down")


app = FastAPI(
    title="CampusFind API",
    description=(
        "Backend API for CampusFind - "
        "AI-powered college Lost & Found system"
    ),
    version="1.0.0",
    lifespan=lifespan,
)


# Rate limiting
app.state.limiter = limiter
app.add_exception_handler(
    RateLimitExceeded,
    _rate_limit_exceeded_handler,
)


# CORS — temporary local development configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_origin_regex=r".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# API routers
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(lost_items.router)
app.include_router(found_items.router)
app.include_router(matches.router)
app.include_router(claims.router)
app.include_router(messages.router)
app.include_router(notifications.router)
app.include_router(reports.router)
app.include_router(search.router)
app.include_router(admin.router)
app.include_router(uploads.router)


# Health check
@app.get("/health", tags=["health"])
def health_check():
    return {
        "status": "ok",
        "message": "CampusFind API is running",
        "version": settings.APP_VERSION,
    }
