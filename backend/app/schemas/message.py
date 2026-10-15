import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator, model_validator

from .user import UserProfile


# ============================================================
# CREATE MESSAGE
# ============================================================

class MessageCreate(BaseModel):
    receiver_id: uuid.UUID

    related_item_id: Optional[uuid.UUID] = None
    related_item_type: Optional[str] = None

    message_text: str = Field(
        ...,
        min_length=1,
        max_length=2000,
    )

    @field_validator("message_text")
    @classmethod
    def validate_message_text(cls, value: str) -> str:
        value = value.strip()

        if not value:
            raise ValueError("Message cannot be empty.")

        return value

    @field_validator("related_item_type")
    @classmethod
    def validate_item_type(
        cls,
        value: Optional[str],
    ) -> Optional[str]:

        if value is None:
            return value

        value = value.lower().strip()

        if value not in {"lost", "found"}:
            raise ValueError(
                "related_item_type must be either 'lost' or 'found'."
            )

        return value

    @model_validator(mode="after")
    def validate_item_reference(self):

        if (
            self.related_item_type is not None
            and self.related_item_id is None
        ):
            raise ValueError(
                "related_item_id is required when "
                "related_item_type is provided."
            )

        return self


# ============================================================
# MESSAGE RESPONSE
# ============================================================

class MessageResponse(BaseModel):
    message_id: uuid.UUID

    sender_id: uuid.UUID
    receiver_id: uuid.UUID

    related_item_id: Optional[uuid.UUID] = None
    related_item_type: Optional[str] = None

    message_text: str

    timestamp: datetime

    read_status: bool
    is_deleted: bool

    class Config:
        from_attributes = True


# ============================================================
# CONVERSATION SUMMARY
#
# This matches the structure returned by
# message_service.get_conversations()
# and consumed by Flutter MessagesScreen.
# ============================================================

class ConversationSummary(BaseModel):
    user_id: uuid.UUID
    name: str
    profile_photo: Optional[str] = None

    item_id: Optional[uuid.UUID] = None
    item_type: Optional[str] = None

    last_message: Optional[str] = None
    last_message_at: Optional[datetime] = None

    unread_count: int = 0

    class Config:
        from_attributes = True


# ============================================================
# OPTIONAL NESTED USER-BASED CONVERSATION RESPONSE
#
# Kept for compatibility if another part of the backend uses
# this structure.
# ============================================================

class ConversationDetail(BaseModel):
    other_user: UserProfile
    last_message: MessageResponse
    unread_count: int

    class Config:
        from_attributes = True