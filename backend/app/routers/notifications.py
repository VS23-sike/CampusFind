import uuid

from fastapi import (
    APIRouter,
    Depends,
    Query,
)

from sqlalchemy.orm import Session

from app.database import get_db

from app.schemas.notification import (
    NotificationResponse,
    NotificationUnreadCount,
)

from app.auth.jwt import get_current_active_user

from app.models.user import User

from app.services.notification_service import (
    get_notifications,
    get_unread_count,
    mark_read,
    mark_all_read,
    delete_notification,
)


router = APIRouter(
    prefix="/notifications",
    tags=["notifications"],
)


MAX_NOTIFICATION_PAGE_SIZE = 100


@router.get(
    "",
    response_model=list[NotificationResponse],
)
def read_notifications(
    page: int = Query(
        1,
        ge=1,
    ),
    size: int = Query(
        50,
        ge=1,
        le=MAX_NOTIFICATION_PAGE_SIZE,
    ),
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return get_notifications(
        db,
        current_user.user_id,
        page=page,
        size=size,
    )


@router.get(
    "/unread-count",
    response_model=NotificationUnreadCount,
)
def read_unread_count(
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return {
        "unread_count": get_unread_count(
            db,
            current_user.user_id,
        )
    }


@router.put("/read-all")
def mark_all_notifications_read(
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    count = mark_all_read(
        db,
        current_user.user_id,
    )

    return {
        "message": (
            "All notifications marked as read."
        ),
        "updated_count": count,
    }


@router.put("/{id}/read")
def mark_notification_read(
    id: uuid.UUID,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    notification = mark_read(
        db,
        id,
        current_user.user_id,
    )

    return {
        "message": (
            "Notification marked as read."
        ),
        "notification_id": (
            notification.notification_id
        ),
    }


@router.delete("/{id}")
def remove_notification(
    id: uuid.UUID,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return delete_notification(
        db,
        id,
        current_user.user_id,
    )