import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.auth.jwt import require_admin
from app.database import get_db

from app.models.audit_log import AuditLog
from app.models.blocked_user import BlockedUser
from app.models.claim import Claim
from app.models.found_item import FoundItem
from app.models.lost_item import LostItem
from app.models.message import Message
from app.models.notification import Notification
from app.models.report import Report
from app.models.match import Match
from app.models.user import AccountStatus, User, UserRole

from app.services.analytics_service import (
    get_category_breakdown,
    get_dashboard_stats,
    get_location_breakdown,
)

from app.services.claim_service import review_claim
from app.schemas.analytics import DashboardStats


router = APIRouter(
    prefix="/admin",
    tags=["admin"],
)


def _enum_value(value):
    return getattr(value, "value", value)


VALID_ROLES = {
    UserRole.STUDENT,
    UserRole.STAFF,
    UserRole.ADMIN,
}

VALID_ACCOUNT_STATUSES = {
    AccountStatus.ACTIVE,
    AccountStatus.SUSPENDED,
    AccountStatus.PENDING,
}


def _write_audit_log(
    db: Session,
    admin_id,
    action: str,
    target_type: str,
    target_id=None,
    details: dict | None = None,
):
    db.add(
        AuditLog(
            admin_id=admin_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            details=details or {},
        )
    )


# ============================================================
# DASHBOARD
# ============================================================

@router.get(
    "/dashboard",
    response_model=DashboardStats,
)
def get_dashboard(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return get_dashboard_stats(db)


# ============================================================
# USERS
# ============================================================

@router.get("/users")
def get_users(
    search: str | None = Query(None, max_length=100),
    status: str | None = Query(None, max_length=30),
    role: str | None = Query(None, max_length=30),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(User)

    if search and search.strip():
        value = search.strip()

        query = query.filter(
            User.full_name.ilike(f"%{value}%")
            | User.college_email.ilike(f"%{value}%")
        )

    if status:
        normalized = status.strip().lower()

        if normalized not in VALID_ACCOUNT_STATUSES:
            raise HTTPException(
                status_code=400,
                detail="Invalid account status.",
            )

        query = query.filter(
            User.account_status == normalized
        )

    if role:
        normalized = role.strip().lower()

        if normalized not in VALID_ROLES:
            raise HTTPException(
                status_code=400,
                detail="Invalid user role.",
            )

        query = query.filter(
            User.role == normalized
        )

    return (
        query
        .order_by(User.created_at.desc())
        .limit(200)
        .all()
    )


@router.get("/users/{id}")
def get_user(
    id: uuid.UUID,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = (
        db.query(User)
        .filter(User.user_id == id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    return user


@router.put("/users/{id}/status")
def update_user_status(
    id: uuid.UUID,
    status: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    normalized = status.strip().lower()

    if normalized not in VALID_ACCOUNT_STATUSES:
        raise HTTPException(
            status_code=400,
            detail="Invalid account status.",
        )

    user = (
        db.query(User)
        .filter(User.user_id == id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    if (
        user.user_id == current_user.user_id
        and normalized != AccountStatus.ACTIVE
    ):
        raise HTTPException(
            status_code=400,
            detail="You cannot deactivate your own admin account.",
        )

    user.account_status = normalized

    try:
        _write_audit_log(
            db,
            current_user.user_id,
            "update_user_status",
            "user",
            user.user_id,
            {"status": normalized},
        )

        db.commit()
        db.refresh(user)

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to update user status.",
        )

    return {
        "message": "User status updated successfully.",
        "user_id": str(user.user_id),
        "status": _enum_value(user.account_status),
    }


@router.put("/users/{id}/role")
def update_user_role(
    id: uuid.UUID,
    role: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    normalized = role.strip().lower()

    if normalized not in VALID_ROLES:
        raise HTTPException(
            status_code=400,
            detail="Invalid user role.",
        )

    user = (
        db.query(User)
        .filter(User.user_id == id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    if (
        user.user_id == current_user.user_id
        and normalized != UserRole.ADMIN
    ):
        raise HTTPException(
            status_code=400,
            detail="You cannot remove your own admin role.",
        )

    user.role = normalized

    try:
        _write_audit_log(
            db,
            current_user.user_id,
            "update_user_role",
            "user",
            user.user_id,
            {"role": normalized},
        )

        db.commit()
        db.refresh(user)

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to update user role.",
        )

    return {
        "message": "User role updated successfully.",
        "user_id": str(user.user_id),
        "role": _enum_value(user.role),
    }


# ============================================================
# DELETE USER
# ============================================================

@router.delete("/users/{id}")
def delete_user(
    id: uuid.UUID,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """
    Permanently delete a user and all dependent CampusFind data.

    This is intentionally handled explicitly rather than relying
    on database cascade behaviour because the project contains
    multiple relationships that may not have cascade rules.
    """

    user = (
        db.query(User)
        .filter(User.user_id == id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found.",
        )

    # --------------------------------------------------------
    # NEVER ALLOW AN ADMIN TO DELETE THEMSELVES
    # --------------------------------------------------------

    if user.user_id == current_user.user_id:
        raise HTTPException(
            status_code=400,
            detail="You cannot delete your own admin account.",
        )

    try:
        user_id = user.user_id

        # ----------------------------------------------------
        # COLLECT USER'S ITEM IDS FIRST
        # ----------------------------------------------------

        lost_item_ids = [
            item_id
            for (item_id,) in (
                db.query(LostItem.item_id)
                .filter(
                    LostItem.user_id == user_id
                )
                .all()
            )
        ]

        found_item_ids = [
            item_id
            for (item_id,) in (
                db.query(FoundItem.item_id)
                .filter(
                    FoundItem.finder_id == user_id
                )
                .all()
            )
        ]

        all_item_ids = (
            lost_item_ids
            + found_item_ids
        )

        # ----------------------------------------------------
        # MATCHES
        #
        # Delete matches involving any item owned/reported
        # by this user.
        # ----------------------------------------------------

        if all_item_ids:
            (
                db.query(Match)
                .filter(
                    (Match.lost_item_id.in_(all_item_ids))
                    | (Match.found_item_id.in_(all_item_ids))
                )
                .delete(
                    synchronize_session=False
                )
            )

        # ----------------------------------------------------
        # CLAIMS
        #
        # 1. Claims submitted by this user
        # 2. Claims on this user's found items
        # ----------------------------------------------------

        claim_query = db.query(Claim).filter(
            (Claim.claimant_id == user_id)
        )

        if found_item_ids:
            claim_query = db.query(Claim).filter(
                (Claim.claimant_id == user_id)
                | (
                    (Claim.item_type == "found")
                    & Claim.item_id.in_(found_item_ids)
                )
            )

        claim_query.delete(
            synchronize_session=False
        )

        # ----------------------------------------------------
        # MESSAGES
        # ----------------------------------------------------

        (
            db.query(Message)
            .filter(
                (Message.sender_id == user_id)
                | (Message.receiver_id == user_id)
            )
            .delete(
                synchronize_session=False
            )
        )

        # ----------------------------------------------------
        # NOTIFICATIONS
        # ----------------------------------------------------

        (
            db.query(Notification)
            .filter(
                Notification.user_id == user_id
            )
            .delete(
                synchronize_session=False
            )
        )

        # ----------------------------------------------------
        # REPORTS CREATED BY THIS USER
        # ----------------------------------------------------

        if hasattr(Report, "reporter_id"):
            (
                db.query(Report)
                .filter(
                    Report.reporter_id == user_id
                )
                .delete(
                    synchronize_session=False
                )
            )

        # ----------------------------------------------------
        # BLOCKED USER RELATIONSHIPS
        # ----------------------------------------------------

        (
            db.query(BlockedUser)
            .filter(
                (BlockedUser.blocker_id == user_id)
                | (BlockedUser.blocked_id == user_id)
            )
            .delete(
                synchronize_session=False
            )
        )

        # ----------------------------------------------------
        # AUDIT LOGS CREATED BY THIS USER
        #
        # An admin account can appear as admin_id in logs.
        # Delete those references before deleting the user.
        # ----------------------------------------------------

        (
            db.query(AuditLog)
            .filter(
                AuditLog.admin_id == user_id
            )
            .delete(
                synchronize_session=False
            )
        )

        # ----------------------------------------------------
        # CLAIMS REVIEWED BY THIS USER
        #
        # If reviewed_by is a FK to users, clear it first.
        # ----------------------------------------------------

        if hasattr(Claim, "reviewed_by"):
            (
                db.query(Claim)
                .filter(
                    Claim.reviewed_by == user_id
                )
                .update(
                    {
                        Claim.reviewed_by: None
                    },
                    synchronize_session=False
                )
            )

        # ----------------------------------------------------
        # LOST ITEMS
        # ----------------------------------------------------

        (
            db.query(LostItem)
            .filter(
                LostItem.user_id == user_id
            )
            .delete(
                synchronize_session=False
            )
        )

        # ----------------------------------------------------
        # FOUND ITEMS
        # ----------------------------------------------------

        (
            db.query(FoundItem)
            .filter(
                FoundItem.finder_id == user_id
            )
            .delete(
                synchronize_session=False
            )
        )

        # ----------------------------------------------------
        # FINALLY DELETE USER
        # ----------------------------------------------------

        db.delete(user)

        # ----------------------------------------------------
        # AUDIT THE ADMIN ACTION
        #
        # This is intentionally written after deleting the
        # target user so the deleted user's FK references are
        # already gone.
        # ----------------------------------------------------

        _write_audit_log(
            db,
            current_user.user_id,
            "delete_user",
            "user",
            user_id,
            {
                "deleted_user_id": str(user_id),
                "deleted_user_email": user.college_email,
                "deleted_user_name": user.full_name,
            },
        )

        db.commit()

    except HTTPException:
        db.rollback()
        raise

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to delete user. "
                "The account may still have related records."
            ),
        )

    return {
        "message": "User account deleted successfully.",
        "user_id": str(user_id),
    }


# ============================================================
# LOST ITEMS
# ============================================================

@router.get("/lost-items")
def get_all_lost(
    status: str | None = Query(None, max_length=50),
    category: str | None = Query(None, max_length=100),
    location: str | None = Query(None, max_length=150),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(LostItem)

    if status:
        query = query.filter(
            LostItem.status == status.strip().lower()
        )

    if category:
        query = query.filter(
            LostItem.category.ilike(
                f"%{category.strip()}%"
            )
        )

    if location and location.strip():
        value = f"%{location.strip()}%"

        query = query.filter(
            LostItem.location_name.ilike(value)
            | LostItem.campus_building.ilike(value)
            | LostItem.nearby_landmark.ilike(value)
        )

    return (
        query
        .order_by(LostItem.created_at.desc())
        .limit(300)
        .all()
    )


# ============================================================
# FOUND ITEMS
# ============================================================

@router.get("/found-items")
def get_all_found(
    status: str | None = Query(None, max_length=50),
    category: str | None = Query(None, max_length=100),
    location: str | None = Query(None, max_length=150),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(FoundItem)

    if status:
        query = query.filter(
            FoundItem.status == status.strip().lower()
        )

    if category:
        query = query.filter(
            FoundItem.category.ilike(
                f"%{category.strip()}%"
            )
        )

    if location and location.strip():
        value = f"%{location.strip()}%"

        query = query.filter(
            FoundItem.location_name.ilike(value)
            | FoundItem.campus_building.ilike(value)
            | FoundItem.nearby_landmark.ilike(value)
        )

    return (
        query
        .order_by(FoundItem.created_at.desc())
        .limit(300)
        .all()
    )


# ============================================================
# MODERATE ITEMS
# ============================================================

@router.put("/items/{id}/moderate")
def moderate_item(
    id: uuid.UUID,
    action: str,
    item_type: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    item_type = item_type.strip().lower()
    action = action.strip().lower()

    if item_type not in {"lost", "found"}:
        raise HTTPException(
            status_code=400,
            detail="item_type must be 'lost' or 'found'.",
        )

    if action not in {
        "approve",
        "close",
        "recover",
        "restore",
    }:
        raise HTTPException(
            status_code=400,
            detail="Invalid moderation action.",
        )

    model = (
        LostItem
        if item_type == "lost"
        else FoundItem
    )

    item = (
        db.query(model)
        .filter(model.item_id == id)
        .first()
    )

    if not item:
        raise HTTPException(
            status_code=404,
            detail="Item not found.",
        )

    status_map = {
        "approve": "active",
        "restore": "active",
        "close": "closed",
        "recover": "recovered",
    }

    item.status = status_map[action]

    try:
        _write_audit_log(
            db,
            current_user.user_id,
            f"moderate_{item_type}",
            f"{item_type}_item",
            item.item_id,
            {
                "action": action,
                "status": item.status,
            },
        )

        db.commit()
        db.refresh(item)

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to moderate item.",
        )

    return {
        "message": (
            f"Item {action} action completed."
        ),
        "item_id": str(id),
        "item_type": item_type,
        "status": item.status,
    }


# ============================================================
# CLAIMS
# ============================================================

@router.get("/claims")
def get_all_claims(
    status: str | None = Query(None, max_length=50),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Claim)

    if status:
        query = query.filter(
            Claim.status == status.strip().lower()
        )

    return (
        query
        .order_by(Claim.submitted_at.desc())
        .limit(300)
        .all()
    )


@router.get("/claims/{id}")
def get_admin_claim(
    id: uuid.UUID,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    claim = (
        db.query(Claim)
        .filter(Claim.claim_id == id)
        .first()
    )

    if not claim:
        raise HTTPException(
            status_code=404,
            detail="Claim not found.",
        )

    return claim


@router.put("/claims/{id}")
def admin_update_claim(
    id: uuid.UUID,
    status: str,
    notes: str = "",
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    normalized = status.strip().lower()

    if normalized not in {
        "pending",
        "under_review",
        "approved",
        "rejected",
        "more_info_required",
    }:
        raise HTTPException(
            status_code=400,
            detail="Invalid claim status.",
        )

    claim = (
        db.query(Claim)
        .filter(Claim.claim_id == id)
        .first()
    )

    if not claim:
        raise HTTPException(
            status_code=404,
            detail="Claim not found.",
        )

    try:
        result = review_claim(
            db,
            id,
            current_user.user_id,
            normalized,
            notes.strip(),
        )

        _write_audit_log(
            db,
            current_user.user_id,
            "review_claim",
            "claim",
            id,
            {
                "status": normalized,
                "notes": notes.strip(),
            },
        )

        db.commit()

        return result

    except HTTPException:
        db.rollback()
        raise

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to update claim.",
        )


# ============================================================
# REPORTS
# ============================================================

@router.get("/reports")
def get_all_reports(
    status: str | None = Query(None, max_length=50),
    report_type: str | None = Query(None, max_length=100),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Report)

    if status:
        query = query.filter(
            Report.status == status.strip().lower()
        )

    if report_type and hasattr(
        Report,
        "report_type",
    ):
        query = query.filter(
            Report.report_type
            == report_type.strip()
        )

    return (
        query
        .order_by(Report.created_at.desc())
        .limit(300)
        .all()
    )


@router.put("/reports/{id}")
def update_report(
    id: uuid.UUID,
    status: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    normalized = status.strip().lower()

    if normalized not in {
        "pending",
        "reviewed",
        "resolved",
        "dismissed",
    }:
        raise HTTPException(
            status_code=400,
            detail="Invalid report status.",
        )

    report = (
        db.query(Report)
        .filter(Report.report_id == id)
        .first()
    )

    if not report:
        raise HTTPException(
            status_code=404,
            detail="Report not found.",
        )

    report.status = normalized

    if normalized in {
        "resolved",
        "dismissed",
    }:
        from datetime import datetime

        report.reviewed_at = datetime.utcnow()

    try:
        _write_audit_log(
            db,
            current_user.user_id,
            "update_report",
            "report",
            report.report_id,
            {"status": normalized},
        )

        db.commit()
        db.refresh(report)

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to update report.",
        )

    return report


# ============================================================
# ANALYTICS
# ============================================================

@router.get("/analytics")
def get_analytics(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return {
        "dashboard": get_dashboard_stats(db),
        "categories": get_category_breakdown(db),
        "locations": get_location_breakdown(db),
    }


# ============================================================
# AUDIT LOGS
# ============================================================

@router.get("/audit-logs")
def get_audit_logs(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(AuditLog)
        .order_by(
            AuditLog.created_at.desc()
        )
        .limit(200)
        .all()
    )


# ============================================================
# ANNOUNCEMENTS
# ============================================================

@router.post("/announcements")
def post_announcement(
    message: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    message = message.strip()

    if not message:
        raise HTTPException(
            status_code=400,
            detail="Announcement message cannot be empty.",
        )

    users = (
        db.query(User)
        .filter(
            User.account_status
            == AccountStatus.ACTIVE,
            User.user_id
            != current_user.user_id,
        )
        .all()
    )

    created = 0

    try:
        for user in users:
            db.add(
                Notification(
                    user_id=user.user_id,
                    title="CampusFind Announcement",
                    message=message,
                    type="system",
                    read_status=False,
                )
            )

            created += 1

        _write_audit_log(
            db,
            current_user.user_id,
            "create_announcement",
            "announcement",
            None,
            {
                "content": message,
                "recipients": created,
            },
        )

        db.commit()

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to create announcement.",
        )

    return {
        "message": (
            "Announcement created successfully."
        ),
        "content": message,
        "created_by": str(
            current_user.user_id
        ),
        "recipients": created,
    }