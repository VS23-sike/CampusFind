# CampusFind - Deadline Build

This archive contains the existing Antigravity-generated CampusFind project, patched into a runnable college-demo MVP.

## 1. Backend (recommended: Docker Desktop)

Open PowerShell in the project root:

```powershell
docker compose up --build
```

Then open:
- http://127.0.0.1:8000/health
- http://127.0.0.1:8000/docs

The backend creates PostgreSQL tables automatically and seeds demo users/items.

Demo accounts:
- Student: `student@campusfind.demo` / `Demo@1234`
- Admin: `admin@campusfind.demo` / `Admin@1234`

Firebase is optional for this deadline build. Local JWT login is used by the Flutter app.

## 2. Flutter

```powershell
cd frontend
flutter pub get
flutter run
```

### If running Flutter on Windows desktop

Use:

```powershell
flutter run -d windows --dart-define=API_URL=http://127.0.0.1:8000
```

### If running an Android emulator

The default API URL is:

```text
http://10.0.2.2:8000
```

## Included working flows

- Login / registration
- Home dashboard
- Lost and found reports
- Search
- AI match suggestions
- Claim verification
- Notifications
- Profile and claim history
- Admin dashboard
- FastAPI + PostgreSQL
- JWT authentication
- Seeded demo data
- Explainable matching factors

## Important

This is optimized for a college demonstration. Firebase image storage/FCM and production email verification are left optional so they do not block the demo.
