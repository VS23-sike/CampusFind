
from typing import List

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = Field(
        default="",
        min_length=1,
    )

    # JWT
    SECRET_KEY: str = Field(
        default="",
        min_length=32,
    )

    ALGORITHM: str = "HS256"

    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(
        default=60,
        ge=5,
        le=1440,
    )

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"
    FIREBASE_STORAGE_BUCKET: str = "campusfind-demo.appspot.com"

    # College
    COLLEGE_EMAIL_DOMAIN: str = "apsit.edu.in"

    # Application
    DEBUG: bool = False
    APP_NAME: str = "CampusFind"
    APP_VERSION: str = "1.0.0"

    # Email / SendGrid
    SENDGRID_API_KEY: str = ""
    SENDGRID_FROM_EMAIL: str = ""

    # AI
    AI_EMBEDDING_MODEL: str = "all-MiniLM-L6-v2"

    AI_MATCH_THRESHOLD: float = Field(
        default=0.70,
        ge=0.0,
        le=1.0,
    )

    # Demo accounts
    DEMO_STUDENT_EMAIL: str = ""
    DEMO_STUDENT_PASSWORD: str = ""
    DEMO_ADMIN_EMAIL: str = ""
    DEMO_ADMIN_PASSWORD: str = ""

    # CORS
    ALLOWED_ORIGINS: List[str] = Field(
        default_factory=lambda: [
            "http://localhost:3000",
            "http://localhost:8000",
            "http://127.0.0.1:8000",
        ]
    )

    # Allow Flutter Web's changing localhost development port.
    # Restricted to localhost and 127.0.0.1.
    ALLOWED_ORIGIN_REGEX: str = (
        r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    )

    # File uploads
    MAX_FILE_SIZE: int = Field(
        default=10 * 1024 * 1024,
        ge=1,
        le=50 * 1024 * 1024,
    )

    ALLOWED_EXTENSIONS: List[str] = Field(
        default_factory=lambda: [
            "jpg",
            "jpeg",
            "png",
            "webp",
        ]
    )

    # Environment
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()
