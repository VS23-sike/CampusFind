import uuid
from datetime import datetime

from sqlalchemy import (
    Column,
    String,
    DateTime,
    Text,
    Enum,
    Float,
    Date,
    ForeignKey,
    Index,
)
from sqlalchemy.dialects.postgresql import UUID, ARRAY

from app.database import Base


class FoundItem(Base):
    __tablename__ = "found_items"

    item_id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    finder_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # -------------------------
    # ITEM INFORMATION
    # -------------------------

    title = Column(
        String(200),
        nullable=False,
    )

    category = Column(
        String(100),
        nullable=False,
        index=True,
    )

    subcategory = Column(
        String(100),
        nullable=True,
    )

    description = Column(
        Text,
        nullable=False,
    )

    color = Column(
        String(50),
        nullable=True,
    )

    brand = Column(
        String(100),
        nullable=True,
    )

    model = Column(
        String(100),
        nullable=True,
    )

    material = Column(
        String(100),
        nullable=True,
    )

    identifying_features = Column(
        Text,
        nullable=True,
    )

    approximate_value = Column(
        Float,
        nullable=True,
    )

    # -------------------------
    # FOUND DATE / TIME
    # -------------------------

    date_found = Column(
        Date,
        nullable=False,
        index=True,
    )

    approximate_time = Column(
        String(50),
        nullable=True,
    )

    # -------------------------
    # LOCATION
    # -------------------------

    # Main human-readable location.
    # Example:
    # "Canteen, near the entrance"
    # "Library 2nd floor"
    # "Parking area"
    location_name = Column(
        String(200),
        nullable=False,
        index=True,
    )

    # Optional structured campus information.
    campus_building = Column(
        String(200),
        nullable=True,
        index=True,
    )

    floor = Column(
        String(50),
        nullable=True,
    )

    nearby_landmark = Column(
        String(200),
        nullable=True,
    )

    # Optional GPS coordinates.
    latitude = Column(
        Float,
        nullable=True,
    )

    longitude = Column(
        Float,
        nullable=True,
    )

    # -------------------------
    # PHOTOS / AI
    # -------------------------

    photos = Column(
        ARRAY(Text),
        nullable=True,
        default=list,
    )

    image_embedding = Column(
        ARRAY(Float),
        nullable=True,
    )

    # -------------------------
    # ITEM STORAGE
    # -------------------------

    storage_location = Column(
        String(200),
        nullable=True,
    )

    storage_type = Column(
        Enum(
            "with_me",
            "security",
            "lost_found_office",
            "department_office",
            name="storage_type",
        ),
        nullable=False,
        default="with_me",
    )

    # Private information used for claim verification.
    # This must never be exposed in public item responses.
    private_details = Column(
        Text,
        nullable=True,
    )

    contact_preference = Column(
        String(50),
        nullable=False,
        default="chat",
    )

    # -------------------------
    # STATUS
    # -------------------------

    status = Column(
        Enum(
            "active",
            "matched",
            "claimed",
            "recovered",
            "closed",
            name="found_status",
        ),
        nullable=False,
        default="active",
        index=True,
    )

    # -------------------------
    # TIMESTAMPS
    # -------------------------

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    # -------------------------
    # INDEXES
    # -------------------------

    __table_args__ = (
        Index(
            "ix_found_items_search",
            "category",
            "status",
            "date_found",
        ),
        Index(
            "ix_found_items_location",
            "campus_building",
            "location_name",
        ),
    )