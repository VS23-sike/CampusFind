from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.found_item import FoundItem
from app.models.lost_item import LostItem
from app.services.search_service import (
    advanced_search,
    full_text_search,
    nearby_search,
    smart_search,
)


router = APIRouter(
    prefix="/search",
    tags=["search"],
)


# ============================================================
# STANDARD SEARCH
# ============================================================

@router.get("")
def standard_search(
    q: str | None = Query(
        default=None,
        max_length=100,
    ),
    type: str | None = Query(
        default=None,
        pattern="^(lost|found)$",
    ),
    db: Session = Depends(get_db),
):
    search_query = q.strip() if q else None

    if type == "lost":
        return {
            "lost": full_text_search(
                db,
                LostItem,
                {},
                search_query,
            ),
            "found": [],
        }

    if type == "found":
        return {
            "lost": [],
            "found": full_text_search(
                db,
                FoundItem,
                {},
                search_query,
            ),
        }

    return {
        "lost": full_text_search(
            db,
            LostItem,
            {},
            search_query,
        ),
        "found": full_text_search(
            db,
            FoundItem,
            {},
            search_query,
        ),
    }


# ============================================================
# ADVANCED SEARCH
# ============================================================

@router.get("/advanced")
def advanced_search_endpoint(
    q: str | None = Query(
        default=None,
        max_length=100,
    ),
    type: str | None = Query(
        default=None,
        pattern="^(lost|found)$",
    ),
    category: str | None = Query(
        default=None,
        max_length=100,
    ),
    subcategory: str | None = Query(
        default=None,
        max_length=100,
    ),
    color: str | None = Query(
        default=None,
        max_length=50,
    ),
    brand: str | None = Query(
        default=None,
        max_length=100,
    ),
    location: str | None = Query(
        default=None,
        max_length=150,
    ),
    date_from: date | None = Query(default=None),
    date_to: date | None = Query(default=None),
    sort: str = Query(
        default="newest",
        pattern="^(newest|oldest)$",
    ),
    db: Session = Depends(get_db),
):
    if date_from and date_to and date_from > date_to:
        raise HTTPException(
            status_code=400,
            detail="date_from cannot be after date_to.",
        )

    return advanced_search(
        db=db,
        query_text=q.strip() if q else None,
        item_type=type,
        category=category,
        subcategory=subcategory,
        color=color,
        brand=brand,
        location=location,
        date_from=date_from,
        date_to=date_to,
        sort=sort,
    )


# ============================================================
# SEARCH SUGGESTIONS
# ============================================================

@router.get("/suggestions")
def search_suggestions(
    q: str = Query(
        default="",
        max_length=100,
    ),
    db: Session = Depends(get_db),
):
    search_text = q.strip().lower()

    if not search_text:
        return {
            "suggestions": []
        }

    suggestions = []

    # --------------------------------------------------------
    # Lost item titles
    # --------------------------------------------------------

    lost_items = (
        db.query(LostItem)
        .filter(
            LostItem.status == "active"
        )
        .filter(
            LostItem.title.ilike(
                f"%{search_text}%"
            )
        )
        .order_by(
            LostItem.created_at.desc()
        )
        .limit(5)
        .all()
    )

    for item in lost_items:
        if item.title:
            suggestions.append(
                {
                    "text": item.title,
                    "type": "lost",
                }
            )

    # --------------------------------------------------------
    # Found item titles
    # --------------------------------------------------------

    found_items = (
        db.query(FoundItem)
        .filter(
            FoundItem.status == "active"
        )
        .filter(
            FoundItem.title.ilike(
                f"%{search_text}%"
            )
        )
        .order_by(
            FoundItem.created_at.desc()
        )
        .limit(5)
        .all()
    )

    for item in found_items:
        if item.title:
            suggestions.append(
                {
                    "text": item.title,
                    "type": "found",
                }
            )

    # --------------------------------------------------------
    # Remove duplicates
    # --------------------------------------------------------

    unique = []
    seen = set()

    for suggestion in suggestions:
        key = (
            suggestion["text"].strip().lower(),
            suggestion["type"],
        )

        if key in seen:
            continue

        seen.add(key)
        unique.append(suggestion)

    return {
        "suggestions": unique[:10]
    }


# ============================================================
# SMART / NATURAL LANGUAGE SEARCH
# ============================================================

@router.get("/smart")
def nlp_search(
    q: str = Query(
        ...,
        min_length=1,
        max_length=200,
    ),
    db: Session = Depends(get_db),
):
    query_text = q.strip()

    if not query_text:
        raise HTTPException(
            status_code=400,
            detail="Search query cannot be empty.",
        )

    return smart_search(
        db,
        query_text,
        {},
    )


# ============================================================
# NEARBY / LOCATION SEARCH
# ============================================================

@router.get("/nearby")
def nearby_search_endpoint(
    latitude: float = Query(
        ...,
        ge=-90,
        le=90,
    ),
    longitude: float = Query(
        ...,
        ge=-180,
        le=180,
    ),
    radius_km: float = Query(
        default=1.0,
        ge=0.1,
        le=10.0,
    ),
    type: str | None = Query(
        default=None,
        pattern="^(lost|found)$",
    ),
    category: str | None = Query(
        default=None,
        max_length=100,
    ),
    q: str | None = Query(
        default=None,
        max_length=100,
    ),
    db: Session = Depends(get_db),
):
    return nearby_search(
        db=db,
        latitude=latitude,
        longitude=longitude,
        radius_km=radius_km,
        item_type=type,
        category=category,
        query_text=q.strip() if q else None,
    )