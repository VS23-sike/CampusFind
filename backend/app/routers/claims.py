import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.auth.jwt import (
    get_current_active_user,
    require_admin,
)

from app.models.user import User

from app.schemas.claim import (
    ClaimCreate,
    ClaimResponse,
    ClaimUpdate,
    ClaimReview,
    AdminClaimView,
)

from app.services.claim_service import (
    create_claim,
    get_claims_for_user,
    get_claim_for_user,
    update_claim,
    get_all_claims,
    review_claim,
)


router = APIRouter(
    prefix="/claims",
    tags=["claims"],
)


@router.post(
    "",
    response_model=ClaimResponse,
)
def create_new_claim(
    data: ClaimCreate,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return create_claim(
        db,
        current_user.user_id,
        data,
    )


@router.get(
    "",
    response_model=list[ClaimResponse],
)
def get_user_claims(
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return get_claims_for_user(
        db,
        current_user.user_id,
    )


@router.get(
    "/admin/all",
    response_model=list[AdminClaimView],
)
def get_all_claims_for_admin(
    current_user: User = Depends(
        require_admin
    ),
    db: Session = Depends(get_db),
):
    return get_all_claims(db)


@router.get(
    "/{claim_id}",
    response_model=ClaimResponse,
)
def get_single_claim(
    claim_id: uuid.UUID,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return get_claim_for_user(
        db,
        claim_id,
        current_user.user_id,
    )


@router.put(
    "/{claim_id}",
    response_model=ClaimResponse,
)
def update_existing_claim(
    claim_id: uuid.UUID,
    data: ClaimUpdate,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return update_claim(
        db=db,
        claim_id=claim_id,
        user_id=current_user.user_id,
        proof_description=data.proof_description,
        verification_answers=data.verification_answers,
    )


@router.put(
    "/{claim_id}/review",
    response_model=AdminClaimView,
)
def review_existing_claim(
    claim_id: uuid.UUID,
    data: ClaimReview,
    current_user: User = Depends(
        require_admin
    ),
    db: Session = Depends(get_db),
):
    return review_claim(
        db=db,
        claim_id=claim_id,
        admin_id=current_user.user_id,
        status=data.status,
        notes=data.admin_notes,
    )