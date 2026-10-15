from sqlalchemy.orm import Session
from fastapi import HTTPException

from app.models.user import User, AccountStatus
from app.schemas.user import UserCreate, UserUpdate
from app.auth.password import hash_password, verify_password


def get_user_by_email(
    db: Session,
    email: str,
):
    normalized_email = str(
        email or ""
    ).strip().lower()

    if not normalized_email:
        return None

    return (
        db.query(User)
        .filter(
            User.college_email == normalized_email
        )
        .first()
    )


def get_user_by_id(
    db: Session,
    user_id: str,
):
    if not user_id:
        return None

    return (
        db.query(User)
        .filter(
            User.user_id == user_id
        )
        .first()
    )


def create_user(
    db: Session,
    data: UserCreate,
):
    email = (
        str(data.college_email)
        .strip()
        .lower()
    )

    if not email:
        raise HTTPException(
            status_code=400,
            detail="College email is required.",
        )

    existing = get_user_by_email(
        db,
        email,
    )

    if existing:
        raise HTTPException(
            status_code=400,
            detail=(
                "An account with this email "
                "already exists."
            ),
        )

    db_user = User(
        full_name=data.full_name.strip(),
        college_email=email,
        hashed_password=hash_password(
            data.password
        ),
        phone_number=data.phone_number,
        student_staff_id=data.student_staff_id,
        department=data.department,
        year=data.year,
        account_status=AccountStatus.ACTIVE,
        email_verified=False,
    )

    try:
        db.add(db_user)
        db.commit()
        db.refresh(db_user)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to create user account.",
        )

    return db_user


def authenticate_user(
    db: Session,
    email: str,
    password: str,
):
    user = get_user_by_email(
        db,
        email,
    )

    if not user:
        return False

    if not user.hashed_password:
        return False

    try:
        if not verify_password(
            password,
            user.hashed_password,
        ):
            return False
    except Exception:
        return False

    return user


def update_user(
    db: Session,
    user_id: str,
    data: UserUpdate,
):
    user = get_user_by_id(
        db,
        user_id,
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    update_data = data.model_dump(
        exclude_unset=True
    )

    protected_fields = {
        "user_id",
        "college_email",
        "hashed_password",
        "role",
        "account_status",
        "firebase_uid",
        "email_verified",
        "email_verification_token",
        "email_verification_expires",
        "password_reset_token",
        "password_reset_expires",
        "created_at",
        "updated_at",
    }

    for key, value in update_data.items():
        if key in protected_fields:
            continue

        if key == "full_name" and value is not None:
            value = str(value).strip()

            if not value:
                raise HTTPException(
                    status_code=400,
                    detail="Full name cannot be empty.",
                )

        if key == "phone_number" and value is not None:
            value = str(value).strip()

        if key == "student_staff_id" and value is not None:
            value = str(value).strip()

        if key == "department" and value is not None:
            value = str(value).strip()

        setattr(
            user,
            key,
            value,
        )

    try:
        db.commit()
        db.refresh(user)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to update user profile.",
        )

    return user


def get_user_profile(
    db: Session,
    user_id: str,
):
    user = get_user_by_id(
        db,
        user_id,
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    return user


def suspend_user(
    db: Session,
    user_id: str,
    admin_id: str,
):
    user = get_user_by_id(
        db,
        user_id,
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    if str(user.user_id) == str(admin_id):
        raise HTTPException(
            status_code=400,
            detail=(
                "An administrator cannot suspend "
                "their own account."
            ),
        )

    if user.account_status == AccountStatus.SUSPENDED:
        return user

    user.account_status = (
        AccountStatus.SUSPENDED
    )

    try:
        db.commit()
        db.refresh(user)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to suspend user.",
        )

    return user


def activate_user(
    db: Session,
    user_id: str,
):
    user = get_user_by_id(
        db,
        user_id,
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    if user.account_status == AccountStatus.ACTIVE:
        return user

    user.account_status = (
        AccountStatus.ACTIVE
    )

    try:
        db.commit()
        db.refresh(user)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to activate user.",
        )

    return user


def verify_user_email(
    db: Session,
    user_id: str,
):
    user = get_user_by_id(
        db,
        user_id,
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    user.email_verified = True
    user.email_verification_token = None
    user.email_verification_expires = None

    try:
        db.commit()
        db.refresh(user)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to verify email.",
        )

    return user


def set_password(
    db: Session,
    user_id: str,
    new_password: str,
):
    user = get_user_by_id(
        db,
        user_id,
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    new_password = str(
        new_password or ""
    )

    if not new_password:
        raise HTTPException(
            status_code=400,
            detail="Password cannot be empty.",
        )

    try:
        new_hash = hash_password(
            new_password
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        )

    user.hashed_password = new_hash

    # A password change invalidates any
    # outstanding password-reset flow.
    user.password_reset_token = None
    user.password_reset_expires = None

    try:
        db.commit()
        db.refresh(user)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to update password.",
        )

    return user