import logging
import uuid
from datetime import date, datetime
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.ai.embedding_service import embedding_service
from app.config import settings
from app.models.found_item import FoundItem
from app.models.lost_item import LostItem
from app.models.match import Match
from app.services.notification_service import send_match_notification
from app.utils.haversine import (
    haversine_distance,
    location_proximity_score,
)
from app.utils.text_utils import fuzzy_similarity


logger = logging.getLogger(__name__)


MATCH_THRESHOLD = settings.AI_MATCH_THRESHOLD
MAX_MATCH_RESULTS = 500
MAX_USER_MATCHES = 200


def _clean(value: Any) -> str:
    if value is None:
        return ""

    return str(value).strip()


def _has_value(value: Any) -> bool:
    return bool(_clean(value))


def _has_embedding(value: Any) -> bool:
    if value is None:
        return False

    try:
        if not isinstance(value, (list, tuple)):
            return False

        return len(value) > 0

    except (TypeError, AttributeError):
        return False


def _safe_similarity(
    first: Any,
    second: Any,
) -> float:
    first = _clean(first)
    second = _clean(second)

    if not first or not second:
        return 0.0

    try:
        score = float(
            fuzzy_similarity(
                first,
                second,
            )
        )

        return max(
            0.0,
            min(1.0, score),
        )

    except Exception:
        return 0.0


def _build_item_text(item) -> str:
    values = [
        getattr(item, "title", None),
        getattr(item, "description", None),
        getattr(item, "identifying_features", None),
        getattr(item, "category", None),
        getattr(item, "subcategory", None),
        getattr(item, "color", None),
        getattr(item, "brand", None),
        getattr(item, "model", None),
        getattr(item, "material", None),
    ]

    return " ".join(
        _clean(value)
        for value in values
        if _has_value(value)
    )


def _build_core_text(item) -> str:
    values = [
        getattr(item, "title", None),
        getattr(item, "description", None),
        getattr(item, "identifying_features", None),
    ]

    return " ".join(
        _clean(value)
        for value in values
        if _has_value(value)
    )


def _get_latitude(item):
    value = getattr(
        item,
        "latitude",
        None,
    )

    if value is None:
        value = getattr(
            item,
            "lat",
            None,
        )

    return value


def _get_longitude(item):
    value = getattr(
        item,
        "longitude",
        None,
    )

    if value is None:
        value = getattr(
            item,
            "long",
            None,
        )

    return value


def _build_location_text(item) -> str:
    values = [
        getattr(item, "location_name", None),
        getattr(item, "campus_building", None),
        getattr(item, "floor", None),
        getattr(item, "nearby_landmark", None),
    ]

    return " ".join(
        _clean(value)
        for value in values
        if _has_value(value)
    )


def _calculate_location_similarity(
    lost_item,
    found_item,
):
    lost_lat = _get_latitude(lost_item)
    lost_lng = _get_longitude(lost_item)

    found_lat = _get_latitude(found_item)
    found_lng = _get_longitude(found_item)

    coordinates_available = all(
        value is not None
        for value in (
            lost_lat,
            lost_lng,
            found_lat,
            found_lng,
        )
    )

    if coordinates_available:
        try:
            distance = haversine_distance(
                float(lost_lat),
                float(lost_lng),
                float(found_lat),
                float(found_lng),
            )

            score = location_proximity_score(
                distance
            )

            return (
                max(
                    0.0,
                    min(
                        1.0,
                        float(score),
                    ),
                ),
                True,
            )

        except Exception:
            pass

    lost_location = _build_location_text(
        lost_item
    )

    found_location = _build_location_text(
        found_item
    )

    if not lost_location or not found_location:
        return 0.0, False

    return (
        _safe_similarity(
            lost_location,
            found_location,
        ),
        True,
    )


def _to_date(value):
    if value is None:
        return None

    if isinstance(value, datetime):
        return value.date()

    if isinstance(value, date):
        return value

    return None


def _calculate_date_similarity(
    lost_item,
    found_item,
):
    lost_date = _to_date(
        getattr(
            lost_item,
            "date_lost",
            None,
        )
    )

    found_date = _to_date(
        getattr(
            found_item,
            "date_found",
            None,
        )
    )

    if not lost_date or not found_date:
        return 0.0, False

    try:
        days_difference = abs(
            (found_date - lost_date).days
        )

        if days_difference <= 3:
            return 1.0, True

        if days_difference <= 14:
            return (
                max(
                    0.0,
                    1.0 - (
                        days_difference / 14.0
                    ),
                ),
                True,
            )

        return 0.0, True

    except Exception:
        return 0.0, False


# ============================================================
# MATCH SCORE
# ============================================================

def compute_match_score(
    lost_item,
    found_item,
):
    """
    Calculate an explainable AI-assisted similarity score.

    AI matching is only a suggestion and is never proof
    of ownership.
    """

    lost_text = _build_item_text(
        lost_item
    )

    found_text = _build_item_text(
        found_item
    )

    lost_core = _build_core_text(
        lost_item
    )

    found_core = _build_core_text(
        found_item
    )

    # --------------------------------------------------------
    # TEXT SIMILARITY
    # --------------------------------------------------------

    try:
        semantic_similarity = (
            embedding_service.compute_text_similarity(
                lost_text,
                found_text,
            )
        )
    except Exception:
        semantic_similarity = 0.0

    semantic_similarity = max(
        0.0,
        min(
            1.0,
            float(
                semantic_similarity or 0.0
            ),
        ),
    )

    lexical_similarity = _safe_similarity(
        lost_core,
        found_core,
    )

    text_similarity = (
        semantic_similarity * 0.65
        + lexical_similarity * 0.35
    )

    text_similarity = max(
        0.0,
        min(
            1.0,
            text_similarity,
        ),
    )

    # --------------------------------------------------------
    # IMAGE SIMILARITY
    # --------------------------------------------------------

    image_similarity = 0.0
    has_image_similarity = False

    lost_embedding = getattr(
        lost_item,
        "image_embedding",
        None,
    )

    found_embedding = getattr(
        found_item,
        "image_embedding",
        None,
    )

    if (
        _has_embedding(lost_embedding)
        and _has_embedding(found_embedding)
    ):
        try:
            image_similarity = (
                embedding_service.compute_image_similarity(
                    lost_embedding,
                    found_embedding,
                )
            )

            image_similarity = max(
                0.0,
                min(
                    1.0,
                    float(
                        image_similarity or 0.0
                    ),
                ),
            )

            has_image_similarity = (
                image_similarity > 0.0
            )

        except Exception:
            image_similarity = 0.0
            has_image_similarity = False

    # --------------------------------------------------------
    # CATEGORY
    # --------------------------------------------------------

    lost_category = _clean(
        getattr(
            lost_item,
            "category",
            None,
        )
    )

    found_category = _clean(
        getattr(
            found_item,
            "category",
            None,
        )
    )

    category_similarity = _safe_similarity(
        lost_category,
        found_category,
    )

    if (
        lost_category
        and found_category
        and lost_category.lower()
        == found_category.lower()
    ):
        category_similarity = 1.0

    # --------------------------------------------------------
    # COLOR
    # --------------------------------------------------------

    lost_color = getattr(
        lost_item,
        "color",
        None,
    )

    found_color = getattr(
        found_item,
        "color",
        None,
    )

    color_available = (
        _has_value(lost_color)
        and _has_value(found_color)
    )

    color_similarity = _safe_similarity(
        lost_color,
        found_color,
    )

    # --------------------------------------------------------
    # BRAND
    # --------------------------------------------------------

    lost_brand = getattr(
        lost_item,
        "brand",
        None,
    )

    found_brand = getattr(
        found_item,
        "brand",
        None,
    )

    brand_available = (
        _has_value(lost_brand)
        and _has_value(found_brand)
    )

    brand_similarity = _safe_similarity(
        lost_brand,
        found_brand,
    )

    # --------------------------------------------------------
    # LOCATION
    # --------------------------------------------------------

    (
        location_similarity,
        location_available,
    ) = _calculate_location_similarity(
        lost_item,
        found_item,
    )

    # --------------------------------------------------------
    # DATE
    # --------------------------------------------------------

    (
        date_similarity,
        date_available,
    ) = _calculate_date_similarity(
        lost_item,
        found_item,
    )

    # --------------------------------------------------------
    # WEIGHTED SCORE
    # --------------------------------------------------------

    score = text_similarity * 0.50
    total_weight = 0.50

    if has_image_similarity:
        score += image_similarity * 0.20
        total_weight += 0.20

    score += category_similarity * 0.10
    total_weight += 0.10

    if color_available:
        score += color_similarity * 0.08
        total_weight += 0.08

    if brand_available:
        score += brand_similarity * 0.04
        total_weight += 0.04

    if location_available:
        score += location_similarity * 0.05
        total_weight += 0.05

    if date_available:
        score += date_similarity * 0.03
        total_weight += 0.03

    final_score = (
        score / total_weight
        if total_weight > 0
        else 0.0
    )

    final_score = round(
        max(
            0.0,
            min(
                1.0,
                final_score,
            ),
        ),
        4,
    )

    # --------------------------------------------------------
    # EXPLAINABLE FEATURES
    # --------------------------------------------------------

    matching_features = []

    if text_similarity >= 0.85:
        matching_features.append(
            "Very similar item description"
        )
    elif text_similarity >= 0.65:
        matching_features.append(
            "Similar item description"
        )
    elif text_similarity >= 0.45:
        matching_features.append(
            "Some item description similarity"
        )

    if has_image_similarity:
        if image_similarity >= 0.80:
            matching_features.append(
                "Strong image similarity"
            )
        elif image_similarity >= 0.60:
            matching_features.append(
                "Similar item appearance"
            )

    if category_similarity >= 0.80:
        matching_features.append(
            "Same category"
        )

    if color_available:
        if color_similarity >= 0.85:
            matching_features.append(
                "Same or very similar color"
            )
        elif color_similarity >= 0.65:
            matching_features.append(
                "Similar color"
            )

    if (
        brand_available
        and brand_similarity >= 0.75
    ):
        matching_features.append(
            "Same or similar brand"
        )

    if location_available:
        if location_similarity >= 0.80:
            matching_features.append(
                "Very close location"
            )
        elif location_similarity >= 0.60:
            matching_features.append(
                "Nearby location"
            )

    if (
        date_available
        and date_similarity >= 0.70
    ):
        matching_features.append(
            "Close report dates"
        )

    if (
        not matching_features
        and final_score >= MATCH_THRESHOLD
    ):
        matching_features.append(
            "General item similarity detected"
        )

    return {
        "total": final_score,
        "image": round(
            image_similarity,
            4,
        ),
        "appearance": round(
            text_similarity,
            4,
        ),
        "ai_text": round(
            semantic_similarity,
            4,
        ),
        "description": round(
            lexical_similarity,
            4,
        ),
        "category": round(
            category_similarity,
            4,
        ),
        "color": round(
            color_similarity,
            4,
        ),
        "brand": round(
            brand_similarity,
            4,
        ),
        "location": round(
            location_similarity,
            4,
        ),
        "date": round(
            date_similarity,
            4,
        ),
        "matching_features": matching_features,
        "percentage": round(
            final_score * 100
        ),
        "is_suggestion": True,
        "warning": (
            "AI matching is only a suggestion "
            "and is not proof of ownership."
        ),
    }


# ============================================================
# MATCH CREATION
# ============================================================

def _create_match(
    db: Session,
    lost_item,
    found_item,
):
    existing = (
        db.query(Match)
        .filter(
            Match.lost_item_id
            == lost_item.item_id,
            Match.found_item_id
            == found_item.item_id,
        )
        .first()
    )

    if existing:
        return None

    scores = compute_match_score(
        lost_item,
        found_item,
    )

    if scores["total"] < MATCH_THRESHOLD:
        return None

    match = Match(
        lost_item_id=lost_item.item_id,
        found_item_id=found_item.item_id,
        similarity_score=scores["total"],
        image_similarity=scores["image"],
        category_similarity=scores["category"],
        color_similarity=scores["color"],
        brand_similarity=scores["brand"],
        location_proximity=scores["location"],
        date_proximity=scores["date"],
        matching_features={
            "features": scores[
                "matching_features"
            ],
            "percentage": scores[
                "percentage"
            ],
            "components": {
                "image": scores["image"],
                "appearance": scores["appearance"],
                "ai_text": scores["ai_text"],
                "description": scores["description"],
                "category": scores["category"],
                "color": scores["color"],
                "brand": scores["brand"],
                "location": scores["location"],
                "date": scores["date"],
            },
            "is_suggestion": True,
            "warning": scores[
                "warning"
            ],
        },
        status="pending",
    )

    db.add(match)

    return match


# ============================================================
# MATCH NOTIFICATION
# ============================================================

def _send_match_notification_safely(
    db: Session,
    lost_item,
    found_item,
    match,
):
    """
    Send the match notification without allowing a notification
    failure to break or hide a successfully-created AI match.
    """

    try:
        send_match_notification(
            db=db,
            lost_item=lost_item,
            found_item=found_item,
            match=match,
        )

        logger.info(
            "AI match notification created for lost item %s "
            "and match %s.",
            lost_item.item_id,
            match.match_id,
        )

        return True

    except Exception:
        logger.exception(
            "AI match was created but notification failed. "
            "lost_item=%s found_item=%s match=%s",
            lost_item.item_id,
            found_item.item_id,
            match.match_id,
        )

        return False


# ============================================================
# GENERATE MATCHES — LOST ITEM
# ============================================================

def generate_matches_for_lost_item(
    db: Session,
    lost_item_id: uuid.UUID,
):
    lost_item = (
        db.query(LostItem)
        .filter(
            LostItem.item_id
            == lost_item_id
        )
        .first()
    )

    if not lost_item:
        return []

    if lost_item.status != "active":
        return []

    found_items = (
        db.query(FoundItem)
        .filter(
            FoundItem.status.in_(
                [
                    "active",
                    "matched",
                ]
            ),
            # IMPORTANT:
            # Never create a match between a user's own
            # lost report and their own found report.
            FoundItem.finder_id
            != lost_item.user_id,
        )
        .limit(MAX_MATCH_RESULTS)
        .all()
    )

    matches = []

    for found_item in found_items:
        match = _create_match(
            db,
            lost_item,
            found_item,
        )

        if match:
            matches.append(match)

    try:
        db.commit()

    except Exception:
        db.rollback()

        logger.exception(
            "Unable to commit AI matches for lost item %s.",
            lost_item_id,
        )

        return []

    # Notifications happen only after the match transaction
    # has successfully committed.
    for match in matches:
        try:
            db.refresh(match)

            found_item = (
                db.query(FoundItem)
                .filter(
                    FoundItem.item_id
                    == match.found_item_id
                )
                .first()
            )

            if found_item:
                _send_match_notification_safely(
                    db=db,
                    lost_item=lost_item,
                    found_item=found_item,
                    match=match,
                )

        except Exception:
            logger.exception(
                "Unable to process notification for AI match %s.",
                match.match_id,
            )

    return matches


# ============================================================
# GENERATE MATCHES — FOUND ITEM
# ============================================================

def generate_matches_for_found_item(
    db: Session,
    found_item_id: uuid.UUID,
):
    found_item = (
        db.query(FoundItem)
        .filter(
            FoundItem.item_id
            == found_item_id
        )
        .first()
    )

    if not found_item:
        return []

    if found_item.status not in {
        "active",
        "matched",
    }:
        return []

    lost_items = (
        db.query(LostItem)
        .filter(
            LostItem.status == "active",
            # IMPORTANT:
            # Never create a match between a user's own
            # found report and their own lost report.
            LostItem.user_id
            != found_item.finder_id,
        )
        .limit(MAX_MATCH_RESULTS)
        .all()
    )

    matches = []

    for lost_item in lost_items:
        match = _create_match(
            db,
            lost_item,
            found_item,
        )

        if match:
            matches.append(match)

    try:
        db.commit()

    except Exception:
        db.rollback()

        logger.exception(
            "Unable to commit AI matches for found item %s.",
            found_item_id,
        )

        return []

    # Notifications happen only after the match transaction
    # has successfully committed.
    for match in matches:
        try:
            db.refresh(match)

            lost_item = (
                db.query(LostItem)
                .filter(
                    LostItem.item_id
                    == match.lost_item_id
                )
                .first()
            )

            if lost_item:
                _send_match_notification_safely(
                    db=db,
                    lost_item=lost_item,
                    found_item=found_item,
                    match=match,
                )

        except Exception:
            logger.exception(
                "Unable to process notification for AI match %s.",
                match.match_id,
            )

    return matches


# ============================================================
# USER MATCHES
# ============================================================

def get_matches_for_user(
    db: Session,
    user_id: uuid.UUID,
):
    lost_matches = (
        db.query(Match)
        .join(
            LostItem,
            Match.lost_item_id
            == LostItem.item_id,
        )
        .filter(
            LostItem.user_id == user_id,
            Match.dismissed_by_lost_user.is_(
                False
            ),
        )
        .order_by(
            Match.similarity_score.desc()
        )
        .limit(MAX_USER_MATCHES)
        .all()
    )

    found_matches = (
        db.query(Match)
        .join(
            FoundItem,
            Match.found_item_id
            == FoundItem.item_id,
        )
        .filter(
            FoundItem.finder_id == user_id,
            Match.dismissed_by_found_user.is_(
                False
            ),
        )
        .order_by(
            Match.similarity_score.desc()
        )
        .limit(MAX_USER_MATCHES)
        .all()
    )

    matches_by_id = {
        match.match_id: match
        for match in (
            lost_matches
            + found_matches
        )
    }

    matches = list(
        matches_by_id.values()
    )

    matches.sort(
        key=lambda match: (
            match.similarity_score or 0
        ),
        reverse=True,
    )

    return matches[:MAX_USER_MATCHES]


# ============================================================
# DISMISS MATCH
# ============================================================

def dismiss_match(
    db: Session,
    match_id: uuid.UUID,
    user_id: uuid.UUID,
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
            detail="Match not found.",
        )

    lost_item = (
        db.query(LostItem)
        .filter(
            LostItem.item_id
            == match.lost_item_id
        )
        .first()
    )

    found_item = (
        db.query(FoundItem)
        .filter(
            FoundItem.item_id
            == match.found_item_id
        )
        .first()
    )

    authorized = False

    if (
        lost_item
        and lost_item.user_id == user_id
    ):
        match.dismissed_by_lost_user = True
        authorized = True

    if (
        found_item
        and found_item.finder_id == user_id
    ):
        match.dismissed_by_found_user = True
        authorized = True

    if not authorized:
        raise HTTPException(
            status_code=403,
            detail=(
                "You are not authorized "
                "to dismiss this match."
            ),
        )

    try:
        db.commit()
        db.refresh(match)

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Unable to dismiss match.",
        )

    return match