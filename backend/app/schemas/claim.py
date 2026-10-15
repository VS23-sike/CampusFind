import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, field_validator


VALID_ITEM_TYPES = {"lost", "found"}

VALID_CLAIM_STATUSES = {
    "pending",
    "under_review",
    "approved",
    "rejected",
    "more_info_required",
}


class ClaimBase(BaseModel):
    item_id: uuid.UUID
    item_type: str
    verification_answers: Optional[Dict[str, Any]] = None
    proof_description: Optional[str] = None

    @field_validator("item_type")
    @classmethod
    def validate_item_type(cls, value: str) -> str:
        value = value.lower().strip()

        if value not in VALID_ITEM_TYPES:
            raise ValueError("item_type must be either 'lost' or 'found'.")

        return value


class ClaimCreate(ClaimBase):
    pass


class ClaimUpdate(BaseModel):
    proof_description: Optional[str] = None
    verification_answers: Optional[Dict[str, Any]] = None


class ClaimReview(BaseModel):
    status: str
    admin_notes: Optional[str] = None

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str) -> str:
        value = value.lower().strip()

        if value not in VALID_CLAIM_STATUSES:
            raise ValueError(
                "Invalid claim status. Use pending, under_review, "
                "approved, rejected, or more_info_required."
            )

        return value


class ClaimResponse(ClaimBase):
    claim_id: uuid.UUID
    claimant_id: uuid.UUID
    evidence_photos: Optional[List[str]] = None
    status: str
    admin_notes: Optional[str] = None
    submitted_at: datetime
    reviewed_at: Optional[datetime] = None
    reviewed_by: Optional[uuid.UUID] = None

    class Config:
        from_attributes = True


class AdminClaimView(ClaimResponse):
    pass