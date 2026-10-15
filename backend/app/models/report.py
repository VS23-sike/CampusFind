import uuid
from datetime import datetime

from sqlalchemy import (
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class Report(Base):
    __tablename__ = "reports"

    report_id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    reporter_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    reported_item_id = Column(
        UUID(as_uuid=True),
        nullable=True,
        index=True,
    )

    reported_user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    reason = Column(
        Enum(
            "fake",
            "fraud",
            "spam",
            "inappropriate",
            "suspicious",
            "incorrect",
            "harassment",
            name="report_reason",
        ),
        nullable=False,
        index=True,
    )

    description = Column(
        Text,
        nullable=False,
    )

    status = Column(
        Enum(
            "pending",
            "reviewed",
            "resolved",
            "dismissed",
            name="report_status",
        ),
        nullable=False,
        default="pending",
        index=True,
    )

    admin_action = Column(
        Text,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    reviewed_at = Column(
        DateTime,
        nullable=True,
    )

    __table_args__ = (
        Index(
            "ix_reports_status_created",
            "status",
            "created_at",
        ),
        Index(
            "ix_reports_reported_user_status",
            "reported_user_id",
            "status",
        ),
        Index(
            "ix_reports_reported_item_status",
            "reported_item_id",
            "status",
        ),
    )