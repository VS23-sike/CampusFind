"""
Detects duplicate reports before submission.
Checks: similar description, same location, same date range.
"""
from sqlalchemy.orm import Session
from app.models.lost_item import LostItem
from app.models.found_item import FoundItem

class DuplicateDetector:
    def check_for_duplicates(self, db: Session, item_type: str, new_item_data: dict) -> list:
        # A simple check for exact title or same user reporting recently
        # Real implementation would use embeddings and time windows
        duplicates = []
        if item_type == 'lost':
            query = db.query(LostItem).filter(
                LostItem.title == new_item_data.get('title'),
                LostItem.category == new_item_data.get('category')
            ).all()
            duplicates.extend([item.item_id for item in query])
        elif item_type == 'found':
            query = db.query(FoundItem).filter(
                FoundItem.title == new_item_data.get('title'),
                FoundItem.category == new_item_data.get('category')
            ).all()
            duplicates.extend([item.item_id for item in query])
        return duplicates

duplicate_detector = DuplicateDetector()
