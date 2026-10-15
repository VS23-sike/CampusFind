import logging
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials

from fastapi import HTTPException, status

from app.config import settings


logger = logging.getLogger(__name__)


# ---------------------------------------------------------
# Firebase initialization
# ---------------------------------------------------------

def initialize_firebase() -> bool:
    """
    Initialize Firebase Admin SDK once.

    Returns:
        True when Firebase is initialized or was already initialized.

    Raises:
        RuntimeError when Firebase credentials/configuration
        cannot be loaded.
    """

    if firebase_admin._apps:
        return True

    credentials_path = Path(
        settings.FIREBASE_CREDENTIALS_PATH
    )

    storage_bucket = (
        settings.FIREBASE_STORAGE_BUCKET
    )

    if not credentials_path:
        raise RuntimeError(
            "Firebase credentials path is not configured"
        )

    if not credentials_path.exists():
        raise RuntimeError(
            f"Firebase credentials file not found: "
            f"{credentials_path}"
        )

    if not credentials_path.is_file():
        raise RuntimeError(
            "Firebase credentials path is not a file"
        )

    if not storage_bucket:
        raise RuntimeError(
            "Firebase storage bucket is not configured"
        )

    try:
        cred = credentials.Certificate(
            str(credentials_path)
        )

        firebase_admin.initialize_app(
            cred,
            {
                "storageBucket": storage_bucket,
            },
        )

        logger.info(
            "Firebase Admin SDK initialized successfully"
        )

        return True

    except Exception as exc:
        logger.exception(
            "Firebase Admin SDK initialization failed"
        )

        raise RuntimeError(
            "Firebase authentication service could not be initialized"
        ) from exc


# ---------------------------------------------------------
# Firebase token verification
# ---------------------------------------------------------

def verify_firebase_token(id_token: str):
    """
    Verify a Firebase ID token.

    Returns:
        Decoded Firebase token.

    Raises:
        HTTPException 401 for invalid/expired tokens.
    """

    if not isinstance(id_token, str):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase authentication token",
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )

    id_token = id_token.strip()

    if not id_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase authentication token is required",
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )

    # Firebase must be initialized before verification.
    if not firebase_admin._apps:
        try:
            initialize_firebase()
        except RuntimeError:
            logger.error(
                "Firebase token verification requested "
                "while Firebase is unavailable"
            )

            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Firebase authentication service is unavailable",
            )

    try:
        decoded_token = auth.verify_id_token(
            id_token,
            check_revoked=True,
        )

        if not decoded_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Firebase authentication token",
                headers={
                    "WWW-Authenticate": "Bearer",
                },
            )

        uid = decoded_token.get("uid")
        issuer = decoded_token.get("iss")
        audience = decoded_token.get("aud")

        if not uid or not issuer or not audience:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Firebase authentication token",
                headers={
                    "WWW-Authenticate": "Bearer",
                },
            )

        return decoded_token

    except HTTPException:
        raise

    except Exception:
        logger.warning(
            "Firebase ID token verification failed",
            exc_info=True,
        )

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase authentication token",
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )


# ---------------------------------------------------------
# Firebase user helpers
# ---------------------------------------------------------

def get_firebase_user(uid: str):
    """
    Retrieve a Firebase user by UID.
    """

    if not uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Firebase user ID is required",
        )

    try:
        return auth.get_user(uid)

    except auth.UserNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Firebase user not found",
        )

    except Exception:
        logger.exception(
            "Failed to retrieve Firebase user"
        )

        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase authentication service is unavailable",
        )


def revoke_firebase_tokens(uid: str) -> None:
    """
    Revoke Firebase refresh tokens for a user.
    """

    if not uid:
        return

    try:
        auth.revoke_refresh_tokens(uid)

    except Exception:
        logger.exception(
            "Failed to revoke Firebase refresh tokens"
        )

        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unable to update Firebase authentication state",
        )