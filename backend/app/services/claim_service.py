import uuid
import logging
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.claim import Claim
from app.models.found_item import FoundItem
from app.models.lost_item import LostItem
from app.models.match import Match
from app.models.user import User
from app.services.notification_service import (
    send_claim_notification,
)

logger = logging.getLogger(__name__)


# ============================================================
# HELPERS
# ============================================================

def _normalize_uuid(value: Any):
    if value is None:
        return None

    if isinstance(value, uuid.UUID):
        return value

    try:
        return uuid.UUID(str(value))
    except (ValueError, TypeError, AttributeError):
        return None


def _is_admin(user: User) -> bool:
    role = getattr(user, "role", None)

    if hasattr(role, "value"):
        role = role.value

    return str(role or "").lower() == "admin"


def _get_found_item(
    db: Session,
    item_id: uuid.UUID,
):
    return (
        db.query(FoundItem)
        .filter(
            FoundItem.item_id == item_id
        )
        .first()
    )


def _get_exact_match(
    db: Session,
    lost_item_id: uuid.UUID,
    found_item_id: uuid.UUID,
):
    return (
        db.query(Match)
        .filter(
            Match.lost_item_id == lost_item_id,
            Match.found_item_id == found_item_id,
        )
        .first()
    )


def _validate_claimant_for_found_item(
    db: Session,
    claimant_id: uuid.UUID,
    found_item_id: uuid.UUID,
):
    """
    A valid claimant must:

    1. Be a real user.
    2. NOT be the finder of the found item.
    3. Own a lost-item report.
    4. Have that lost item connected to this exact
       found item through an AI match.

    Claims are stored against the FOUND item.
    """

    found_item = _get_found_item(
        db,
        found_item_id,
    )

    if not found_item:
        raise HTTPException(
            status_code=404,
            detail="Found item not found.",
        )

    # --------------------------------------------------------
    # Finder cannot claim their own found item.
    # --------------------------------------------------------

    if (
        found_item.finder_id
        and found_item.finder_id == claimant_id
    ):
        raise HTTPException(
            status_code=403,
            detail="You cannot claim an item that you reported as found.",
        )

    # --------------------------------------------------------
    # Find the claimant's lost item connected to this
    # exact found item.
    # --------------------------------------------------------

    lost_item = (
        db.query(LostItem)
        .join(
            Match,
            Match.lost_item_id == LostItem.item_id,
        )
        .filter(
            LostItem.user_id == claimant_id,
            Match.found_item_id == found_item_id,
        )
        .order_by(
            Match.similarity_score.desc()
        )
        .first()
    )

    if not lost_item:
        raise HTTPException(
            status_code=403,
            detail=(
                "You can only claim a found item when it "
                "matches one of your lost-item reports."
            ),
        )

    # --------------------------------------------------------
    # Confirm exact pair.
    # --------------------------------------------------------

    match = _get_exact_match(
        db,
        lost_item.item_id,
        found_item_id,
    )

    if not match:
        raise HTTPException(
            status_code=403,
            detail=(
                "No valid AI match exists between "
                "your lost item and this found item."
            ),
        )

    return (
        found_item,
        lost_item,
        match,
    )


# ============================================================
# CREATE CLAIM
# ============================================================

def create_claim(
    db: Session,
    current_user: User,
    item_id: uuid.UUID,
    item_type: str,
    verification_answers: dict | None = None,
    proof_description: str | None = None,
    evidence_photos: list | None = None,
):
    """
    Create a claim for a FOUND item.

    Claims are stored as:

        item_id   = found_item.item_id
        item_type = "found"

    The claimant must own the matching LOST report.
    """

    normalized_type = str(
        item_type or ""
    ).strip().lower()

    if normalized_type != "found":
        raise HTTPException(
            status_code=400,
            detail="Claims can only be submitted for found items.",
        )

    found_item_id = _normalize_uuid(item_id)

    if not found_item_id:
        raise HTTPException(
            status_code=400,
            detail="Invalid found item ID.",
        )

    (
        found_item,
        lost_item,
        match,
    ) = _validate_claimant_for_found_item(
        db,
        current_user.user_id,
        found_item_id,
    )

    # --------------------------------------------------------
    # Prevent duplicate pending/approved claims.
    # --------------------------------------------------------

    existing_claim = (
        db.query(Claim)
        .filter(
            Claim.item_id == found_item_id,
            Claim.item_type == "found",
            Claim.claimant_id == current_user.user_id,
        )
        .order_by(
            Claim.submitted_at.desc()
        )
        .first()
    )

    if existing_claim:
        status = str(
            getattr(
                existing_claim,
                "status",
                "",
            )
            or ""
        ).lower()

        if status in {
            "pending",
            "approved",
        }:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"You already have a {status} claim "
                    "for this found item."
                ),
            )

    claim = Claim(
        item_id=found_item_id,
        item_type="found",
        claimant_id=current_user.user_id,
        verification_answers=(
            verification_answers or {}
        ),
        proof_description=proof_description,
        evidence_photos=evidence_photos,
        status="pending",
    )

    db.add(claim)

    try:
        db.commit()
        db.refresh(claim)

    except Exception:
        db.rollback()

        logger.exception(
            "Unable to create claim for found item %s.",
            found_item_id,
        )

        raise HTTPException(
            status_code=500,
            detail="Unable to submit claim.",
        )

    # --------------------------------------------------------
    # Notify admins.
    # --------------------------------------------------------

    try:
        send_claim_notification(
            db=db,
            claim=claim,
            lost_item=lost_item,
            found_item=found_item,
        )
    except Exception:
        logger.exception(
            "Claim %s created but admin notification failed.",
            claim.claim_id,
        )

    return claim


# ============================================================
# GET ALL CLAIMS
# ============================================================

def get_all_claims(
    db: Session,
):
    """
    Return all claims.

    Used by the admin claims endpoints.
    """

    return (
        db.query(Claim)
        .order_by(
            Claim.submitted_at.desc()
        )
        .all()
    )


# ============================================================
# GET USER CLAIMS
# ============================================================

def get_claims_for_user(
    db: Session,
    current_user_id: uuid.UUID,
):
    """
    Return all claims belonging to the current user.
    """

    return (
        db.query(Claim)
        .filter(
            Claim.claimant_id == current_user_id
        )
        .order_by(
            Claim.submitted_at.desc()
        )
        .all()
    )


# ============================================================
# GET CLAIMS FOR USER - SINGULAR COMPATIBILITY NAME
# ============================================================

def get_claim_for_user(
    db: Session,
    current_user_id: uuid.UUID,
):
    """
    Compatibility alias used by existing router code.
    """

    return get_claims_for_user(
        db=db,
        current_user_id=current_user_id,
    )


# ============================================================
# BACKWARDS COMPATIBILITY
# ============================================================

def get_user_claims(
    db: Session,
    current_user_id: uuid.UUID,
):
    """
    Backwards-compatible alias.
    """

    return get_claims_for_user(
        db=db,
        current_user_id=current_user_id,
    )


# ============================================================
# GET SINGLE CLAIM
# ============================================================

def get_claim(
    db: Session,
    claim_id: uuid.UUID,
    current_user: User,
):
    claim = (
        db.query(Claim)
        .filter(
            Claim.claim_id == claim_id
        )
        .first()
    )

    if not claim:
        raise HTTPException(
            status_code=404,
            detail="Claim not found.",
        )

    if (
        claim.claimant_id != current_user.user_id
        and not _is_admin(current_user)
    ):
        raise HTTPException(
            status_code=403,
            detail="You are not authorized to view this claim.",
        )

    return claim


# ============================================================
# UPDATE CLAIM
# ============================================================

def update_claim(
    db: Session,
    claim_id: uuid.UUID,
    current_user: User,
    verification_answers: dict | None = None,
    proof_description: str | None = None,
    evidence_photos: list | None = None,
):
    claim = (
        db.query(Claim)
        .filter(
            Claim.claim_id == claim_id
        )
        .first()
    )

    if not claim:
        raise HTTPException(
            status_code=404,
            detail="Claim not found.",
        )

    if claim.claimant_id != current_user.user_id:
        raise HTTPException(
            status_code=403,
            detail="You can only update your own claim.",
        )

    status = str(
        getattr(
            claim,
            "status",
            "",
        )
        or ""
    ).lower()

    if status != "pending":
        raise HTTPException(
            status_code=400,
            detail="Only pending claims can be updated.",
        )

    # --------------------------------------------------------
    # Revalidate exact found/lost relationship.
    # --------------------------------------------------------

    found_item_id = _normalize_uuid(
        claim.item_id
    )

    if (
        not found_item_id
        or str(
            getattr(
                claim,
                "item_type",
                "",
            )
            or ""
        ).lower() != "found"
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid claim item.",
        )

    _validate_claimant_for_found_item(
        db,
        current_user.user_id,
        found_item_id,
    )

    if verification_answers is not None:
        claim.verification_answers = (
            verification_answers
        )

    if proof_description is not None:
        claim.proof_description = (
            proof_description
        )

    if evidence_photos is not None:
        claim.evidence_photos = (
            evidence_photos
        )

    try:
        db.commit()
        db.refresh(claim)

    except Exception:
        db.rollback()

        logger.exception(
            "Unable to update claim %s.",
            claim_id,
        )

        raise HTTPException(
            status_code=500,
            detail="Unable to update claim.",
        )

    return claim


# ============================================================
# ADMIN REVIEW CLAIM
# ============================================================

def review_claim(
    db: Session,
    claim_id: uuid.UUID,
    current_user: User,
    status: str,
    admin_notes: str | None = None,
):
    if not _is_admin(current_user):
        raise HTTPException(
            status_code=403,
            detail="Admin access required.",
        )

    normalized_status = str(
        status or ""
    ).strip().lower()

    if normalized_status not in {
        "approved",
        "rejected",
    }:
        raise HTTPException(
            status_code=400,
            detail="Claim status must be approved or rejected.",
        )

    claim = (
        db.query(Claim)
        .filter(
            Claim.claim_id == claim_id
        )
        .first()
    )

    if not claim:
        raise HTTPException(
            status_code=404,
            detail="Claim not found.",
        )

    # --------------------------------------------------------
    # Only found-item claims are valid.
    # --------------------------------------------------------

    if str(
        getattr(
            claim,
            "item_type",
            "",
        )
        or ""
    ).lower() != "found":
        raise HTTPException(
            status_code=400,
            detail="Invalid claim type.",
        )

    found_item_id = _normalize_uuid(
        claim.item_id
    )

    if not found_item_id:
        raise HTTPException(
            status_code=400,
            detail="Invalid found item ID.",
        )

    # --------------------------------------------------------
    # Revalidate claimant + exact AI match.
    # --------------------------------------------------------

    (
        found_item,
        lost_item,
        match,
    ) = _validate_claimant_for_found_item(
        db,
        claim.claimant_id,
        found_item_id,
    )

    claim.status = normalized_status
    claim.admin_notes = admin_notes
    claim.reviewed_by = current_user.user_id

    if hasattr(claim, "reviewed_at"):
        from datetime import datetime

        claim.reviewed_at = datetime.utcnow()

    # --------------------------------------------------------
    # Keep item state consistent after approval.
    # --------------------------------------------------------

    if normalized_status == "approved":
        found_item.status = "matched"
        lost_item.status = "matched"

        # Match.status remains independent from Claim.status.
        #
        # Match.status = AI matching workflow
        # Claim.status = claim verification workflow

    try:
        db.commit()
        db.refresh(claim)

    except Exception:
        db.rollback()

        logger.exception(
            "Unable to review claim %s.",
            claim_id,
        )

        raise HTTPException(
            status_code=500,
            detail="Unable to review claim.",
        )

    # --------------------------------------------------------
    # Notify claimant.
    # --------------------------------------------------------

    try:
        send_claim_notification(
            db=db,
            claim=claim,
            lost_item=lost_item,
            found_item=found_item,
        )
    except Exception:
        logger.exception(
            "Claim %s reviewed but claimant notification failed.",
            claim.claim_id,
        )

    return claim
