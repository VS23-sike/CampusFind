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
from app.models.found_item import FoundItem
from app.models.user import User
from app.routers.uploads import upload_image
from app.schemas.found_item import (
    FoundItemCreate,
    FoundItemPublic,
    FoundItemResponse,
    FoundItemUpdate,
)
from app.services.found_item_service import (
    create_found_item,
    delete_found_item,
    get_found_item,
    get_found_items,
    get_public_found_item,
    update_embedding,
    update_found_item,
)


router = APIRouter(
    prefix="/found-items",
    tags=["found-items"],
)


VALID_STATUSES = {
    "active",
    "matched",
    "claimed",
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
    response_model=FoundItemResponse,
)
def create_item(
    item: FoundItemCreate,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return create_found_item(
        db=db,
        finder_id=current_user.user_id,
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

    return get_found_items(
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
    response_model=FoundItemPublic,
)
def read_item(
    item_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    return get_public_found_item(
        db=db,
        item_id=item_id,
    )


# ============================================================
# UPDATE
# ============================================================

@router.put(
    "/{item_id}",
    response_model=FoundItemResponse,
)
def update_item(
    item_id: uuid.UUID,
    data: FoundItemUpdate,
    current_user: User = Depends(
        get_current_active_user
    ),
    db: Session = Depends(get_db),
):
    return update_found_item(
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
    return delete_found_item(
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
        db.query(FoundItem)
        .filter(
            FoundItem.item_id == item_id
        )
        .first()
    )

    if not item:
        raise HTTPException(
            status_code=404,
            detail="Found item not found.",
        )

    if item.finder_id != current_user.user_id:
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

    # Keep the first image for AI processing.
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

            # upload_image() reads the UploadFile,
            # so reset the stream after reading it.
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

                # Re-run matching now that the item has
                # an actual visual embedding.
                try:
                    from app.services.match_service import (
                        generate_matches_for_found_item,
                    )

                    generate_matches_for_found_item(
                        db,
                        item.item_id,
                    )

                except Exception:
                    # Matching failure must never make
                    # a successful photo upload fail.
                    pass

        except Exception:
            # Photo upload remains successful even if the
            # optional AI image model is unavailable.
            pass

    return {
        "message": "Photos uploaded successfully.",
        "item_id": str(item.item_id),
        "photos": item.photos or [],
        "image_embedding_generated": bool(
            item.image_embedding
        ),
    }