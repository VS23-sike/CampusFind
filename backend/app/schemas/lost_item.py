import uuid
from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator

from .user import UserProfile


VALID_CONTACT_PREFERENCES = {
    "chat",
    "email",
    "phone",
}


class LostItemBase(BaseModel):
    title: str = Field(..., min_length=2, max_length=200)
    category: str = Field(..., min_length=1, max_length=100)
    subcategory: Optional[str] = Field(default=None, max_length=100)
    description: str = Field(..., min_length=5)
    color: Optional[str] = Field(default=None, max_length=50)
    brand: Optional[str] = Field(default=None, max_length=100)
    model: Optional[str] = Field(default=None, max_length=100)
    material: Optional[str] = Field(default=None, max_length=100)
    identifying_features: Optional[str] = None
    approximate_value: Optional[float] = Field(default=None, ge=0)
    date_lost: date
    approximate_time: Optional[str] = Field(default=None, max_length=50)
    location_name: str = Field(..., min_length=1, max_length=200)
    campus_building: str = Field(..., min_length=1, max_length=200)
    floor: Optional[str] = Field(default=None, max_length=50)
    nearby_landmark: Optional[str] = Field(default=None, max_length=200)
    latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180)
    contact_preference: str = "chat"

    @field_validator("contact_preference")
    @classmethod
    def validate_contact_preference(cls, value: str) -> str:
        value = value.lower().strip()

        if value not in VALID_CONTACT_PREFERENCES:
            raise ValueError(
                "Invalid contact_preference. Use chat, email, or phone."
            )

        return value


class LostItemCreate(LostItemBase):
    pass


class LostItemUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=2, max_length=200)
    category: Optional[str] = Field(default=None, min_length=1, max_length=100)
    subcategory: Optional[str] = Field(default=None, max_length=100)
    description: Optional[str] = Field(default=None, min_length=5)
    color: Optional[str] = Field(default=None, max_length=50)
    brand: Optional[str] = Field(default=None, max_length=100)
    model: Optional[str] = Field(default=None, max_length=100)
    material: Optional[str] = Field(default=None, max_length=100)
    identifying_features: Optional[str] = None
    approximate_value: Optional[float] = Field(default=None, ge=0)
    date_lost: Optional[date] = None
    approximate_time: Optional[str] = Field(default=None, max_length=50)
    location_name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    campus_building: Optional[str] = Field(default=None, min_length=1, max_length=200)
    floor: Optional[str] = Field(default=None, max_length=50)
    nearby_landmark: Optional[str] = Field(default=None, max_length=200)
    latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180)
    contact_preference: Optional[str] = None
    status: Optional[str] = None


class LostItemResponse(LostItemBase):
    item_id: uuid.UUID
    user_id: uuid.UUID
    photos: Optional[List[str]] = None
    image_embedding: Optional[List[float]] = None
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class LostItemPublic(BaseModel):
    item_id: uuid.UUID
    title: str
    category: str
    subcategory: Optional[str] = None
    description: str
    color: Optional[str] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    date_lost: date
    location_name: str
    campus_building: str
    floor: Optional[str] = None
    nearby_landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    photos: Optional[List[str]] = None
    status: str
    created_at: datetime
    user: Optional[UserProfile] = None

    class Config:
        from_attributes = True