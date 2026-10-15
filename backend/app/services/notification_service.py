import uuid
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.notification import Notification


VALID_NOTIFICATION_TYPES = {
    "match",
    "claim",
    "message",
    "system",
    "recovery",
}

VALID_ITEM_TYPES = {
    "lost",
    "found",
}

MAX_TITLE_LENGTH = 200
MAX_MESSAGE_LENGTH = 2000
MAX_NOTIFICATIONS_PER_PAGE = 100


def create_notification(
    db: Session,
    user_id: uuid.UUID,
    title: str,
    message: str,
    notification_type: str,
    related_item_id: Optional[uuid.UUID] = None,
    related_item_type: Optional[str] = None,
):
    notification_type = (
        str(notification_type).strip().lower()
    )

    if notification_type not in VALID_NOTIFICATION_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Invalid notification type.",
        )

    if related_item_type is not None:
        related_item_type = (
            str(related_item_type).strip().lower()
        )

        if related_item_type not in VALID_ITEM_TYPES:
            raise HTTPException(
                status_code=400,
                detail="Invalid related item type.",
            )

        if related_item_id is None:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Related item ID is required "
                    "when related item type is provided."
                ),
            )

    title = str(title or "").strip()
    message = str(message or "").strip()

    if not title:
        raise HTTPException(
            status_code=400,
            detail="Notification title cannot be empty.",
        )

    if len(title) > MAX_TITLE_LENGTH:
        raise HTTPException(
            status_code=400,
            detail="Notification title is too long.",
        )

    if not message:
        raise HTTPException(
            status_code=400,
            detail="Notification message cannot be empty.",
        )

    if len(message) > MAX_MESSAGE_LENGTH:
        raise HTTPException(
            status_code=400,
            detail="Notification message is too long.",
        )

    notification = Notification(
        user_id=user_id,
        title=title,
        message=message,
        type=notification_type,
        related_item_id=related_item_id,
        related_item_type=related_item_type,
        read_status=False,
    )

    try:
        db.add(notification)
        db.commit()
        db.refresh(notification)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to create notification.",
        )

    return notification


def get_notifications(
    db: Session,
    user_id: uuid.UUID,
    page: int = 1,
    size: int = 50,
):
    page = max(1, int(page))
    size = max(
        1,
        min(
            int(size),
            MAX_NOTIFICATIONS_PER_PAGE,
        ),
    )

    offset = (page - 1) * size

    return (
        db.query(Notification)
        .filter(
            Notification.user_id == user_id
        )
        .order_by(
            Notification.created_at.desc()
        )
        .offset(offset)
        .limit(size)
        .all()
    )


def get_unread_count(
    db: Session,
    user_id: uuid.UUID,
):
    return (
        db.query(Notification)
        .filter(
            Notification.user_id == user_id,
            Notification.read_status.is_(False),
        )
        .count()
    )


def mark_read(
    db: Session,
    notification_id: uuid.UUID,
    user_id: uuid.UUID,
):
    notification = (
        db.query(Notification)
        .filter(
            Notification.notification_id == notification_id,
            Notification.user_id == user_id,
        )
        .first()
    )

    if not notification:
        raise HTTPException(
            status_code=404,
            detail="Notification not found.",
        )

    if notification.read_status:
        return notification

    notification.read_status = True

    try:
        db.commit()
        db.refresh(notification)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to mark notification as read.",
        )

    return notification


def mark_all_read(
    db: Session,
    user_id: uuid.UUID,
):
    try:
        updated_count = (
            db.query(Notification)
            .filter(
                Notification.user_id == user_id,
                Notification.read_status.is_(False),
            )
            .update(
                {
                    Notification.read_status: True,
                },
                synchronize_session=False,
            )
        )

        db.commit()

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to mark notifications as read.",
        )

    return updated_count


def delete_notification(
    db: Session,
    notification_id: uuid.UUID,
    user_id: uuid.UUID,
):
    notification = (
        db.query(Notification)
        .filter(
            Notification.notification_id == notification_id,
            Notification.user_id == user_id,
        )
        .first()
    )

    if not notification:
        raise HTTPException(
            status_code=404,
            detail="Notification not found.",
        )

    try:
        db.delete(notification)
        db.commit()

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to delete notification.",
        )

    return {
        "message": "Notification deleted successfully.",
        "notification_id": str(notification_id),
    }


def send_match_notification(
    db: Session,
    lost_item,
    found_item,
    match,
):
    message = (
        f"We found a potential match for your "
        f"lost item '{lost_item.title}'. "
        f"Match confidence: "
        f"{round((match.similarity_score or 0) * 100)}%."
    )

    return create_notification(
        db=db,
        user_id=lost_item.user_id,
        title="Potential Match Found",
        message=message,
        notification_type="match",
        related_item_id=lost_item.item_id,
        related_item_type="lost",
    )


def send_claim_notification(
    db: Session,
    claim,
    status: str,
):
    status_text = (
        str(status)
        .replace("_", " ")
        .title()
    )

    message = (
        f"Your claim status has been updated to: "
        f"{status_text}."
    )

    return create_notification(
        db=db,
        user_id=claim.claimant_id,
        title="Claim Update",
        message=message,
        notification_type="claim",
        related_item_id=claim.item_id,
        related_item_type=claim.item_type,
    )


def send_message_notification(
    db: Session,
    message_obj,
):
    return create_notification(
        db=db,
        user_id=message_obj.receiver_id,
        title="New Message",
        message="You have received a new message.",
        notification_type="message",
        related_item_id=message_obj.related_item_id,
        related_item_type=message_obj.related_item_type,
    )


def send_recovery_notification(
    db: Session,
    user_id: uuid.UUID,
    item_id: uuid.UUID,
    item_type: str,
    item_title: str,
):
    return create_notification(
        db=db,
        user_id=user_id,
        title="Item Recovery Update",
        message=(
            f"Your item '{item_title}' "
            f"has a recovery update."
        ),
        notification_type="recovery",
        related_item_id=item_id,
        related_item_type=item_type,
    )


def send_system_notification(
    db: Session,
    user_id: uuid.UUID,
    title: str,
    message: str,
):
    return create_notification(
        db=db,
        user_id=user_id,
        title=title,
        message=message,
        notification_type="system",
    )