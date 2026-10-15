import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    JSON,
)
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


class Match(Base):
    __tablename__ = "matches"

    match_id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    lost_item_id = Column(
        UUID(as_uuid=True),
        ForeignKey("lost_items.item_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    found_item_id = Column(
        UUID(as_uuid=True),
        ForeignKey("found_items.item_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Overall AI similarity score (0.0 - 1.0)
    similarity_score = Column(
        Float,
        nullable=False,
    )

    image_similarity = Column(
        Float,
        nullable=True,
    )

    category_similarity = Column(
        Float,
        nullable=True,
    )

    color_similarity = Column(
        Float,
        nullable=True,
    )

    brand_similarity = Column(
        Float,
        nullable=True,
    )

    location_proximity = Column(
        Float,
        nullable=True,
    )

    date_proximity = Column(
        Float,
        nullable=True,
    )

    description_similarity = Column(
        Float,
        nullable=True,
    )

    # Structured explanation of why the items matched
    matching_features = Column(
        JSON,
        nullable=True,
    )

    status = Column(
        Enum(
            "pending",
            "viewed",
            "dismissed",
            "claimed",
            name="match_status",
        ),
        nullable=False,
        default="pending",
        index=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    dismissed_by_lost_user = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    dismissed_by_found_user = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    __table_args__ = (
        Index(
            "ix_matches_lost_found",
            "lost_item_id",
            "found_item_id",
        ),
        Index(
            "ix_matches_lost_status",
            "lost_item_id",
            "status",
        ),
        Index(
            "ix_matches_found_status",
            "found_item_id",
            "status",
        ),
    )