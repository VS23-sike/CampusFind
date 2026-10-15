
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_active_user
from app.database import get_db
from app.models.user import User

from app.schemas.message import (
    MessageCreate,
    MessageResponse,
    ConversationSummary,
)

from app.services.message_service import (
    send_message,
    get_conversations,
    get_conversation_messages,
    mark_conversation_read,
    delete_message,
)


router = APIRouter(
    prefix="/messages",
    tags=["messages"],
)


# ============================================================
# SEND MESSAGE
# ============================================================

@router.post(
    "",
    response_model=MessageResponse,
)
def create_message(
    data: MessageCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    if data.receiver_id == current_user.user_id:
        raise HTTPException(
            status_code=400,
            detail="You cannot send a message to yourself.",
        )

    return send_message(
        db=db,
        sender_id=current_user.user_id,
        receiver_id=data.receiver_id,
        message_text=data.message_text,
        related_item_id=data.related_item_id,
        related_item_type=data.related_item_type,
    )


# ============================================================
# GET ALL CONVERSATIONS
#
# IMPORTANT:
# This returns ConversationSummary objects,
# NOT MessageResponse objects.
# ============================================================

@router.get(
    "/conversations",
    response_model=list[ConversationSummary],
)
def get_user_conversations(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    return get_conversations(
        db=db,
        current_user_id=current_user.user_id,
    )


# ============================================================
# GET ITEM-SPECIFIC CONVERSATION
# ============================================================

@router.get(
    "/conversations/{user_id}/{item_id}",
    response_model=list[MessageResponse],
)
def get_item_conversation(
    user_id: uuid.UUID,
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    return get_conversation_messages(
        db=db,
        current_user_id=current_user.user_id,
        other_user_id=user_id,
        item_id=item_id,
    )


# ============================================================
# GET GENERAL CONVERSATION
# ============================================================

@router.get(
    "/conversations/{user_id}",
    response_model=list[MessageResponse],
)
def get_general_conversation(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    return get_conversation_messages(
        db=db,
        current_user_id=current_user.user_id,
        other_user_id=user_id,
        item_id=None,
    )


# ============================================================
# MARK CONVERSATION AS READ
# ============================================================

@router.put(
    "/conversations/{user_id}/read",
)
def mark_messages_read(
    user_id: uuid.UUID,
    item_id: Optional[uuid.UUID] = Query(
        default=None,
    ),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    return mark_conversation_read(
        db=db,
        current_user_id=current_user.user_id,
        other_user_id=user_id,
        item_id=item_id,
    )


# ============================================================
# DELETE MESSAGE
#
# IMPORTANT:
# No MessageResponse response model here because delete_message()
# intentionally returns a simple success dictionary.
#
# Authorization is enforced inside message_service.py:
# only the original sender can delete the message.
# ============================================================

@router.delete(
    "/{message_id}",
)
def remove_message(
    message_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    return delete_message(
        db=db,
        current_user_id=current_user.user_id,
        message_id=message_id,
    )
