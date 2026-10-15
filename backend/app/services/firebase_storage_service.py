import logging
from pathlib import Path

from firebase_admin import storage

from app.config import settings
from app.utils.image_utils import compress_image, validate_image_file

logger = logging.getLogger(__name__)


def _get_bucket():
    """
    Return the configured Firebase Storage bucket.

    Firebase Admin must already be initialized before this function
    is called.
    """
    try:
        return storage.bucket()
    except Exception as exc:
        logger.exception("Unable to access Firebase Storage bucket")
        raise RuntimeError(
            "Firebase Storage is not available."
        ) from exc


def upload_image(
    file_bytes: bytes,
    path: str,
    content_type: str,
) -> str:
    """
    Validate, compress and upload an image to Firebase Storage.

    Returns the Firebase Storage URL/path for the uploaded object.
    """
    if not file_bytes:
        raise ValueError("Image file is empty.")

    if not path or not path.strip():
        raise ValueError("Image storage path is required.")

    path = path.strip().replace("\\", "/")

    # Prevent accidental path traversal.
    if ".." in Path(path).parts:
        raise ValueError("Invalid image storage path.")

    validate_image_file(
        content_type,
        len(file_bytes),
    )

    compressed = compress_image(file_bytes)

    bucket = _get_bucket()
    blob = bucket.blob(path)

    try:
        blob.upload_from_string(
            compressed,
            content_type=content_type,
        )

        # Do not make the Firebase object publicly writable/readable.
        # The backend returns a Firebase Storage URL/reference.
        return blob.public_url

    except Exception as exc:
        logger.exception(
            "Firebase image upload failed for path: %s",
            path,
        )
        raise RuntimeError(
            "Unable to upload image to Firebase Storage."
        ) from exc


def delete_image(path: str) -> bool:
    """
    Delete an image from Firebase Storage.

    Returns True when deletion succeeds.
    """
    if not path or not path.strip():
        return False

    path = path.strip().replace("\\", "/")

    if ".." in Path(path).parts:
        raise ValueError("Invalid image storage path.")

    try:
        bucket = _get_bucket()
        blob = bucket.blob(path)
        blob.delete()

        return True

    except Exception as exc:
        logger.warning(
            "Firebase image deletion failed for path %s: %s",
            path,
            exc,
        )
        return False


def generate_thumbnail(image_bytes: bytes) -> bytes:
    """
    Compress image bytes to a smaller representation suitable
    for thumbnails/previews.
    """
    if not image_bytes:
        raise ValueError("Image file is empty.")

    return compress_image(
        image_bytes,
        max_size_kb=100,
    )