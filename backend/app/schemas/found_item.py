import uuid
from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator

from .user import UserProfile


VALID_STORAGE_TYPES = {
    "with_me",
    "security",
    "lost_found_office",
    "department_office",
}

VALID_CONTACT_PREFERENCES = {
    "chat",
    "email",
    "phone",
}


class FoundItemBase(BaseModel):
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
    date_found: date
    approximate_time: Optional[str] = Field(default=None, max_length=50)
    location_name: str = Field(..., min_length=1, max_length=200)
    campus_building: str = Field(..., min_length=1, max_length=200)
    floor: Optional[str] = Field(default=None, max_length=50)
    nearby_landmark: Optional[str] = Field(default=None, max_length=200)
    latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180)
    storage_location: Optional[str] = Field(default=None, max_length=200)
    storage_type: str = "with_me"
    contact_preference: str = "chat"

    @field_validator("storage_type")
    @classmethod
    def validate_storage_type(cls, value: str) -> str:
        value = value.lower().strip()

        if value not in VALID_STORAGE_TYPES:
            raise ValueError(
                "Invalid storage_type. Use with_me, security, "
                "lost_found_office, or department_office."
            )

        return value

    @field_validator("contact_preference")
    @classmethod
    def validate_contact_preference(cls, value: str) -> str:
        value = value.lower().strip()

        if value not in VALID_CONTACT_PREFERENCES:
            raise ValueError(
                "Invalid contact_preference. Use chat, email, or phone."
            )

        return value


class FoundItemCreate(FoundItemBase):
    private_details: Optional[str] = None


class FoundItemUpdate(BaseModel):
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
    date_found: Optional[date] = None
    approximate_time: Optional[str] = Field(default=None, max_length=50)
    location_name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    campus_building: Optional[str] = Field(default=None, min_length=1, max_length=200)
    floor: Optional[str] = Field(default=None, max_length=50)
    nearby_landmark: Optional[str] = Field(default=None, max_length=200)
    latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180)
    storage_location: Optional[str] = Field(default=None, max_length=200)
    storage_type: Optional[str] = None
    private_details: Optional[str] = None
    contact_preference: Optional[str] = None
    status: Optional[str] = None


class FoundItemResponse(FoundItemBase):
    item_id: uuid.UUID
    finder_id: uuid.UUID
    photos: Optional[List[str]] = None
    image_embedding: Optional[List[float]] = None
    private_details: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class FoundItemPublic(BaseModel):
    item_id: uuid.UUID
    title: str
    category: str
    subcategory: Optional[str] = None
    description: str
    color: Optional[str] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    date_found: date
    location_name: str
    campus_building: str
    floor: Optional[str] = None
    nearby_landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    photos: Optional[List[str]] = None
    status: str
    created_at: datetime
    finder: Optional[UserProfile] = None

    class Config:
        from_attributes = True