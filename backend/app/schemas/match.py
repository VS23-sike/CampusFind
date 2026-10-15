import uuid

from datetime import datetime
from typing import Any, Dict, Optional

from pydantic import BaseModel, Field

from .lost_item import LostItemPublic
from .found_item import FoundItemPublic


class MatchResponse(BaseModel):
    match_id: uuid.UUID

    similarity_score: float = Field(..., ge=0.0, le=1.0)

    image_similarity: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    category_similarity: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    color_similarity: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    brand_similarity: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    location_proximity: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    date_proximity: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    description_similarity: Optional[float] = Field(default=None, ge=0.0, le=1.0)

    matching_features: Optional[Dict[str, Any]] = None

    status: str
    created_at: Optional[datetime] = None

    lost_item: Optional[LostItemPublic] = None
    found_item: Optional[FoundItemPublic] = None

    class Config:
        from_attributes = True