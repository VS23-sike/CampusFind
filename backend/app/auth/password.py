import base64
import hashlib
import hmac
import os
import re


# ---------------------------------------------------------
# Password security configuration
# ---------------------------------------------------------

_HASH_SCHEME = "pbkdf2_sha256"
_HASH_ALGORITHM = "sha256"

_ITERATIONS = 200_000

_MIN_PASSWORD_LENGTH = 8
_MAX_PASSWORD_LENGTH = 128

_MIN_STORED_ITERATIONS = 100_000
_MAX_STORED_ITERATIONS = 1_000_000

_SALT_LENGTH = 16


# ---------------------------------------------------------
# Hash password
# ---------------------------------------------------------

def hash_password(password: str) -> str:
    if not isinstance(password, str):
        raise ValueError("Password must be a string")

    if not password:
        raise ValueError("Password cannot be empty")

    if len(password) < _MIN_PASSWORD_LENGTH:
        raise ValueError(
            f"Password must be at least {_MIN_PASSWORD_LENGTH} characters long"
        )

    if len(password) > _MAX_PASSWORD_LENGTH:
        raise ValueError(
            f"Password must not exceed {_MAX_PASSWORD_LENGTH} characters"
        )

    salt = os.urandom(_SALT_LENGTH)

    digest = hashlib.pbkdf2_hmac(
        _HASH_ALGORITHM,
        password.encode("utf-8"),
        salt,
        _ITERATIONS,
    )

    salt_b64 = base64.urlsafe_b64encode(salt).decode("ascii")
    digest_b64 = base64.urlsafe_b64encode(digest).decode("ascii")

    return f"{_HASH_SCHEME}${_ITERATIONS}${salt_b64}${digest_b64}"


# ---------------------------------------------------------
# Verify password
# ---------------------------------------------------------

def verify_password(
    plain_password: str,
    hashed_password: str,
) -> bool:
    try:
        if not isinstance(plain_password, str):
            return False

        if not isinstance(hashed_password, str):
            return False

        if not plain_password:
            return False

        if len(plain_password) > _MAX_PASSWORD_LENGTH:
            return False

        parts = hashed_password.split("$", 3)

        if len(parts) != 4:
            return False

        scheme, iterations_str, salt_b64, digest_b64 = parts

        if scheme != _HASH_SCHEME:
            return False

        iterations = int(iterations_str)

        if not (
            _MIN_STORED_ITERATIONS
            <= iterations
            <= _MAX_STORED_ITERATIONS
        ):
            return False

        salt = base64.urlsafe_b64decode(
            salt_b64.encode("ascii")
        )

        expected_digest = base64.urlsafe_b64decode(
            digest_b64.encode("ascii")
        )

        if len(salt) != _SALT_LENGTH:
            return False

        if len(expected_digest) != hashlib.sha256().digest_size:
            return False

        actual_digest = hashlib.pbkdf2_hmac(
            _HASH_ALGORITHM,
            plain_password.encode("utf-8"),
            salt,
            iterations,
        )

        return hmac.compare_digest(
            actual_digest,
            expected_digest,
        )

    except (
        ValueError,
        TypeError,
        UnicodeError,
        base64.binascii.Error,
    ):
        return False


# ---------------------------------------------------------
# Password strength validation
# ---------------------------------------------------------

def validate_password_strength(password: str) -> None:
    if not isinstance(password, str):
        raise ValueError("Password must be a string")

    if len(password) < _MIN_PASSWORD_LENGTH:
        raise ValueError(
            f"Password must be at least {_MIN_PASSWORD_LENGTH} characters long"
        )

    if len(password) > _MAX_PASSWORD_LENGTH:
        raise ValueError(
            f"Password must not exceed {_MAX_PASSWORD_LENGTH} characters"
        )

    if not re.search(r"[a-z]", password):
        raise ValueError(
            "Password must contain at least one lowercase letter"
        )

    if not re.search(r"[A-Z]", password):
        raise ValueError(
            "Password must contain at least one uppercase letter"
        )

    if not re.search(r"[0-9]", password):
        raise ValueError(
            "Password must contain at least one digit"
        )

    if not re.search(r"[^A-Za-z0-9]", password):
        raise ValueError(
            "Password must contain at least one special character"
        )