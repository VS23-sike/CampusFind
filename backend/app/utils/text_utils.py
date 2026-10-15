import difflib
import re

from datetime import date
from typing import Optional

from dateutil import parser


MAX_TEXT_LENGTH = 5000


def _safe_text(text: str) -> str:
    if text is None:
        return ""

    return str(text)[:MAX_TEXT_LENGTH]


def fuzzy_similarity(
    str1: str,
    str2: str,
) -> float:
    str1 = _safe_text(str1).strip()
    str2 = _safe_text(str2).strip()

    if not str1 or not str2:
        return 0.0

    try:
        score = difflib.SequenceMatcher(
            None,
            str1.lower(),
            str2.lower(),
        ).ratio()

        return round(
            max(0.0, min(1.0, score)),
            4,
        )

    except (TypeError, ValueError):
        return 0.0


def extract_color_from_text(
    text: str,
) -> Optional[str]:

    colors = [
        "red",
        "blue",
        "green",
        "black",
        "white",
        "yellow",
        "brown",
        "grey",
        "silver",
        "gold",
    ]

    text_lower = _safe_text(text).lower()

    for color in colors:
        if re.search(
            rf"\b{re.escape(color)}\b",
            text_lower,
        ):
            return color

    return None


def extract_category_from_text(
    text: str,
) -> Optional[str]:

    categories = [
        "electronics",
        "clothing",
        "documents",
        "keys",
        "accessories",
        "books",
        "other",
    ]

    text_lower = _safe_text(text).lower()

    for category in categories:
        if re.search(
            rf"\b{re.escape(category)}\b",
            text_lower,
        ):
            return category

    return None


def extract_location_from_text(
    text: str,
) -> Optional[str]:

    locations = [
        "library",
        "canteen",
        "auditorium",
        "ground",
        "block",
    ]

    text_lower = _safe_text(text).lower()

    for location in locations:
        if re.search(
            rf"\b{re.escape(location)}\b",
            text_lower,
        ):
            return location.capitalize()

    return None


def parse_natural_date(
    text: str,
) -> Optional[date]:

    text = _safe_text(text).strip()

    if not text:
        return None

    try:
        parsed_date = parser.parse(
            text,
            fuzzy=True,
        )

        return parsed_date.date()

    except (
        ValueError,
        OverflowError,
        TypeError,
    ):
        return None