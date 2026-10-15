import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class Notification(Base):
    __tablename__ = "notifications"

    notification_id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    title = Column(
        String(200),
        nullable=False,
    )

    message = Column(
        Text,
        nullable=False,
    )

    type = Column(
        Enum(
            "match",
            "claim",
            "message",
            "system",
            "recovery",
            name="notification_type",
        ),
        nullable=False,
        index=True,
    )

    related_item_id = Column(
        UUID(as_uuid=True),
        nullable=True,
        index=True,
    )

    related_item_type = Column(
        String(50),
        nullable=True,
    )

    read_status = Column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    __table_args__ = (
        Index(
            "ix_notifications_user_read",
            "user_id",
            "read_status",
            "created_at",
        ),
    )