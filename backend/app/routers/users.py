import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_active_user
from app.database import get_db
from app.models.blocked_user import BlockedUser
from app.models.found_item import FoundItem
from app.models.lost_item import LostItem
from app.models.user import User
from app.schemas.user import UserProfile, UserResponse, UserUpdate
from app.services.user_service import get_user_profile, update_user

router = APIRouter(
    prefix="/users",
    tags=["users"],
)


# ============================================================
# CURRENT USER
# ============================================================

@router.get(
    "/me",
    response_model=UserResponse,
)
def read_users_me(
    current_user: User = Depends(get_current_active_user),
):
    return current_user


# ============================================================
# CURRENT USER REPORTS
# ============================================================

@router.get("/me/reports")
def get_my_reports(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    lost_items = (
        db.query(LostItem)
        .filter(LostItem.user_id == current_user.user_id)
        .order_by(LostItem.created_at.desc())
        .all()
    )

    found_items = (
        db.query(FoundItem)
        .filter(FoundItem.finder_id == current_user.user_id)
        .order_by(FoundItem.created_at.desc())
        .all()
    )

    reports = []

    for item in lost_items:
        reports.append(
            {
                "report_type": "lost",
                "item_id": str(item.item_id),
                "title": item.title,
                "category": item.category,
                "subcategory": item.subcategory,
                "description": item.description,
                "color": item.color,
                "brand": item.brand,
                "model": item.model,
                "material": item.material,
                "identifying_features": item.identifying_features,
                "location_name": item.location_name,
                "campus_building": item.campus_building,
                "floor": item.floor,
                "nearby_landmark": item.nearby_landmark,
                "latitude": item.latitude,
                "longitude": item.longitude,
                "photos": item.photos or [],
                "status": item.status,
                "date_lost": (
                    item.date_lost.isoformat()
                    if item.date_lost
                    else None
                ),
                "created_at": (
                    item.created_at.isoformat()
                    if item.created_at
                    else None
                ),
            }
        )

    for item in found_items:
        reports.append(
            {
                "report_type": "found",
                "item_id": str(item.item_id),
                "title": item.title,
                "category": item.category,
                "subcategory": item.subcategory,
                "description": item.description,
                "color": item.color,
                "brand": item.brand,
                "model": item.model,
                "material": item.material,
                "identifying_features": item.identifying_features,
                "location_name": item.location_name,
                "campus_building": item.campus_building,
                "floor": item.floor,
                "nearby_landmark": item.nearby_landmark,
                "latitude": item.latitude,
                "longitude": item.longitude,
                "photos": item.photos or [],
                "storage_location": item.storage_location,
                "storage_type": item.storage_type,
                "contact_preference": item.contact_preference,
                "status": item.status,
                "date_found": (
                    item.date_found.isoformat()
                    if item.date_found
                    else None
                ),
                "created_at": (
                    item.created_at.isoformat()
                    if item.created_at
                    else None
                ),
            }
        )

    reports.sort(
        key=lambda item: item.get("created_at") or "",
        reverse=True,
    )

    return reports


# ============================================================
# UPDATE CURRENT USER
# ============================================================

@router.put(
    "/me",
    response_model=UserResponse,
)
def update_user_me(
    data: UserUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    return update_user(
        db,
        current_user.user_id,
        data,
    )


# ============================================================
# USER PROFILE
# ============================================================

@router.get(
    "/{user_id}/profile",
    response_model=UserProfile,
)
def read_user_profile(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    profile = get_user_profile(
        db,
        str(user_id),
    )

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found",
        )

    return profile


# ============================================================
# BLOCK USER
# ============================================================

@router.post("/block/{user_id}")
def block_user(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    if user_id == current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot block yourself",
        )

    target_user = (
        db.query(User)
        .filter(User.user_id == user_id)
        .first()
    )

    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    existing = (
        db.query(BlockedUser)
        .filter(
            BlockedUser.blocker_id == current_user.user_id,
            BlockedUser.blocked_id == user_id,
        )
        .first()
    )

    if existing:
        return {
            "message": "User is already blocked",
            "user_id": str(user_id),
        }

    blocked = BlockedUser(
        blocker_id=current_user.user_id,
        blocked_id=user_id,
    )

    try:
        db.add(blocked)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to block user",
        )

    return {
        "message": "User blocked successfully",
        "user_id": str(user_id),
    }


# ============================================================
# UNBLOCK USER
# ============================================================

@router.delete("/block/{user_id}")
def unblock_user(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    if user_id == current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user",
        )

    blocked = (
        db.query(BlockedUser)
        .filter(
            BlockedUser.blocker_id == current_user.user_id,
            BlockedUser.blocked_id == user_id,
        )
        .first()
    )

    if not blocked:
        return {
            "message": "User is not blocked",
            "user_id": str(user_id),
        }

    try:
        db.delete(blocked)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to unblock user",
        )

    return {
        "message": "User unblocked successfully",
        "user_id": str(user_id),
    }


# ============================================================
# BLOCKED USERS
# ============================================================

@router.get("/me/blocked")
def get_blocked_users(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    blocked_rows = (
        db.query(BlockedUser, User)
        .join(
            User,
            User.user_id == BlockedUser.blocked_id,
        )
        .filter(
            BlockedUser.blocker_id == current_user.user_id
        )
        .order_by(BlockedUser.created_at.desc())
        .all()
    )

    return [
        {
            "user_id": str(user.user_id),
            "full_name": user.full_name,
            "college_email": user.college_email,
            "profile_photo": user.profile_photo,
            "blocked_at": (
                blocked.created_at.isoformat()
                if blocked.created_at
                else None
            ),
        }
        for blocked, user in blocked_rows
    ]