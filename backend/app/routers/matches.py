
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.auth.jwt import (
    get_current_active_user,
    require_admin,
)
from app.models.user import User
from app.models.match import Match
from app.models.claim import Claim
from app.models.lost_item import LostItem
from app.models.found_item import FoundItem
from app.services.match_service import (
    get_matches_for_user,
    dismiss_match,
    generate_matches_for_lost_item,
    generate_matches_for_found_item,
)

router = APIRouter(
    prefix="/matches",
    tags=["matches"],
)


def _is_admin(user: User) -> bool:
    role = getattr(user, "role", None)

    if hasattr(role, "value"):
        role = role.value

    return str(role or "").lower() == "admin"


def _user_owns_match(
    current_user: User,
    lost: LostItem | None,
    found: FoundItem | None,
) -> bool:
    user_id = str(current_user.user_id)

    return bool(
        (
            lost
            and str(lost.user_id) == user_id
        )
        or (
            found
            and str(found.finder_id) == user_id
        )
    )


def _get_claim_for_match(
    db: Session,
    lost: LostItem | None,
    found: FoundItem | None,
):
    """
    Find the claim belonging to the exact lost/found pair.

    Claims are stored against the FOUND item.

    Therefore:
        Claim.item_id      = found.item_id
        Claim.item_type    = "found"
        Claim.claimant_id  = lost.user_id

    This lets both the lost-item owner and the finder
    see the same claim status for the same match.
    """

    if not lost or not found:
        return None

    return (
        db.query(Claim)
        .filter(
            Claim.item_id == found.item_id,
            Claim.item_type == "found",
            Claim.claimant_id == lost.user_id,
        )
        .order_by(
            Claim.submitted_at.desc()
        )
        .first()
    )


def _serialize_match(
    m: Match,
    lost: LostItem | None,
    found: FoundItem | None,
    full: bool = False,
    finder: User | None = None,
    claim_status: str | None = None,
) -> dict:

    base = {
        "match_id": str(m.match_id),
        "similarity_score": m.similarity_score,
        "score_percent": round(
            (m.similarity_score or 0) * 100
        ),

        # -----------------------------------------------------
        # AI MATCH STATUS
        # -----------------------------------------------------
        # This remains independent from Claim.status.
        #
        # Example:
        # Match.status  = "pending"
        # Claim.status  = "approved"
        #
        "status": m.status,

        # -----------------------------------------------------
        # SHARED CLAIM STATUS
        # -----------------------------------------------------
        # This represents the claim attached to the exact
        # lost-item / found-item pair.
        #
        # Both users involved in the match receive this value.
        #
        "claim_status": claim_status,

        "matching_features": (
            m.matching_features or []
        ),
        "image_similarity": m.image_similarity,
        "category_similarity": (
            m.category_similarity
        ),
        "color_similarity": m.color_similarity,
        "brand_similarity": m.brand_similarity,
        "location_proximity": (
            m.location_proximity
        ),
        "date_proximity": m.date_proximity,
        "created_at": (
            m.created_at.isoformat()
            if m.created_at
            else None
        ),
    }

    # ---------------------------------------------------------
    # LOST ITEM
    # ---------------------------------------------------------

    if lost:
        lost_data = {
            "item_id": str(lost.item_id),
            "title": lost.title,
            "category": lost.category,
            "color": lost.color,
            "brand": lost.brand,
            "campus_building": (
                lost.campus_building
            ),
            "date_lost": (
                lost.date_lost.isoformat()
                if lost.date_lost
                else None
            ),
            "photos": (
                lost.photos[:1]
                if lost.photos
                else []
            ),
            "status": lost.status,
        }

        if full:
            lost_data.update({
                "subcategory": lost.subcategory,
                "description": lost.description,
                "identifying_features": (
                    lost.identifying_features
                ),
                "location_name": (
                    lost.location_name
                ),
                "approximate_time": (
                    lost.approximate_time
                ),
                "photos": lost.photos or [],
            })

        base["lost_item"] = lost_data

    else:
        base["lost_item"] = None

    # ---------------------------------------------------------
    # FOUND ITEM
    # ---------------------------------------------------------

    if found:
        found_data = {
            "item_id": str(found.item_id),
            "title": found.title,
            "category": found.category,
            "color": found.color,
            "brand": found.brand,
            "campus_building": (
                found.campus_building
            ),
            "date_found": (
                found.date_found.isoformat()
                if found.date_found
                else None
            ),
            "photos": (
                found.photos[:1]
                if found.photos
                else []
            ),
            "status": found.status,

            # -------------------------------------------------
            # FINDER IDENTITY
            # -------------------------------------------------
            # This is what Flutter needs to open the
            # correct conversation after an approved claim.
            # -------------------------------------------------

            "finder_id": (
                str(found.finder_id)
                if found.finder_id
                else None
            ),

            "finder_name": (
                finder.full_name
                if finder
                else None
            ),

            "finder_email": (
                finder.college_email
                if finder
                else None
            ),
        }

        if full:
            found_data.update({
                "description": found.description,
                "location_name": (
                    found.location_name
                ),
                "approximate_time": (
                    found.approximate_time
                ),
                "photos": found.photos or [],
            })

        base["found_item"] = found_data

    else:
        base["found_item"] = None

    return base


# ---------------------------------------------------------
# GET ALL MATCHES FOR CURRENT USER
# ---------------------------------------------------------

@router.get("")
def get_user_matches(
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    matches = get_matches_for_user(
        db,
        current_user.user_id,
    )

    result = []

    for match in matches:
        lost = (
            db.query(LostItem)
            .filter(
                LostItem.item_id
                == match.lost_item_id
            )
            .first()
        )

        found = (
            db.query(FoundItem)
            .filter(
                FoundItem.item_id
                == match.found_item_id
            )
            .first()
        )

        # -----------------------------------------------------
        # DEFENSIVE OWNERSHIP CHECK
        # -----------------------------------------------------

        if not _user_owns_match(
            current_user,
            lost,
            found,
        ):
            continue

        # -----------------------------------------------------
        # FIND THE PERSON WHO REPORTED THE FOUND ITEM
        # -----------------------------------------------------

        finder = None

        if found and found.finder_id:
            finder = (
                db.query(User)
                .filter(
                    User.user_id
                    == found.finder_id
                )
                .first()
            )

        # -----------------------------------------------------
        # FIND CLAIM FOR THIS EXACT MATCH
        # -----------------------------------------------------
        #
        # This is deliberately NOT restricted to the logged-in
        # user.
        #
        # The claim belongs to the lost-item owner, but both
        # sides of the match need to know the shared claim
        # status.
        #

        claim = _get_claim_for_match(
            db,
            lost,
            found,
        )

        claim_status = (
            str(claim.status)
            if claim and claim.status
            else None
        )

        result.append(
            _serialize_match(
                match,
                lost,
                found,
                full=False,
                finder=finder,
                claim_status=claim_status,
            )
        )

    return result


# ---------------------------------------------------------
# GENERATE MATCHES FOR LOST ITEM
# ADMIN ONLY
# ---------------------------------------------------------

@router.post("/trigger/{lost_item_id}")
def trigger_lost_matches(
    lost_item_id: uuid.UUID,
    current_user: User = Depends(
        require_admin
    ),
    db: Session = Depends(get_db),
):
    lost_item = (
        db.query(LostItem)
        .filter(
            LostItem.item_id == lost_item_id
        )
        .first()
    )

    if not lost_item:
        raise HTTPException(
            status_code=404,
            detail="Lost item not found",
        )

    matches = generate_matches_for_lost_item(
        db,
        lost_item_id,
    )

    return {
        "message": (
            f"Generated {len(matches)} matches"
        ),
        "lost_item_id": str(lost_item_id),
        "match_count": len(matches),
    }


# ---------------------------------------------------------
# GENERATE MATCHES FOR FOUND ITEM
# ADMIN ONLY
# ---------------------------------------------------------

@router.post("/trigger-found/{found_item_id}")
def trigger_found_matches(
    found_item_id: uuid.UUID,
    current_user: User = Depends(
        require_admin
    ),
    db: Session = Depends(get_db),
):
    found_item = (
        db.query(FoundItem)
        .filter(
            FoundItem.item_id == found_item_id
        )
        .first()
    )

    if not found_item:
        raise HTTPException(
            status_code=404,
            detail="Found item not found",
        )

    matches = generate_matches_for_found_item(
        db,
        found_item_id,
    )

    return {
        "message": (
            f"Generated {len(matches)} matches"
        ),
        "found_item_id": str(found_item_id),
        "match_count": len(matches),
    }


# ---------------------------------------------------------
# GET SINGLE MATCH
# ---------------------------------------------------------

@router.get("/{match_id}")
def get_match(
    match_id: uuid.UUID,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    match = (
        db.query(Match)
        .filter(
            Match.match_id == match_id
        )
        .first()
    )

    if not match:
        raise HTTPException(
            status_code=404,
            detail="Match not found",
        )

    lost = (
        db.query(LostItem)
        .filter(
            LostItem.item_id
            == match.lost_item_id
        )
        .first()
    )

    found = (
        db.query(FoundItem)
        .filter(
            FoundItem.item_id
            == match.found_item_id
        )
        .first()
    )

    if not _user_owns_match(
        current_user,
        lost,
        found,
    ) and not _is_admin(current_user):
        raise HTTPException(
            status_code=403,
            detail="Not authorized to view this match",
        )

    finder = None

    if found and found.finder_id:
        finder = (
            db.query(User)
            .filter(
                User.user_id
                == found.finder_id
            )
            .first()
        )

    # -----------------------------------------------------
    # FIND CLAIM FOR THIS EXACT MATCH
    # -----------------------------------------------------

    claim = _get_claim_for_match(
        db,
        lost,
        found,
    )

    claim_status = (
        str(claim.status)
        if claim and claim.status
        else None
    )

    return _serialize_match(
        match,
        lost,
        found,
        full=True,
        finder=finder,
        claim_status=claim_status,
    )


# ---------------------------------------------------------
# DISMISS MATCH
# ---------------------------------------------------------

@router.post("/{match_id}/dismiss")
def dismiss_user_match(
    match_id: uuid.UUID,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    match = (
        db.query(Match)
        .filter(
            Match.match_id == match_id
        )
        .first()
    )

    if not match:
        raise HTTPException(
            status_code=404,
            detail="Match not found",
        )

    lost = (
        db.query(LostItem)
        .filter(
            LostItem.item_id
            == match.lost_item_id
        )
        .first()
    )

    found = (
        db.query(FoundItem)
        .filter(
            FoundItem.item_id
            == match.found_item_id
        )
        .first()
    )

    if not _user_owns_match(
        current_user,
        lost,
        found,
    ):
        raise HTTPException(
            status_code=403,
            detail="You can only dismiss your own matches",
        )

    dismiss_match(
        db,
        match_id,
        current_user.user_id,
    )

    return {
        "message": "Match dismissed",
        "match_id": str(match_id),
    }
