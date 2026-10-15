from datetime import date
from math import asin, cos, radians, sin, sqrt
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models.lost_item import LostItem
from app.models.found_item import FoundItem

from app.utils.text_utils import (
    extract_color_from_text,
    extract_category_from_text,
    extract_location_from_text,
    parse_natural_date,
)


VALID_SORTS = {
    "newest",
    "oldest",
}

VALID_ITEM_TYPES = {
    "lost",
    "found",
    "all",
}

MAX_SEARCH_RESULTS = 100
MAX_RADIUS_KM = 10.0
MIN_RADIUS_KM = 0.1


# ============================================================
# NATURAL LANGUAGE SEARCH
# ============================================================

def extract_search_params(query: str):
    query = str(query or "").strip()

    if not query:
        return {
            "color": None,
            "category": None,
            "location": None,
            "date": None,
        }

    return {
        "color": extract_color_from_text(query),
        "category": extract_category_from_text(query),
        "location": extract_location_from_text(query),
        "date": parse_natural_date(query),
    }


# ============================================================
# KEYWORD SEARCH
# ============================================================

def _apply_keyword_search(
    query,
    model,
    text_query: Optional[str],
):
    text_query = str(text_query or "").strip()

    if not text_query:
        return query

    words = [
        word.strip()
        for word in text_query.lower().split()
        if len(word.strip()) > 1
    ]

    if not words:
        return query

    searchable_fields = [
        model.title,
        model.description,
        model.category,
        model.subcategory,
        model.color,
        model.brand,
        model.model,
        model.material,
        model.identifying_features,
        model.location_name,
        model.campus_building,
        model.floor,
        model.nearby_landmark,
    ]

    # Every meaningful word must occur somewhere in the item.
    for word in words:
        like = f"%{word}%"

        query = query.filter(
            or_(
                *[
                    field.ilike(like)
                    for field in searchable_fields
                ]
            )
        )

    return query


# ============================================================
# FILTERS
# ============================================================

def _apply_filters(
    query,
    model,
    params: dict,
):
    color = params.get("color")
    category = params.get("category")
    subcategory = params.get("subcategory")
    brand = params.get("brand")
    location = params.get("location")
    date_value = params.get("date")
    date_from = params.get("date_from")
    date_to = params.get("date_to")

    if color:
        query = query.filter(
            model.color.ilike(f"%{str(color).strip()}%")
        )

    if category:
        query = query.filter(
            model.category.ilike(
                f"%{str(category).strip()}%"
            )
        )

    if subcategory:
        query = query.filter(
            model.subcategory.ilike(
                f"%{str(subcategory).strip()}%"
            )
        )

    if brand:
        query = query.filter(
            model.brand.ilike(
                f"%{str(brand).strip()}%"
            )
        )

    if location:
        location_like = (
            f"%{str(location).strip()}%"
        )

        query = query.filter(
            or_(
                model.location_name.ilike(
                    location_like
                ),
                model.campus_building.ilike(
                    location_like
                ),
                model.floor.ilike(
                    location_like
                ),
                model.nearby_landmark.ilike(
                    location_like
                ),
            )
        )

    # --------------------------------------------------------
    # DATE FILTERS
    # --------------------------------------------------------

    date_column = (
        model.date_lost
        if model is LostItem
        else model.date_found
    )

    if date_value:
        query = query.filter(
            date_column == date_value
        )

    if date_from:
        query = query.filter(
            date_column >= date_from
        )

    if date_to:
        query = query.filter(
            date_column <= date_to
        )

    return query


# ============================================================
# SORTING
# ============================================================

def _apply_sort(
    query,
    model,
    sort: str = "newest",
):
    sort = str(
        sort or "newest"
    ).lower().strip()

    if sort not in VALID_SORTS:
        sort = "newest"

    if sort == "oldest":
        return query.order_by(
            model.created_at.asc()
        )

    return query.order_by(
        model.created_at.desc()
    )


# ============================================================
# BASE SEARCH
# ============================================================

def full_text_search(
    db: Session,
    model,
    params: Optional[dict] = None,
    text_query: Optional[str] = None,
):
    params = params or {}

    query = db.query(model)

    # Public search only shows active reports.
    query = query.filter(
        model.status == "active"
    )

    query = _apply_keyword_search(
        query,
        model,
        text_query,
    )

    query = _apply_filters(
        query,
        model,
        params,
    )

    query = _apply_sort(
        query,
        model,
        params.get("sort", "newest"),
    )

    raw_limit = params.get(
        "limit",
        MAX_SEARCH_RESULTS,
    )

    try:
        limit = int(raw_limit)
    except (TypeError, ValueError):
        limit = MAX_SEARCH_RESULTS

    limit = max(
        1,
        min(
            limit,
            MAX_SEARCH_RESULTS,
        ),
    )

    return query.limit(limit).all()


# ============================================================
# ADVANCED SEARCH
# ============================================================

def advanced_search(
    db: Session,
    query_text: Optional[str] = None,
    item_type: Optional[str] = None,
    category: Optional[str] = None,
    subcategory: Optional[str] = None,
    color: Optional[str] = None,
    brand: Optional[str] = None,
    location: Optional[str] = None,
    date_from=None,
    date_to=None,
    sort: str = "newest",
):
    item_type = (
        str(item_type).strip().lower()
        if item_type
        else "all"
    )

    if item_type not in VALID_ITEM_TYPES:
        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid item type. "
                "Use 'lost', 'found', or 'all'."
            ),
        )

    if sort not in VALID_SORTS:
        sort = "newest"

    params = {
        "category": category,
        "subcategory": subcategory,
        "color": color,
        "brand": brand,
        "location": location,
        "date_from": date_from,
        "date_to": date_to,
        "sort": sort,
    }

    if item_type == "lost":
        return {
            "lost": full_text_search(
                db,
                LostItem,
                params,
                query_text,
            ),
            "found": [],
        }

    if item_type == "found":
        return {
            "lost": [],
            "found": full_text_search(
                db,
                FoundItem,
                params,
                query_text,
            ),
        }

    return {
        "lost": full_text_search(
            db,
            LostItem,
            params,
            query_text,
        ),
        "found": full_text_search(
            db,
            FoundItem,
            params,
            query_text,
        ),
    }


# ============================================================
# SMART SEARCH
# ============================================================

def smart_search(
    db: Session,
    query_text: str,
    filters: Optional[dict] = None,
):
    filters = filters or {}

    query_text = str(
        query_text or ""
    ).strip()

    extracted = extract_search_params(
        query_text
    )

    params = {
        "color": (
            filters.get("color")
            or extracted.get("color")
        ),
        "category": (
            filters.get("category")
            or extracted.get("category")
        ),
        "location": (
            filters.get("location")
            or extracted.get("location")
        ),
        "date": extracted.get("date"),
        "date_from": filters.get(
            "date_from"
        ),
        "date_to": filters.get(
            "date_to"
        ),
        "brand": filters.get("brand"),
        "subcategory": filters.get(
            "subcategory"
        ),
        "sort": filters.get(
            "sort",
            "newest",
        ),
    }

    return {
        "lost_items": full_text_search(
            db,
            LostItem,
            params,
            query_text,
        ),
        "found_items": full_text_search(
            db,
            FoundItem,
            params,
            query_text,
        ),
        "extracted_params": params,
    }


# ============================================================
# LOCATION INTELLIGENCE
# ============================================================

def calculate_distance_km(
    latitude_1: float,
    longitude_1: float,
    latitude_2: float,
    longitude_2: float,
) -> float:
    """
    Calculate distance between two coordinates
    using the Haversine formula.
    """

    earth_radius_km = 6371.0

    lat1 = radians(float(latitude_1))
    lon1 = radians(float(longitude_1))
    lat2 = radians(float(latitude_2))
    lon2 = radians(float(longitude_2))

    delta_lat = lat2 - lat1
    delta_lon = lon2 - lon1

    haversine = (
        sin(delta_lat / 2) ** 2
        + cos(lat1)
        * cos(lat2)
        * sin(delta_lon / 2) ** 2
    )

    # Floating point operations can very slightly
    # exceed 1.0.
    haversine = max(
        0.0,
        min(1.0, haversine),
    )

    return (
        2
        * asin(sqrt(haversine))
        * earth_radius_km
    )


def _validate_coordinates(
    latitude: float,
    longitude: float,
):
    try:
        latitude = float(latitude)
        longitude = float(longitude)
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=400,
            detail="Invalid latitude or longitude.",
        )

    if not -90 <= latitude <= 90:
        raise HTTPException(
            status_code=400,
            detail="Latitude must be between -90 and 90.",
        )

    if not -180 <= longitude <= 180:
        raise HTTPException(
            status_code=400,
            detail="Longitude must be between -180 and 180.",
        )

    return latitude, longitude


def _add_distance_to_items(
    items,
    latitude: float,
    longitude: float,
):
    results = []

    for item in items:
        item_latitude = getattr(
            item,
            "latitude",
            None,
        )

        item_longitude = getattr(
            item,
            "longitude",
            None,
        )

        if (
            item_latitude is None
            or item_longitude is None
        ):
            continue

        try:
            item_latitude = float(
                item_latitude
            )
            item_longitude = float(
                item_longitude
            )

            if not (
                -90 <= item_latitude <= 90
                and -180 <= item_longitude <= 180
            ):
                continue

            distance = calculate_distance_km(
                latitude,
                longitude,
                item_latitude,
                item_longitude,
            )

            results.append(
                {
                    "item": item,
                    "distance_km": round(
                        distance,
                        3,
                    ),
                }
            )

        except (
            TypeError,
            ValueError,
        ):
            continue

    return results


# ============================================================
# NEARBY SEARCH
# ============================================================

def nearby_search(
    db: Session,
    latitude: float,
    longitude: float,
    radius_km: float = 1.0,
    item_type: Optional[str] = None,
    category: Optional[str] = None,
    query_text: Optional[str] = None,
):
    """
    Find active lost/found reports within a
    specified radius.

    Results are ordered nearest -> farthest.
    """

    latitude, longitude = _validate_coordinates(
        latitude,
        longitude,
    )

    try:
        radius_km = float(radius_km)
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=400,
            detail="Invalid radius.",
        )

    radius_km = max(
        MIN_RADIUS_KM,
        min(
            radius_km,
            MAX_RADIUS_KM,
        ),
    )

    item_type = (
        str(item_type).strip().lower()
        if item_type
        else "all"
    )

    if item_type not in VALID_ITEM_TYPES:
        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid item type. "
                "Use 'lost', 'found', or 'all'."
            ),
        )

    params = {
        "category": category,
        "sort": "newest",
        "limit": MAX_SEARCH_RESULTS,
    }

    lost_results = []
    found_results = []

    if item_type in ("all", "lost"):
        lost_items = full_text_search(
            db,
            LostItem,
            params,
            query_text,
        )

        nearby_lost = _add_distance_to_items(
            lost_items,
            latitude,
            longitude,
        )

        lost_results = [
            result
            for result in nearby_lost
            if result["distance_km"] <= radius_km
        ]

    if item_type in ("all", "found"):
        found_items = full_text_search(
            db,
            FoundItem,
            params,
            query_text,
        )

        nearby_found = _add_distance_to_items(
            found_items,
            latitude,
            longitude,
        )

        found_results = [
            result
            for result in nearby_found
            if result["distance_km"] <= radius_km
        ]

    lost_results.sort(
        key=lambda result: result["distance_km"]
    )

    found_results.sort(
        key=lambda result: result["distance_km"]
    )

    return {
        "latitude": latitude,
        "longitude": longitude,
        "radius_km": radius_km,
        "lost": [
            {
                "item": result["item"],
                "distance_km": result["distance_km"],
            }
            for result in lost_results
        ],
        "found": [
            {
                "item": result["item"],
                "distance_km": result["distance_km"],
            }
            for result in found_results
        ],
        "total": (
            len(lost_results)
            + len(found_results)
        ),
    }