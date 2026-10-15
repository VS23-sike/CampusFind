import uuid
from datetime import date

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.found_item import FoundItem
from app.schemas.found_item import (
    FoundItemCreate,
    FoundItemUpdate,
)
from app.utils.pagination import paginate_query


MAX_PAGE_SIZE = 100

VALID_STATUSES = {
    "active",
    "matched",
    "claimed",
    "recovered",
    "closed",
}


def _normalize_location(value):
    if value is None:
        return None

    value = str(value).strip()

    return value if value else None


def create_found_item(
    db: Session,
    finder_id: uuid.UUID,
    data: FoundItemCreate,
):
    if data.date_found > date.today():
        raise HTTPException(
            status_code=400,
            detail="Date found cannot be in the future.",
        )

    item_dict = data.model_dump()

    if "location_name" in item_dict:
        item_dict["location_name"] = (
            _normalize_location(
                item_dict["location_name"]
            )
        )

    if not item_dict.get("location_name"):
        raise HTTPException(
            status_code=400,
            detail="Location is required.",
        )

    db_item = FoundItem(
        **item_dict,
        finder_id=finder_id,
        status="active",
    )

    try:
        # Text matching is handled dynamically by
        # match_service.
        #
        # image_embedding is reserved exclusively for
        # actual visual/image embeddings generated after
        # photo upload.

        db.add(db_item)
        db.commit()
        db.refresh(db_item)

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to create found item report.",
        )

    # Matching must never prevent report creation.
    try:
        from app.services.match_service import (
            generate_matches_for_found_item,
        )

        generate_matches_for_found_item(
            db,
            db_item.item_id,
        )

    except Exception:
        pass

    return db_item


def get_found_items(
    db: Session,
    filters: dict,
    page: int,
    size: int,
):
    page = max(1, int(page))
    size = max(
        1,
        min(
            int(size),
            MAX_PAGE_SIZE,
        ),
    )

    query = db.query(FoundItem)

    category = filters.get("category")

    if category:
        query = query.filter(
            FoundItem.category == category.strip()
        )

    status = filters.get("status")

    if status:
        requested_status = (
            str(status)
            .lower()
            .strip()
        )

        if requested_status not in VALID_STATUSES:
            raise HTTPException(
                status_code=400,
                detail="Invalid item status.",
            )

        query = query.filter(
            FoundItem.status == requested_status
        )

    location = filters.get("location")

    if location:
        location = location.strip()

        query = query.filter(
            FoundItem.location_name.ilike(
                f"%{location}%"
            )
            | FoundItem.campus_building.ilike(
                f"%{location}%"
            )
            | FoundItem.floor.ilike(
                f"%{location}%"
            )
            | FoundItem.nearby_landmark.ilike(
                f"%{location}%"
            )
        )

    items, total, pages = paginate_query(
        query,
        page,
        size,
    )

    return {
        "items": items,
        "total": total,
        "page": page,
        "size": size,
        "pages": pages,
    }


def get_found_item(
    db: Session,
    item_id: uuid.UUID,
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

    return item


def get_public_found_item(
    db: Session,
    item_id: uuid.UUID,
):
    return get_found_item(
        db,
        item_id,
    )


def update_found_item(
    db: Session,
    item_id: uuid.UUID,
    finder_id: uuid.UUID,
    data: FoundItemUpdate,
):
    item = get_found_item(
        db,
        item_id,
    )

    if item.finder_id != finder_id:
        raise HTTPException(
            status_code=403,
            detail=(
                "You are not authorized "
                "to update this item."
            ),
        )

    update_data = data.model_dump(
        exclude_unset=True,
    )

    if not update_data:
        return item

    # ========================================================
    # DATE VALIDATION
    # ========================================================

    if "date_found" in update_data:
        if update_data["date_found"] > date.today():
            raise HTTPException(
                status_code=400,
                detail="Date found cannot be in the future.",
            )

    # ========================================================
    # LOCATION VALIDATION
    # ========================================================

    if "location_name" in update_data:
        update_data["location_name"] = (
            _normalize_location(
                update_data["location_name"]
            )
        )

        if not update_data["location_name"]:
            raise HTTPException(
                status_code=400,
                detail="Location cannot be empty.",
            )

    # ========================================================
    # STATUS VALIDATION
    # ========================================================

    if "status" in update_data:
        new_status = (
            str(update_data["status"])
            .lower()
            .strip()
        )

        if new_status not in VALID_STATUSES:
            raise HTTPException(
                status_code=400,
                detail="Invalid item status.",
            )

        if new_status in {
            "claimed",
            "recovered",
            "closed",
        }:
            raise HTTPException(
                status_code=403,
                detail=(
                    "This status can only be changed "
                    "through the appropriate workflow."
                ),
            )

        update_data["status"] = new_status

    # ========================================================
    # PROTECTED FIELDS
    # ========================================================

    protected_fields = {
        "item_id",
        "finder_id",
        "created_at",
        "updated_at",
        "image_embedding",
        "photos",
    }

    for field in protected_fields:
        update_data.pop(
            field,
            None,
        )

    # ========================================================
    # APPLY UPDATE
    # ========================================================

    for key, value in update_data.items():
        setattr(
            item,
            key,
            value,
        )

    try:
        db.commit()
        db.refresh(item)

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to update found item.",
        )

    # ========================================================
    # RE-RUN MATCHING
    # ========================================================

    searchable_fields = {
        "title",
        "category",
        "subcategory",
        "description",
        "color",
        "brand",
        "model",
        "material",
        "identifying_features",
        "date_found",
        "location_name",
        "campus_building",
        "floor",
        "nearby_landmark",
    }

    searchable_changed = bool(
        searchable_fields.intersection(
            update_data.keys()
        )
    )

    if searchable_changed:
        try:
            from app.services.match_service import (
                generate_matches_for_found_item,
            )

            generate_matches_for_found_item(
                db,
                item.item_id,
            )

        except Exception:
            pass

    return item


def delete_found_item(
    db: Session,
    item_id: uuid.UUID,
    finder_id: uuid.UUID,
):
    item = get_found_item(
        db,
        item_id,
    )

    if item.finder_id != finder_id:
        raise HTTPException(
            status_code=403,
            detail=(
                "You are not authorized "
                "to delete this item."
            ),
        )

    if item.status in {
        "claimed",
        "recovered",
        "closed",
    }:
        raise HTTPException(
            status_code=400,
            detail=(
                "A claimed, recovered, or closed "
                "item cannot be deleted."
            ),
        )

    try:
        db.delete(item)
        db.commit()

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to delete found item.",
        )

    return {
        "message": (
            "Found item deleted successfully."
        ),
        "item_id": str(item_id),
    }


def update_embedding(
    db: Session,
    item_id: uuid.UUID,
    embedding: list,
):
    """
    Stores an actual visual/image embedding.

    This is called by the photo-upload flow after
    the image has been processed by the vision model.
    """

    item = get_found_item(
        db,
        item_id,
    )

    if not embedding:
        raise HTTPException(
            status_code=400,
            detail="Embedding cannot be empty.",
        )

    if not isinstance(
        embedding,
        (list, tuple),
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid image embedding.",
        )

    item.image_embedding = list(
        embedding
    )

    try:
        db.commit()
        db.refresh(item)

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to update item embedding."
            ),
        )

    return item