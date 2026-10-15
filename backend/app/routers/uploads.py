import io
from uuid import uuid4
from urllib.parse import quote

from fastapi import APIRouter, File, HTTPException, UploadFile
from firebase_admin import storage

from app.auth.firebase import initialize_firebase
from app.config import settings


router = APIRouter(
    prefix="/uploads",
    tags=["uploads"],
)


ALLOWED_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

MAX_FILE_SIZE = min(
    int(getattr(settings, "MAX_FILE_SIZE", 10 * 1024 * 1024)),
    10 * 1024 * 1024,
)


def detect_image_type(contents: bytes) -> str | None:
    if contents.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"

    if contents.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"

    if (
        len(contents) >= 12
        and contents[:4] == b"RIFF"
        and contents[8:12] == b"WEBP"
    ):
        return "image/webp"

    return None


def validate_image(
    contents: bytes,
    declared_content_type: str | None,
) -> str:
    if not contents:
        raise HTTPException(
            status_code=400,
            detail="The uploaded image is empty.",
        )

    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Image must be smaller than "
                f"{MAX_FILE_SIZE // (1024 * 1024)} MB."
            ),
        )

    detected_type = detect_image_type(contents)

    if detected_type is None:
        raise HTTPException(
            status_code=400,
            detail="Only valid JPG, PNG and WebP images are allowed.",
        )

    if declared_content_type:
        declared = declared_content_type.lower().strip()

        if declared != detected_type:
            raise HTTPException(
                status_code=400,
                detail="The uploaded file type does not match its contents.",
            )

    return detected_type


def get_firebase_bucket():
    try:
        initialize_firebase()
        bucket = storage.bucket()

        if bucket is None:
            raise RuntimeError("Firebase bucket unavailable.")

        return bucket

    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=(
                "Firebase Storage is not configured. "
                "Please configure firebase-credentials.json "
                "and the Firebase Storage bucket."
            ),
        ) from exc


def build_firebase_download_url(
    bucket_name: str,
    storage_path: str,
    token: str,
) -> str:
    encoded_path = quote(
        storage_path,
        safe="",
    )

    return (
        f"https://firebasestorage.googleapis.com/"
        f"v0/b/{bucket_name}/o/"
        f"{encoded_path}"
        f"?alt=media&token={token}"
    )


async def upload_image(
    file: UploadFile,
):
    if not file:
        raise HTTPException(
            status_code=400,
            detail="No image was provided.",
        )

    declared_content_type = (
        file.content_type or ""
    ).lower().strip()

    if declared_content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, PNG and WebP images are allowed.",
        )

    contents = await file.read()

    trusted_content_type = validate_image(
        contents,
        declared_content_type,
    )

    extension = ALLOWED_TYPES[trusted_content_type]

    filename = f"{uuid4().hex}{extension}"

    storage_path = (
        f"campusfind/items/{filename}"
    )

    bucket = get_firebase_bucket()

    try:
        blob = bucket.blob(storage_path)

        blob.upload_from_file(
            io.BytesIO(contents),
            content_type=trusted_content_type,
        )

        # Firebase download-token URL.
        # This remains valid instead of expiring after one hour.
        token = uuid4().hex

        blob.metadata = {
            **(blob.metadata or {}),
            "firebaseStorageDownloadTokens": token,
        }

        blob.patch()

        url = build_firebase_download_url(
            bucket.name,
            storage_path,
            token,
        )

        return {
            "filename": filename,
            "url": url,
            "storage_path": storage_path,
            "content_type": trusted_content_type,
            "size": len(contents),
        }

    except HTTPException:
        raise

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail="Unable to upload image to Firebase Storage.",
        ) from exc


@router.post("/image")
async def upload_image_endpoint(
    file: UploadFile = File(...),
):
    return await upload_image(file)