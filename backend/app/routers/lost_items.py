import uuid
from typing import List, Optional

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Query,
    UploadFile,
)
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_active_user
from app.database import get_db
from app.models.lost_item import LostItem
from app.models.user import User
from app.routers.uploads import upload_image
from app.schemas.lost_item import (
    LostItemCreate,
    LostItemResponse,
    LostItemUpdate,
)
from app.services.lost_item_service import (
    create_lost_item,
    delete_lost_item,
    get_lost_item,
    get_lost_items,
    mark_recovered,
    update_embedding,
    update_lost_item,
)


router = APIRouter(
    prefix="/lost-items",
    tags=["lost-items"],
)


VALID_STATUSES = {
    "active",
    "matched",
    "recovered",
    "closed",
}

MAX_PHOTOS_PER_REQUEST = 5
MAX_TOTAL_PHOTOS = 10


# ============================================================
# CREATE
# ============================================================

@router.post(
    "",
    response_model=LostItemResponse,
)
def create_item(
    item: LostItemCreate,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return create_lost_item(
        db=db,
        user_id=current_user.user_id,
        data=item,
    )


# ============================================================
# LIST / SEARCH
# ============================================================

@router.get("")
def read_items(
    category: Optional[str] = Query(
        default=None,
        max_length=100,
    ),
    location: Optional[str] = Query(
        default=None,
        max_length=200,
    ),
    status: Optional[str] = Query(
        default="active",
        max_length=30,
    ),
    page: int = Query(
        default=1,
        ge=1,
    ),
    size: int = Query(
        default=20,
        ge=1,
        le=100,
    ),
    db: Session = Depends(get_db),
):
    normalized_status = (
        status.strip().lower()
        if status
        else None
    )

    if (
        normalized_status
        and normalized_status not in VALID_STATUSES
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid item status.",
        )

    filters = {
        "category": (
            category.strip()
            if category
            else None
        ),
        "location": (
            location.strip()
            if location
            else None
        ),
        "status": normalized_status,
    }

    return get_lost_items(
        db=db,
        filters=filters,
        page=page,
        size=size,
    )


# ============================================================
# GET SINGLE ITEM
# ============================================================

@router.get(
    "/{item_id}",
    response_model=LostItemResponse,
)
def read_item(
    item_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    return get_lost_item(
        db=db,
        item_id=item_id,
    )


# ============================================================
# UPDATE
# ============================================================

@router.put(
    "/{item_id}",
    response_model=LostItemResponse,
)
def update_item(
    item_id: uuid.UUID,
    data: LostItemUpdate,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return update_lost_item(
        db=db,
        item_id=item_id,
        user_id=current_user.user_id,
        data=data,
    )


# ============================================================
# DELETE
# ============================================================

@router.delete("/{item_id}")
def delete_item(
    item_id: uuid.UUID,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return delete_lost_item(
        db=db,
        item_id=item_id,
        user_id=current_user.user_id,
    )


# ============================================================
# UPLOAD PHOTOS
# ============================================================

@router.post("/{item_id}/photos")
async def add_photos(
    item_id: uuid.UUID,
    files: List[UploadFile] = File(...),
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    item = (
        db.query(LostItem)
        .filter(
            LostItem.item_id == item_id
        )
        .first()
    )

    if not item:
        raise HTTPException(
            status_code=404,
            detail="Lost item not found.",
        )

    if item.user_id != current_user.user_id:
        raise HTTPException(
            status_code=403,
            detail=(
                "You can only add photos "
                "to your own report."
            ),
        )

    if not files:
        raise HTTPException(
            status_code=400,
            detail="At least one photo is required.",
        )

    if len(files) > MAX_PHOTOS_PER_REQUEST:
        raise HTTPException(
            status_code=400,
            detail=(
                f"You can upload a maximum of "
                f"{MAX_PHOTOS_PER_REQUEST} photos "
                f"per request."
            ),
        )

    existing_photos = item.photos or []

    if (
        len(existing_photos) + len(files)
        > MAX_TOTAL_PHOTOS
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                f"A report can contain a maximum of "
                f"{MAX_TOTAL_PHOTOS} photos."
            ),
        )

    uploaded_urls: List[str] = []

    # Keep the first successfully uploaded image bytes
    # so we can generate the AI image embedding.
    first_image_bytes = None

    try:
        for file in files:
            if not file.filename:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid file.",
                )

            image_bytes = await file.read()

            if not image_bytes:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f"File '{file.filename}' "
                        f"is empty."
                    ),
                )

            if first_image_bytes is None:
                first_image_bytes = image_bytes

            # Reset file position because upload_image()
            # reads the UploadFile itself.
            await file.seek(0)

            result = await upload_image(file)

            url = result.get("url")

            if not url:
                raise HTTPException(
                    status_code=500,
                    detail=(
                        "Image upload did not return "
                        "a valid URL."
                    ),
                )

            uploaded_urls.append(str(url))

        item.photos = (
            existing_photos + uploaded_urls
        )

        db.commit()
        db.refresh(item)

    except HTTPException:
        db.rollback()
        raise

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to upload photos.",
        )

    # ========================================================
    # AI IMAGE EMBEDDING
    # ========================================================

    # Generate the actual visual embedding from the first
    # uploaded photo. This is deliberately separate from
    # the text embedding/matching system.
    if first_image_bytes:
        try:
            from app.ai.embedding_service import (
                embedding_service,
            )

            image_embedding = (
                embedding_service.embed_image(
                    first_image_bytes
                )
            )

            if image_embedding:
                update_embedding(
                    db=db,
                    item_id=item.item_id,
                    embedding=image_embedding,
                )

                # Generate new lost/found matches now that
                # an actual image embedding exists.
                try:
                    from app.services.match_service import (
                        generate_matches_for_lost_item,
                    )

                    generate_matches_for_lost_item(
                        db,
                        item.item_id,
                    )

                except Exception:
                    # AI matching must never make a successful
                    # photo upload fail.
                    pass

        except Exception:
            # Image embedding is an enhancement. The photo
            # itself has already been successfully uploaded.
            pass

    return {
        "message": "Photos uploaded successfully.",
        "item_id": str(item.item_id),
        "photos": item.photos or [],
        "image_embedding_generated": bool(
            item.image_embedding
        ),
    }


# ============================================================
# UPDATE STATUS
# ============================================================

@router.put("/{item_id}/status")
def update_status(
    item_id: uuid.UUID,
    status: str = Query(
        ...,
        min_length=1,
        max_length=30,
    ),
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    normalized_status = (
        status.strip().lower()
    )

    if normalized_status not in VALID_STATUSES:
        raise HTTPException(
            status_code=400,
            detail="Invalid item status.",
        )

    if normalized_status == "recovered":
        return mark_recovered(
            db=db,
            item_id=item_id,
            user_id=current_user.user_id,
        )

    return update_lost_item(
        db=db,
        item_id=item_id,
        user_id=current_user.user_id,
        data=LostItemUpdate(
            status=normalized_status,
        ),
    )


# ============================================================
# MARK RECOVERED
# ============================================================

@router.post("/{item_id}/recover")
def recover_item(
    item_id: uuid.UUID,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return mark_recovered(
        db=db,
        item_id=item_id,
        user_id=current_user.user_id,
    )