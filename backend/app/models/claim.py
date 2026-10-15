import uuid
from datetime import datetime

from sqlalchemy import (
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    JSON,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID, ARRAY

from app.database import Base


class Claim(Base):
    __tablename__ = "claims"

    claim_id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    item_id = Column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
    )

    item_type = Column(
        Enum(
            "lost",
            "found",
            name="item_type",
        ),
        nullable=False,
    )

    claimant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    verification_answers = Column(
        JSON,
        nullable=True,
    )

    proof_description = Column(
        Text,
        nullable=True,
    )

    evidence_photos = Column(
        ARRAY(Text),
        nullable=True,
    )

    status = Column(
        Enum(
            "pending",
            "under_review",
            "approved",
            "rejected",
            "more_info_required",
            name="claim_status",
        ),
        nullable=False,
        default="pending",
        index=True,
    )

    admin_notes = Column(
        Text,
        nullable=True,
    )

    submitted_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    reviewed_at = Column(
        DateTime,
        nullable=True,
    )

    reviewed_by = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    __table_args__ = (
        Index(
            "ix_claims_item_type_status",
            "item_id",
            "item_type",
            "status",
        ),
        Index(
            "ix_claims_claimant_status",
            "claimant_id",
            "status",
        ),
    )