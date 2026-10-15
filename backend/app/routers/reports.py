from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_active_user
from app.database import get_db
from app.models.report import Report
from app.models.user import User
from app.schemas.report import ReportCreate, ReportResponse

router = APIRouter(
    prefix="/reports",
    tags=["reports"],
)

MAX_REPORTS_PER_PAGE = 100

VALID_STATUSES = {
    "pending",
    "reviewed",
    "resolved",
    "dismissed",
}


@router.post(
    "",
    response_model=ReportResponse,
    status_code=201,
)
def create_report(
    data: ReportCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    # Prevent users from reporting themselves.
    if (
        data.reported_user_id
        and data.reported_user_id == current_user.user_id
    ):
        raise HTTPException(
            status_code=400,
            detail="You cannot report yourself.",
        )

    # Prevent duplicate pending reports from the same user
    # against the same target.
    existing_query = db.query(Report).filter(
        Report.reporter_id == current_user.user_id,
        Report.status == "pending",
    )

    if data.reported_item_id:
        existing_query = existing_query.filter(
            Report.reported_item_id == data.reported_item_id
        )

    if data.reported_user_id:
        existing_query = existing_query.filter(
            Report.reported_user_id == data.reported_user_id
        )

    existing = existing_query.first()

    if existing:
        raise HTTPException(
            status_code=400,
            detail="You already have a pending report for this target.",
        )

    report_data = data.model_dump(
        exclude_unset=True
    )

    report = Report(
        **report_data,
        reporter_id=current_user.user_id,
        status="pending",
    )

    try:
        db.add(report)
        db.commit()
        db.refresh(report)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to create report.",
        )

    return report


@router.get(
    "",
    response_model=list[ReportResponse],
)
def get_user_reports(
    page: int = Query(1, ge=1),
    size: int = Query(
        50,
        ge=1,
        le=MAX_REPORTS_PER_PAGE,
    ),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    offset = (page - 1) * size

    return (
        db.query(Report)
        .filter(
            Report.reporter_id == current_user.user_id
        )
        .order_by(
            Report.created_at.desc()
        )
        .offset(offset)
        .limit(size)
        .all()
    )


@router.get(
    "/{report_id}",
    response_model=ReportResponse,
)
def get_report(
    report_id: str,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    report = (
        db.query(Report)
        .filter(
            Report.report_id == report_id,
            Report.reporter_id == current_user.user_id,
        )
        .first()
    )

    if not report:
        raise HTTPException(
            status_code=404,
            detail="Report not found.",
        )

    return report