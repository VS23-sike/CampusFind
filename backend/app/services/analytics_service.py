from datetime import datetime, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.claim import Claim
from app.models.found_item import FoundItem
from app.models.lost_item import LostItem
from app.models.match import Match
from app.models.report import Report
from app.models.user import User


def get_dashboard_stats(db: Session):
    total_users = db.query(User).count()
    total_lost = db.query(LostItem).count()
    total_found = db.query(FoundItem).count()

    recovered_lost = (
        db.query(LostItem)
        .filter(LostItem.status == "recovered")
        .count()
    )

    recovered_found = (
        db.query(FoundItem)
        .filter(FoundItem.status == "recovered")
        .count()
    )

    total_recovered = recovered_lost + recovered_found
    total_items = total_lost + total_found

    recovery_rate = (
        (total_recovered / total_items) * 100
        if total_items > 0
        else 0.0
    )

    active_matches = (
        db.query(Match)
        .filter(Match.status == "pending")
        .count()
    )

    pending_claims = (
        db.query(Claim)
        .filter(
            Claim.status.in_(
                ["pending", "under_review", "more_info_required"]
            )
        )
        .count()
    )

    open_reports = (
        db.query(Report)
        .filter(
            Report.status.in_(
                ["pending", "reviewed"]
            )
        )
        .count()
    )

    return {
        "total_users": total_users,
        "total_lost_items": total_lost,
        "total_found_items": total_found,
        "total_recovered_items": total_recovered,
        "recovery_rate": round(recovery_rate, 2),
        "active_matches": active_matches,
        "pending_claims": pending_claims,
        "open_reports": open_reports,
    }


def get_category_breakdown(db: Session):
    lost = (
        db.query(
            LostItem.category,
            func.count(LostItem.item_id),
        )
        .group_by(LostItem.category)
        .all()
    )

    found = (
        db.query(
            FoundItem.category,
            func.count(FoundItem.item_id),
        )
        .group_by(FoundItem.category)
        .all()
    )

    return {
        "lost": [
            {
                "category": category,
                "count": count,
            }
            for category, count in lost
        ],
        "found": [
            {
                "category": category,
                "count": count,
            }
            for category, count in found
        ],
    }


def get_location_breakdown(db: Session):
    lost = (
        db.query(
            LostItem.campus_building,
            func.count(LostItem.item_id),
        )
        .group_by(LostItem.campus_building)
        .all()
    )

    found = (
        db.query(
            FoundItem.campus_building,
            func.count(FoundItem.item_id),
        )
        .group_by(FoundItem.campus_building)
        .all()
    )

    locations = {}

    for location, count in lost:
        locations[location] = locations.get(location, 0) + count

    for location, count in found:
        locations[location] = locations.get(location, 0) + count

    return [
        {
            "location": location,
            "count": count,
        }
        for location, count in sorted(
            locations.items(),
            key=lambda item: item[1],
            reverse=True,
        )
    ]


def get_time_series(db: Session, days: int = 30):
    days = max(1, min(days, 365))

    today = datetime.utcnow().date()
    start_date = today - timedelta(days=days - 1)

    lost_rows = (
        db.query(
            func.date(LostItem.created_at),
            func.count(LostItem.item_id),
        )
        .filter(LostItem.created_at >= datetime.combine(start_date, datetime.min.time()))
        .group_by(func.date(LostItem.created_at))
        .all()
    )

    found_rows = (
        db.query(
            func.date(FoundItem.created_at),
            func.count(FoundItem.item_id),
        )
        .filter(FoundItem.created_at >= datetime.combine(start_date, datetime.min.time()))
        .group_by(func.date(FoundItem.created_at))
        .all()
    )

    recovered_lost_rows = (
        db.query(
            func.date(LostItem.updated_at),
            func.count(LostItem.item_id),
        )
        .filter(
            LostItem.status == "recovered",
            LostItem.updated_at >= datetime.combine(
                start_date,
                datetime.min.time(),
            ),
        )
        .group_by(func.date(LostItem.updated_at))
        .all()
    )

    recovered_found_rows = (
        db.query(
            func.date(FoundItem.updated_at),
            func.count(FoundItem.item_id),
        )
        .filter(
            FoundItem.status == "recovered",
            FoundItem.updated_at >= datetime.combine(
                start_date,
                datetime.min.time(),
            ),
        )
        .group_by(func.date(FoundItem.updated_at))
        .all()
    )

    lost_by_date = {
        str(date): count
        for date, count in lost_rows
    }

    found_by_date = {
        str(date): count
        for date, count in found_rows
    }

    recovered_by_date = {}

    for date, count in recovered_lost_rows:
        key = str(date)
        recovered_by_date[key] = recovered_by_date.get(key, 0) + count

    for date, count in recovered_found_rows:
        key = str(date)
        recovered_by_date[key] = recovered_by_date.get(key, 0) + count

    series = []

    for offset in range(days):
        current_date = start_date + timedelta(days=offset)
        key = str(current_date)

        series.append(
            {
                "date": key,
                "lost_count": lost_by_date.get(key, 0),
                "found_count": found_by_date.get(key, 0),
                "recovered_count": recovered_by_date.get(key, 0),
            }
        )

    return series


def get_recovery_rate(db: Session):
    stats = get_dashboard_stats(db)
    return stats["recovery_rate"]