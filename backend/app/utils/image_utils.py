import io
from PIL import Image
from fastapi import HTTPException, status

ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp']
MAX_SIZE = 10 * 1024 * 1024  # 10MB

def compress_image(image_bytes: bytes, max_size_kb: int = 500) -> bytes:
    try:
        img = Image.open(io.BytesIO(image_bytes))
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")

        output = io.BytesIO()
        img.save(output, format="JPEG", quality=85, optimize=True)

        # very rudimentary size check
        val = output.getvalue()
        if len(val) > max_size_kb * 1024:
            output = io.BytesIO()
            img.save(output, format="JPEG", quality=60, optimize=True)
            val = output.getvalue()

        return val
    except Exception:
        return image_bytes

def validate_image_file(content_type: str, size_bytes: int):
    if content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {ALLOWED_TYPES}"
        )
    if size_bytes > MAX_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Maximum 10MB allowed."
        )
