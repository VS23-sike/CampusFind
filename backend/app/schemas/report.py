import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


VALID_REPORT_REASONS = {
    "fake",
    "fraud",
    "spam",
    "inappropriate",
    "suspicious",
    "incorrect",
    "harassment",
}


VALID_REPORT_STATUSES = {
    "pending",
    "reviewed",
    "resolved",
    "dismissed",
}


class ReportBase(BaseModel):
    reported_item_id: Optional[uuid.UUID] = None
    reported_user_id: Optional[uuid.UUID] = None
    reason: str
    description: str = Field(..., min_length=5, max_length=2000)

    @field_validator("reason")
    @classmethod
    def validate_reason(cls, value: str) -> str:
        value = value.lower().strip()

        if value not in VALID_REPORT_REASONS:
            raise ValueError(
                "Invalid report reason. Use fake, fraud, spam, "
                "inappropriate, suspicious, incorrect, or harassment."
            )

        return value


class ReportCreate(ReportBase):
    pass


class ReportResponse(ReportBase):
    report_id: uuid.UUID
    reporter_id: uuid.UUID
    status: str
    admin_action: Optional[str] = None
    created_at: datetime
    reviewed_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class AdminReportView(ReportResponse):
    pass