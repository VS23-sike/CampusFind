import uuid
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_

from app.models.message import Message
from app.models.user import User
from app.models.claim import Claim
from app.models.blocked_user import BlockedUser
from app.models.lost_item import LostItem
from app.models.found_item import FoundItem
from app.models.notification import Notification
from app.models.match import Match


MAX_MESSAGE_LENGTH = 2000


# ============================================================================
# USER HELPERS
# ============================================================================

def _ensure_active_user(user: User) -> None:
    status = getattr(user.account_status, "value", user.account_status)

    if str(status).lower() != "active":
        raise HTTPException(
            status_code=403,
            detail="Account is not active",
        )


def _get_user(db: Session, user_id):
    user = (
        db.query(User)
        .filter(User.user_id == user_id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    return user


# ============================================================================
# BLOCKING
# ============================================================================

def _is_blocked(
    db: Session,
    user_a_id,
    user_b_id,
) -> bool:
    return (
        db.query(BlockedUser)
        .filter(
            or_(
                and_(
                    BlockedUser.blocker_id == user_a_id,
                    BlockedUser.blocked_id == user_b_id,
                ),
                and_(
                    BlockedUser.blocker_id == user_b_id,
                    BlockedUser.blocked_id == user_a_id,
                ),
            )
        )
        .first()
        is not None
    )


# ============================================================================
# ITEM TYPE
# ============================================================================

def _normalise_item_type(item_type) -> Optional[str]:
    if item_type is None:
        return None

    value = str(item_type).strip().lower()

    aliases = {
        "found": "found",
        "found_item": "found",
        "found-item": "found",
        "founditem": "found",
        "lost": "lost",
        "lost_item": "lost",
        "lost-item": "lost",
        "lostitem": "lost",
    }

    return aliases.get(value)


# ============================================================================
# EXACT APPROVED CLAIM
# ============================================================================

def _has_approved_claim_for_exact_pair(
    db: Session,
    current_user_id,
    receiver_id,
    lost_item_id,
    found_item_id,
) -> bool:
    """
    Exact relationship required:

        current user
             |
             v
        owns LostItem
             |
             v
          Match
        /       \
      lost     found
                 |
                 v
             FoundItem
                 |
                 v
             receiver

    AND

    The current user must have an APPROVED CLAIM
    for the exact FOUND item.
    """

    if not lost_item_id or not found_item_id:
        return False

    # ------------------------------------------------------------------------
    # 1. Current user must own the exact lost item.
    # ------------------------------------------------------------------------

    lost_item = (
        db.query(LostItem)
        .filter(
            LostItem.item_id == lost_item_id,
            LostItem.user_id == current_user_id,
        )
        .first()
    )

    if not lost_item:
        return False

    # ------------------------------------------------------------------------
    # 2. Receiver must be the finder of the exact found item.
    # ------------------------------------------------------------------------

    found_item = (
        db.query(FoundItem)
        .filter(
            FoundItem.item_id == found_item_id,
            FoundItem.finder_id == receiver_id,
        )
        .first()
    )

    if not found_item:
        return False

    # ------------------------------------------------------------------------
    # 3. Exact AI match must connect these two items.
    # ------------------------------------------------------------------------

    match = (
        db.query(Match)
        .filter(
            Match.lost_item_id == lost_item_id,
            Match.found_item_id == found_item_id,
        )
        .first()
    )

    if not match:
        return False

    # ------------------------------------------------------------------------
    # 4. IMPORTANT:
    #
    # Claims are stored against the FOUND item.
    #
    # Your real database payload confirms:
    #
    # item_id    = found item ID
    # item_type  = found
    # claimant_id = lost owner
    # status     = approved
    # ------------------------------------------------------------------------

    approved_claim = (
        db.query(Claim)
        .filter(
            Claim.item_id == found_item_id,
            Claim.item_type == "found",
            Claim.claimant_id == current_user_id,
            Claim.status == "approved",
        )
        .first()
    )

    if not approved_claim:
        return False

    return True


# ============================================================================
# ITEM ACCESS
# ============================================================================

def _validate_item_access(
    db: Session,
    current_user: User,
    receiver: User,
    item_id,
    item_type,
) -> None:

    # General user-to-user message.
    if not item_id:
        return

    normalized_type = _normalise_item_type(item_type)

    if normalized_type is None:
        raise HTTPException(
            status_code=400,
            detail="Invalid item type. Expected 'lost' or 'found'.",
        )

    # =========================================================================
    # FOUND ITEM
    # =========================================================================

    if normalized_type == "found":

        found_item = (
            db.query(FoundItem)
            .filter(
                FoundItem.item_id == item_id,
            )
            .first()
        )

        if not found_item:
            raise HTTPException(
                status_code=404,
                detail="Found item not found",
            )

        finder_id = found_item.finder_id

        # ---------------------------------------------------------------------
        # FINDER REPLY
        #
        # The finder is allowed to reply to a conversation about their
        # own found item.
        # ---------------------------------------------------------------------

        if finder_id == current_user.user_id:

            # Receiver must be someone who is actually connected to this
            # found item through an approved claim.
            approved_claim = (
                db.query(Claim)
                .filter(
                    Claim.item_id == found_item.item_id,
                    Claim.item_type == "found",
                    Claim.claimant_id == receiver.user_id,
                    Claim.status == "approved",
                )
                .first()
            )

            if not approved_claim:
                raise HTTPException(
                    status_code=403,
                    detail="You can only reply to an approved claimant for this item.",
                )

            return

        # ---------------------------------------------------------------------
        # LOST OWNER -> FINDER
        # ---------------------------------------------------------------------

        if finder_id != receiver.user_id:
            raise HTTPException(
                status_code=403,
                detail=(
                    "Messages about this found item can only be sent "
                    "to its finder."
                ),
            )

        # Find all AI matches involving this found item and a lost item
        # owned by the current user.
        candidate_matches = (
            db.query(Match)
            .join(
                LostItem,
                LostItem.item_id == Match.lost_item_id,
            )
            .filter(
                Match.found_item_id == found_item.item_id,
                LostItem.user_id == current_user.user_id,
            )
            .all()
        )

        # One of these exact matches must have an approved claim.
        for match in candidate_matches:

            if _has_approved_claim_for_exact_pair(
                db=db,
                current_user_id=current_user.user_id,
                receiver_id=receiver.user_id,
                lost_item_id=match.lost_item_id,
                found_item_id=found_item.item_id,
            ):
                return

        raise HTTPException(
            status_code=403,
            detail=(
                "Messaging about this item requires an approved claim "
                "for the exact matched found item."
            ),
        )

    # =========================================================================
    # LOST ITEM
    # =========================================================================

    if normalized_type == "lost":

        lost_item = (
            db.query(LostItem)
            .filter(
                LostItem.item_id == item_id,
            )
            .first()
        )

        if not lost_item:
            raise HTTPException(
                status_code=404,
                detail="Lost item not found",
            )

        owner_id = lost_item.user_id

        # Owner can reply about their own lost item.
        if owner_id == current_user.user_id:
            return

        if owner_id != receiver.user_id:
            raise HTTPException(
                status_code=403,
                detail=(
                    "Messages about this lost item can only be sent "
                    "to its owner."
                ),
            )

        raise HTTPException(
            status_code=403,
            detail=(
                "Messaging about this lost item requires an approved "
                "found-item claim."
            ),
        )


# ============================================================================
# SEND MESSAGE
# ============================================================================

def send_message(
    db: Session,
    sender_id,
    receiver_id,
    message_text,
    related_item_id=None,
    related_item_type=None,
):

    sender = _get_user(
        db,
        sender_id,
    )

    receiver = _get_user(
        db,
        receiver_id,
    )

    _ensure_active_user(sender)
    _ensure_active_user(receiver)

    if sender_id == receiver_id:
        raise HTTPException(
            status_code=400,
            detail="You cannot send a message to yourself",
        )

    if _is_blocked(
        db,
        sender_id,
        receiver_id,
    ):
        raise HTTPException(
            status_code=403,
            detail=(
                "Messaging is unavailable because one user "
                "has blocked the other"
            ),
        )

    if not message_text or not message_text.strip():
        raise HTTPException(
            status_code=400,
            detail="Message cannot be empty",
        )

    message_text = message_text.strip()

    if len(message_text) > MAX_MESSAGE_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"Message cannot exceed {MAX_MESSAGE_LENGTH} characters",
        )

    # Validate before creating anything.
    _validate_item_access(
        db=db,
        current_user=sender,
        receiver=receiver,
        item_id=related_item_id,
        item_type=related_item_type,
    )

    normalized_type = (
        _normalise_item_type(related_item_type)
        if related_item_type
        else None
    )

    message = Message(
        sender_id=sender_id,
        receiver_id=receiver_id,
        related_item_id=related_item_id,
        related_item_type=normalized_type,
        message_text=message_text,
        read_status=False,
        is_deleted=False,
    )

    db.add(message)
    db.flush()

    notification = Notification(
        user_id=receiver_id,
        title="New Message",
        message=f"{sender.full_name} sent you a message.",
        type="message",
        related_item_id=related_item_id,
    )

    db.add(notification)

    db.commit()
    db.refresh(message)

    return message


# ============================================================================
# GET CONVERSATIONS
# ============================================================================

def get_conversations(
    db: Session,
    current_user_id,
):

    current_user = _get_user(
        db,
        current_user_id,
    )

    _ensure_active_user(current_user)

    messages = (
        db.query(Message)
        .filter(
            or_(
                Message.sender_id == current_user_id,
                Message.receiver_id == current_user_id,
            ),
            Message.is_deleted.is_(False),
        )
        .order_by(
            Message.timestamp.desc()
        )
        .all()
    )

    conversations = {}
    blocked_cache = {}

    for message in messages:

        other_user_id = (
            message.receiver_id
            if message.sender_id == current_user_id
            else message.sender_id
        )

        if other_user_id not in blocked_cache:
            blocked_cache[other_user_id] = _is_blocked(
                db,
                current_user_id,
                other_user_id,
            )

        if blocked_cache[other_user_id]:
            continue

        key = (
            str(other_user_id),
            str(message.related_item_id)
            if message.related_item_id
            else None,
        )

        if key in conversations:
            continue

        other_user = _get_user(
            db,
            other_user_id,
        )

        unread_count = (
            db.query(Message)
            .filter(
                Message.sender_id == other_user_id,
                Message.receiver_id == current_user_id,
                Message.is_deleted.is_(False),
                Message.read_status.is_(False),
                Message.related_item_id == message.related_item_id,
            )
            .count()
        )

        conversations[key] = {
            "user_id": str(other_user.user_id),
            "name": other_user.full_name,
            "profile_photo": other_user.profile_photo,
            "item_id": (
                str(message.related_item_id)
                if message.related_item_id
                else None
            ),
            "item_type": message.related_item_type,
            "last_message": message.message_text,
            "last_message_at": message.timestamp,
            "unread_count": unread_count,
        }

    return list(conversations.values())


# ============================================================================
# GET CONVERSATION MESSAGES
# ============================================================================

def get_conversation_messages(
    db: Session,
    current_user_id,
    other_user_id,
    item_id=None,
):

    current_user = _get_user(
        db,
        current_user_id,
    )

    other_user = _get_user(
        db,
        other_user_id,
    )

    _ensure_active_user(current_user)
    _ensure_active_user(other_user)

    if current_user_id == other_user_id:
        raise HTTPException(
            status_code=400,
            detail="Cannot open a conversation with yourself",
        )

    if _is_blocked(
        db,
        current_user_id,
        other_user_id,
    ):
        raise HTTPException(
            status_code=403,
            detail="This conversation is unavailable",
        )

    query = (
        db.query(Message)
        .filter(
            or_(
                and_(
                    Message.sender_id == current_user_id,
                    Message.receiver_id == other_user_id,
                ),
                and_(
                    Message.sender_id == other_user_id,
                    Message.receiver_id == current_user_id,
                ),
            ),
            Message.is_deleted.is_(False),
        )
    )

    if item_id:
        query = query.filter(
            Message.related_item_id == item_id
        )

    return (
        query
        .order_by(Message.timestamp.asc())
        .all()
    )


# ============================================================================
# MARK CONVERSATION READ
# ============================================================================

def mark_conversation_read(
    db: Session,
    current_user_id,
    other_user_id,
    item_id=None,
):

    query = (
        db.query(Message)
        .filter(
            Message.sender_id == other_user_id,
            Message.receiver_id == current_user_id,
            Message.is_deleted.is_(False),
            Message.read_status.is_(False),
        )
    )

    if item_id:
        query = query.filter(
            Message.related_item_id == item_id
        )

    messages = query.all()

    for message in messages:
        message.read_status = True

    db.commit()

    return {
        "success": True,
        "marked_read": len(messages),
    }


# ============================================================================
# DELETE MESSAGE
# ============================================================================

def delete_message(
    db: Session,
    current_user_id,
    message_id,
):

    message = (
        db.query(Message)
        .filter(
            Message.message_id == message_id,
        )
        .first()
    )

    if not message:
        raise HTTPException(
            status_code=404,
            detail="Message not found",
        )

    if message.sender_id != current_user_id:
        raise HTTPException(
            status_code=403,
            detail="You can only delete your own messages",
        )

    message.is_deleted = True

    db.commit()

    return {
        "success": True,
        "message": "Message deleted",
    }