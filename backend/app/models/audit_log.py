import uuid
from datetime import datetime

from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Index,
    JSON,
    String,
)
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    log_id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    admin_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    action = Column(
        String(200),
        nullable=False,
        index=True,
    )

    target_type = Column(
        String(100),
        nullable=False,
        index=True,
    )

    target_id = Column(
        UUID(as_uuid=True),
        nullable=True,
        index=True,
    )

    details = Column(
        JSON,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    __table_args__ = (
        Index(
            "ix_audit_logs_admin_created",
            "admin_id",
            "created_at",
        ),
        Index(
            "ix_audit_logs_target",
            "target_type",
            "target_id",
        ),
    )