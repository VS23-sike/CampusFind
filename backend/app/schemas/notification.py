import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class NotificationResponse(BaseModel):
    notification_id: uuid.UUID
    user_id: uuid.UUID

    title: str
    message: str
    type: str

    related_item_id: Optional[uuid.UUID] = None
    related_item_type: Optional[str] = None

    read_status: bool
    created_at: datetime

    class Config:
        from_attributes = True


class NotificationUnreadCount(BaseModel):
    unread_count: int