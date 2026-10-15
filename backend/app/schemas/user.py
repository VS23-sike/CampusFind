import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field, field_validator


class UserBase(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=200)
    college_email: EmailStr
    phone_number: Optional[str] = Field(default=None, max_length=20)
    student_staff_id: Optional[str] = Field(default=None, max_length=50)
    department: Optional[str] = Field(default=None, max_length=100)
    year: Optional[str] = Field(default=None, max_length=20)


class UserCreate(UserBase):
    password: str = Field(..., min_length=8, max_length=200)


class UserUpdate(BaseModel):
    full_name: Optional[str] = Field(default=None, min_length=2, max_length=200)
    phone_number: Optional[str] = Field(default=None, max_length=20)
    department: Optional[str] = Field(default=None, max_length=100)
    year: Optional[str] = Field(default=None, max_length=20)
    profile_photo: Optional[str] = None


class UserResponse(UserBase):
    user_id: uuid.UUID
    role: str
    account_status: str
    profile_photo: Optional[str] = None
    email_verified: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


class UserProfile(BaseModel):
    user_id: uuid.UUID
    full_name: str
    college_email: EmailStr
    phone_number: Optional[str] = None
    student_staff_id: Optional[str] = None
    department: Optional[str] = None
    year: Optional[str] = None
    role: str
    profile_photo: Optional[str] = None
    email_verified: bool = False

    class Config:
        from_attributes = True


class AdminUserView(UserResponse):
    firebase_uid: Optional[str] = None
    last_login: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=200)


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    email: Optional[str] = None