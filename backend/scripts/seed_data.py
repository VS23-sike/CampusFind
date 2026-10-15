import os
import sys
import uuid
from datetime import datetime, timedelta

# Add parent directory to path so we can import from app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models.user import User
from app.models.lost_item import LostItem
from app.models.found_item import FoundItem
from app.auth.password import hash_password
from app.config import settings

def seed():
    # Create tables if not exist
    Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()

    # 1. Demo users
    student_email = settings.DEMO_STUDENT_EMAIL
    if not db.query(User).filter(User.college_email == student_email).first():
        student = User(
            full_name="Demo Student",
            college_email=student_email,
            hashed_password=hash_password(settings.DEMO_STUDENT_PASSWORD),
            role="student",
            department="Computer Science",
            email_verified=True
        )
        db.add(student)

    admin_email = settings.DEMO_ADMIN_EMAIL
    if not db.query(User).filter(User.college_email == admin_email).first():
        admin = User(
            full_name="Demo Admin",
            college_email=admin_email,
            hashed_password=hash_password(settings.DEMO_ADMIN_PASSWORD),
            role="admin",
            department="Administration",
            email_verified=True
        )
        db.add(admin)

    db.commit()

    student = db.query(User).filter(User.college_email == student_email).first()
    admin = db.query(User).filter(User.college_email == admin_email).first()

    # 2. Add realistic Lost Items
    lost_items_data = [
        {"title": "Black laptop bag", "cat": "electronics", "desc": "Dell bag", "loc": "Main Library", "color": "black"},
        {"title": "Blue water bottle", "cat": "accessories", "desc": "Milton bottle", "loc": "Canteen", "color": "blue"},
        {"title": "Student ID card", "cat": "documents", "desc": "John Doe ID", "loc": "Computer Lab Block A", "color": "white"},
        {"title": "Wireless earbuds", "cat": "electronics", "desc": "Airpods Pro", "loc": "Seminar Hall", "color": "white"},
        {"title": "Scientific calculator", "cat": "electronics", "desc": "Casio fx-991", "loc": "Auditorium", "color": "grey"},
        {"title": "Red umbrella", "cat": "accessories", "desc": "Foldable", "loc": "Sports Ground", "color": "red"},
        {"title": "Math notebook", "cat": "books", "desc": "Calculus notes", "loc": "Parking Area", "color": "blue"},
        {"title": "Brown wallet", "cat": "accessories", "desc": "Leather wallet", "loc": "Admin Building", "color": "brown"},
        {"title": "USB drive", "cat": "electronics", "desc": "SanDisk 64GB", "loc": "Engineering Block", "color": "silver"},
        {"title": "Grey hoodie", "cat": "clothing", "desc": "College merch", "loc": "College Gate", "color": "grey"}
    ]

    for item in lost_items_data:
        if not db.query(LostItem).filter(LostItem.title == item['title']).first():
            db.add(LostItem(
                user_id=student.user_id,
                title=item['title'],
                category=item['cat'],
                description=item['desc'],
                location_name=item['loc'],
                campus_building=item['loc'],
                color=item['color'],
                date_lost=datetime.utcnow().date() - timedelta(days=2)
            ))

    # 3. Add realistic Found Items
    found_items_data = [
        {"title": "Black backpack", "cat": "accessories", "desc": "Wildcraft bag", "loc": "Main Library", "color": "black"},
        {"title": "Silver water bottle", "cat": "accessories", "desc": "Steel bottle", "loc": "Canteen", "color": "silver"},
        {"title": "Casio calculator", "cat": "electronics", "desc": "Calculator", "loc": "Auditorium", "color": "grey"},
        {"title": "Earbuds case", "cat": "electronics", "desc": "Empty white case", "loc": "Seminar Hall", "color": "white"},
        {"title": "Key bunch", "cat": "keys", "desc": "3 keys with chain", "loc": "Parking Area", "color": "silver"},
        {"title": "Blue notebook", "cat": "books", "desc": "Physics notes", "loc": "Computer Lab Block A", "color": "blue"},
        {"title": "Spectacles", "cat": "accessories", "desc": "Black frame", "loc": "Sports Ground", "color": "black"},
        {"title": "Power bank", "cat": "electronics", "desc": "Mi 10000mAh", "loc": "Engineering Block", "color": "black"},
        {"title": "Charger cable", "cat": "electronics", "desc": "Type C", "loc": "Admin Building", "color": "white"},
        {"title": "Green jacket", "cat": "clothing", "desc": "Size M", "loc": "College Gate", "color": "green"}
    ]

    for item in found_items_data:
        if not db.query(FoundItem).filter(FoundItem.title == item['title']).first():
            db.add(FoundItem(
                finder_id=admin.user_id,
                title=item['title'],
                category=item['cat'],
                description=item['desc'],
                location_name=item['loc'],
                campus_building=item['loc'],
                color=item['color'],
                date_found=datetime.utcnow().date() - timedelta(days=1)
            ))

    db.commit()

    # Generate initial explainable AI matches for the demo.
    from app.services.match_service import generate_matches_for_lost_item
    for lost in db.query(LostItem).all():
        generate_matches_for_lost_item(db, lost.item_id)

    db.close()
    print("Database seeded successfully!")

if __name__ == "__main__":
    seed()
