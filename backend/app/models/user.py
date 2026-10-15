import uuid
from datetime import datetime

from sqlalchemy import Column, String, Text, Boolean, DateTime, Enum
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class UserRole:
    STUDENT = "student"
    STAFF = "staff"
    ADMIN = "admin"


class AccountStatus:
    ACTIVE = "active"
    SUSPENDED = "suspended"
    PENDING = "pending"


class User(Base):
    __tablename__ = "users"

    user_id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    full_name = Column(
        String(200),
        nullable=False,
    )

    college_email = Column(
        String(200),
        unique=True,
        nullable=False,
        index=True,
    )

    hashed_password = Column(
        String(200),
        nullable=False,
    )

    phone_number = Column(
        String(20),
        nullable=True,
    )

    profile_photo = Column(
        Text,
        nullable=True,
    )

    student_staff_id = Column(
        String(50),
        nullable=True,
    )

    department = Column(
        String(100),
        nullable=True,
    )

    year = Column(
        String(20),
        nullable=True,
    )

    role = Column(
        Enum(
            "student",
            "staff",
            "admin",
            name="user_role",
        ),
        default="student",
        nullable=False,
    )

    account_status = Column(
        Enum(
            "active",
            "suspended",
            "pending",
            name="account_status",
        ),
        default="active",
        nullable=False,
    )

    firebase_uid = Column(
        String(128),
        unique=True,
        nullable=True,
    )

    email_verified = Column(
        Boolean,
        default=False,
        nullable=False,
    )

    email_verification_token = Column(
        String(500),
        nullable=True,
    )

    email_verification_expires = Column(
        DateTime,
        nullable=True,
    )

    password_reset_token = Column(
        String(500),
        nullable=True,
    )

    password_reset_expires = Column(
        DateTime,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    last_login = Column(
        DateTime,
        nullable=True,
    )