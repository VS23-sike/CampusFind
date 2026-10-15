from datetime import datetime, timedelta
import logging
import re
import secrets
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session

from app.auth.firebase import verify_firebase_token
from app.auth.jwt import create_access_token, get_current_active_user
from app.auth.password import (
    hash_password,
    validate_password_strength,
    verify_password,
)
from app.config import settings
from app.database import get_db
from app.models.user import AccountStatus, User, UserRole
from app.schemas.user import UserCreate, UserLogin
from app.services.user_service import (
    authenticate_user,
    create_user,
    get_user_by_email,
    get_user_by_id,
)

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger(__name__)

APSIT_STUDENT_EMAIL_REGEX = re.compile(
    r"^[0-9]{8}@apsit\.edu\.in$",
    re.IGNORECASE,
)

ADMIN_EMAIL = "admin@campusfind.demo"


def normalize_email(email: str) -> str:
    return str(email or "").strip().lower()


def is_valid_student_email(email: str) -> bool:
    return APSIT_STUDENT_EMAIL_REGEX.fullmatch(
        normalize_email(email)
    ) is not None


def is_allowed_campus_email(email: str) -> bool:
    normalized = normalize_email(email)
    return normalized == ADMIN_EMAIL or is_valid_student_email(normalized)


def _role_value(role) -> str:
    return str(getattr(role, "value", role)).lower()


def _status_value(value) -> str:
    return str(getattr(value, "value", value)).lower()


def _create_user_access_token(user: User) -> str:
    return create_access_token(
        data={
            "sub": normalize_email(user.college_email),
            "role": _role_value(user.role),
            "user_id": str(user.user_id),
        },
        expires_delta=timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        ),
    )


class FirebaseLoginRequest(BaseModel):
    id_token: str = Field(..., min_length=1, max_length=5000)


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )
    new_password: str = Field(
        ...,
        min_length=8,
        max_length=200,
    )


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    token: str = Field(..., min_length=1, max_length=500)
    new_password: str = Field(
        ...,
        min_length=8,
        max_length=200,
    )


class VerifyEmailRequest(BaseModel):
    user_id: uuid.UUID
    token: str = Field(
        default="",
        max_length=500,
    )


# ============================================================
# REGISTER
# ============================================================

@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
)
def register(
    data: UserCreate,
    db: Session = Depends(get_db),
):
    email = normalize_email(data.college_email)

    if not is_valid_student_email(email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Registration requires an APSIT student email "
                "in the format 8digits@apsit.edu.in."
            ),
        )

    if get_user_by_email(db, email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email already exists.",
        )

    try:
        validate_password_strength(data.password)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )

    if not data.full_name or not data.full_name.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Full name is required.",
        )

    data.college_email = email
    data.full_name = data.full_name.strip()

    try:
        user = create_user(db, data)
    except HTTPException:
        raise
    except Exception:
        db.rollback()
        logger.exception("User registration failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to create account.",
        )

    access_token = _create_user_access_token(user)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": str(user.user_id),
        "role": _role_value(user.role),
        "full_name": user.full_name,
        "email": user.college_email,
        "email_verified": bool(user.email_verified),
        "profile_photo": user.profile_photo,
        "department": user.department,
        "year": user.year,
    }


# ============================================================
# LOGIN
# ============================================================

@router.post("/login")
def login(
    data: UserLogin,
    db: Session = Depends(get_db),
):
    email = normalize_email(data.email)

    if not is_allowed_campus_email(email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Please use your APSIT college email "
                "(8digits@apsit.edu.in)."
            ),
        )

    user = authenticate_user(
        db,
        email,
        data.password,
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if _status_value(user.account_status) != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Your account is not active. "
                "Contact administration."
            ),
        )

    user.last_login = datetime.utcnow()

    try:
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to complete login.",
        )

    access_token = _create_user_access_token(user)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": str(user.user_id),
        "role": _role_value(user.role),
        "full_name": user.full_name,
        "email": user.college_email,
        "email_verified": bool(user.email_verified),
        "profile_photo": user.profile_photo,
        "department": user.department,
        "year": user.year,
    }


# ============================================================
# FIREBASE LOGIN
# ============================================================

@router.post("/firebase-login")
def firebase_login(
    body: FirebaseLoginRequest,
    db: Session = Depends(get_db),
):
    try:
        decoded = verify_firebase_token(body.id_token.strip())
    except Exception:
        logger.warning(
            "Firebase token verification failed",
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not decoded:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = normalize_email(decoded.get("email", ""))
    firebase_uid = str(decoded.get("uid", "")).strip()
    name = str(
        decoded.get("name")
        or email.split("@")[0]
    ).strip()
    photo_url = decoded.get("picture")

    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Firebase token does not contain an email.",
        )

    if not is_allowed_campus_email(email):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Only APSIT college email accounts "
                "are allowed to access CampusFind."
            ),
        )

    if not firebase_uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase identity.",
        )

    user = get_user_by_email(db, email)

    if user:
        if _status_value(user.account_status) != "active":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "Your account is not active. "
                    "Contact administration."
                ),
            )

        if not user.firebase_uid:
            user.firebase_uid = firebase_uid
        elif user.firebase_uid != firebase_uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Firebase account does not match this user.",
            )

        if photo_url and not user.profile_photo:
            user.profile_photo = photo_url

        if name and (
            not user.full_name
            or user.full_name == email.split("@")[0]
        ):
            user.full_name = name

        user.email_verified = True

    else:
        if email == ADMIN_EMAIL:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "Admin account must be created "
                    "by the system administrator."
                ),
            )

        if not is_valid_student_email(email):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "Only APSIT student accounts can register."
                ),
            )

        user = User(
            full_name=name or email.split("@")[0],
            college_email=email,
            hashed_password=hash_password(
                secrets.token_urlsafe(32)
            ),
            firebase_uid=firebase_uid,
            profile_photo=photo_url,
            email_verified=True,
            role=UserRole.STUDENT,
            account_status=AccountStatus.ACTIVE,
        )

        db.add(user)

    user.last_login = datetime.utcnow()

    try:
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        logger.exception(
            "Firebase account synchronization failed"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to complete authentication.",
        )

    access_token = _create_user_access_token(user)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": str(user.user_id),
        "role": _role_value(user.role),
        "full_name": user.full_name,
        "email": user.college_email,
        "email_verified": bool(user.email_verified),
        "profile_photo": user.profile_photo,
        "department": user.department,
        "year": user.year,
    }


# ============================================================
# LOGOUT
# ============================================================

@router.post("/logout")
def logout(
    current_user: User = Depends(get_current_active_user),
):
    return {
        "message": "Logged out successfully."
    }


# ============================================================
# FORGOT PASSWORD
# ============================================================

@router.post("/forgot-password")
def forgot_password(
    body: ForgotPasswordRequest,
    db: Session = Depends(get_db),
):
    email = normalize_email(body.email)

    generic_response = {
        "message": (
            "If an account exists with this email, "
            "a reset link has been sent."
        )
    }

    if not is_allowed_campus_email(email):
        return generic_response

    user = get_user_by_email(db, email)

    if not user:
        return generic_response

    token = secrets.token_urlsafe(48)

    user.password_reset_token = token
    user.password_reset_expires = (
        datetime.utcnow() + timedelta(minutes=30)
    )

    try:
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Password reset token creation failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to process password reset.",
        )

    # Development mode exposes the token so the Flutter app
    # can complete the flow while email delivery is configured.
    if settings.DEBUG:
        return {
            **generic_response,
            "reset_token": token,
        }

    return generic_response


# ============================================================
# RESET PASSWORD
# ============================================================

@router.post("/reset-password")
def reset_password(
    body: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    email = normalize_email(body.email)

    user = get_user_by_email(db, email)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token.",
        )

    if not user.password_reset_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token.",
        )

    if user.password_reset_token != body.token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token.",
        )

    if (
        not user.password_reset_expires
        or user.password_reset_expires < datetime.utcnow()
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token.",
        )

    try:
        validate_password_strength(body.new_password)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )

    user.hashed_password = hash_password(body.new_password)
    user.password_reset_token = None
    user.password_reset_expires = None

    try:
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Password reset failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to reset password.",
        )

    return {
        "message": "Password reset successfully."
    }


# ============================================================
# CHANGE PASSWORD
# ============================================================

@router.post("/change-password")
def change_password(
    body: ChangePasswordRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    if not verify_password(
        body.current_password,
        current_user.hashed_password,
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect.",
        )

    if body.current_password == body.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "New password must be different "
                "from the current password."
            ),
        )

    try:
        validate_password_strength(body.new_password)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )

    current_user.hashed_password = hash_password(
        body.new_password
    )

    try:
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Password change failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to change password.",
        )

    return {
        "message": "Password changed successfully."
    }


# ============================================================
# VERIFY EMAIL
# ============================================================

@router.post("/verify-email")
def verify_email(
    body: VerifyEmailRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    if current_user.user_id != body.user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You cannot verify another user's account.",
        )

    if current_user.email_verified:
        return {
            "message": "Email is already verified."
        }

    # If a real verification token exists, require it.
    if current_user.email_verification_token:
        if current_user.email_verification_token != body.token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid verification token.",
            )

        if (
            current_user.email_verification_expires
            and current_user.email_verification_expires
            < datetime.utcnow()
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Verification token has expired.",
            )

    current_user.email_verified = True
    current_user.email_verification_token = None
    current_user.email_verification_expires = None

    try:
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Email verification failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to verify email.",
        )

    return {
        "message": "Email verified successfully."
    }