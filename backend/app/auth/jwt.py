from datetime import datetime, timedelta
from typing import Optional

from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.user import User


oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/auth/login"
)


def _role_value(role) -> str:
    return str(
        getattr(role, "value", role)
    ).lower()


def _status_value(account_status) -> str:
    return str(
        getattr(account_status, "value", account_status)
    ).lower()


def create_access_token(
    data: dict,
    expires_delta: Optional[timedelta] = None,
):
    if not settings.SECRET_KEY:
        raise RuntimeError(
            "SECRET_KEY is not configured"
        )

    if not settings.ALGORITHM:
        raise RuntimeError(
            "JWT algorithm is not configured"
        )

    now = datetime.utcnow()

    expire = (
        now + expires_delta
        if expires_delta
        else now + timedelta(minutes=15)
    )

    to_encode = data.copy()

    to_encode["type"] = "access"
    to_encode["iat"] = now
    to_encode["exp"] = expire

    return jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )


def verify_token(token: str):
    if not token:
        return None

    if not settings.SECRET_KEY or not settings.ALGORITHM:
        return None

    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )

        email = payload.get("sub")

        if not isinstance(email, str):
            return None

        email = email.strip().lower()

        if not email:
            return None

        if payload.get("type") != "access":
            return None

        if payload.get("exp") is None:
            return None

        return payload

    except JWTError:
        return None
    except Exception:
        return None


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={
            "WWW-Authenticate": "Bearer"
        },
    )

    payload = verify_token(token)

    if payload is None:
        raise credentials_exception

    email = payload.get("sub")

    if not isinstance(email, str):
        raise credentials_exception

    user = (
        db.query(User)
        .filter(
            User.college_email == email.strip().lower()
        )
        .first()
    )

    if user is None:
        raise credentials_exception

    return user


def get_current_active_user(
    current_user: User = Depends(
        get_current_user
    ),
):
    if _status_value(
        current_user.account_status
    ) != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is not active",
        )

    return current_user


def require_role(
    allowed_roles: list[str],
):
    normalized_roles = {
        _role_value(role)
        for role in allowed_roles
    }

    def role_checker(
        current_user: User = Depends(
            get_current_active_user
        ),
    ):
        current_role = _role_value(
            current_user.role
        )

        if current_role not in normalized_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not enough permissions",
            )

        return current_user

    return role_checker


def require_admin(
    current_user: User = Depends(
        get_current_active_user
    ),
):
    if _role_value(current_user.role) != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )

    return current_user