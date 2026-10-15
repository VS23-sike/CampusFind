import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class Message(Base):
    __tablename__ = "messages"

    message_id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    sender_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    receiver_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
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

    message_text = Column(
        Text,
        nullable=False,
    )

    timestamp = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    read_status = Column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
    )

    is_deleted = Column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
    )

    __table_args__ = (
        Index(
            "ix_messages_conversation",
            "sender_id",
            "receiver_id",
            "timestamp",
        ),
        Index(
            "ix_messages_receiver_unread",
            "receiver_id",
            "read_status",
        ),
    )