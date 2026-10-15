# This project is a CampusFind backend!

## Setup Instructions

1. Clone repo
2. Create virtualenv
3. Install requirements `pip install -r requirements.txt`
4. Copy `.env.example` to `.env`
5. Set up PostgreSQL
6. Add `firebase-credentials.json`
7. Run alembic migrations `alembic upgrade head`
8. Run seed script `python scripts/seed_data.py`
9. Run server `uvicorn app.main:app --reload`
10. Visit `/docs`

Note: For demo/development mode without Firebase, the app falls back to local auth only.
