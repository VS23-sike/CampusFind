from pydantic import BaseModel


class CategoryBreakdown(BaseModel):
    category: str
    count: int

class LocationBreakdown(BaseModel):
    location: str
    count: int

class TimeSeriesData(BaseModel):
    date: str
    lost_count: int
    found_count: int
    recovered_count: int

class DashboardStats(BaseModel):
    total_users: int
    total_lost_items: int
    total_found_items: int
    total_recovered_items: int
    recovery_rate: float
    active_matches: int
    pending_claims: int
    open_reports: int
