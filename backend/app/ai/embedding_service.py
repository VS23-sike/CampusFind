"""
AI similarity service for CampusFind.

Provides:
- text similarity
- keyword similarity
- field similarity
- image similarity using CLIP
- explainable item comparison

AI matching is only a suggestion and is never proof of ownership.
"""

import io
import re
from difflib import SequenceMatcher
from typing import Any, Optional

import numpy as np


class EmbeddingService:
    MAX_TEXT_LENGTH = 10000
    MAX_EMBEDDING_LENGTH = 10000

    def __init__(self):
        self.model_loaded = False
        self.image_model = None
        self.image_processor = None

        self.vocab = [
            "black", "blue", "brown", "white", "red", "green",
            "yellow", "pink", "grey", "gray", "orange", "purple",
            "wallet", "bag", "backpack", "bottle", "calculator",
            "earbuds", "headphones", "phone", "laptop", "tablet",
            "keys", "book", "notebook", "clothing", "shirt",
            "jacket", "electronics", "accessories", "documents",
            "id", "card", "stationery", "library", "canteen",
            "lab", "classroom", "auditorium", "parking",
            "cafeteria", "office",
        ]

        self._load_image_model()

    # =========================================================
    # IMAGE MODEL
    # =========================================================

    def _load_image_model(self):
        """
        Load CLIP if the optional AI dependencies/model are available.

        If CLIP cannot be loaded, the backend continues to work with
        text/field matching instead of crashing during startup.
        """

        try:
            from transformers import CLIPModel, CLIPProcessor

            model_name = "openai/clip-vit-base-patch32"

            self.image_processor = CLIPProcessor.from_pretrained(
                model_name
            )

            self.image_model = CLIPModel.from_pretrained(
                model_name
            )

            self.image_model.eval()

            self.model_loaded = True

        except Exception:
            self.image_model = None
            self.image_processor = None
            self.model_loaded = False

    # =========================================================
    # BASIC TEXT PROCESSING
    # =========================================================

    def _safe_text(self, text: Any) -> str:
        if text is None:
            return ""

        return str(text)[:self.MAX_TEXT_LENGTH]

    def _clean(self, text: Any) -> str:
        return " ".join(
            self._safe_text(text)
            .lower()
            .split()
        )

    def _tokens(self, text: Any) -> set[str]:
        cleaned = self._clean(text)

        if not cleaned:
            return set()

        return set(
            re.findall(
                r"[a-z0-9]+",
                cleaned,
            )
        )

    # =========================================================
    # TEXT EMBEDDING
    # =========================================================

    def embed_text(
        self,
        text: str,
    ) -> list[float]:
        """
        Lightweight deterministic text representation.

        This is used only as a supporting feature. Actual image
        similarity uses CLIP embeddings.
        """

        tokens = self._tokens(text)

        return [
            1.0 if word in tokens else 0.0
            for word in self.vocab
        ]

    def embed_item_description(
        self,
        item,
    ) -> list[float]:
        def get(key):
            if isinstance(item, dict):
                return item.get(key, "") or ""

            return getattr(
                item,
                key,
                "",
            ) or ""

        fields = (
            "title",
            "category",
            "subcategory",
            "color",
            "brand",
            "model",
            "material",
            "identifying_features",
            "description",
            "location_name",
            "campus_building",
            "floor",
            "nearby_landmark",
        )

        text = " ".join(
            str(get(field))
            for field in fields
        )

        return self.embed_text(text)

    # =========================================================
    # IMAGE EMBEDDING
    # =========================================================

    def embed_image(
        self,
        image_bytes: bytes,
    ) -> Optional[list[float]]:
        """
        Generate a normalized CLIP image embedding.

        Returns None when the vision model is unavailable or
        the image cannot be processed.
        """

        if not image_bytes:
            return None

        if not self.model_loaded:
            return None

        if (
            self.image_model is None
            or self.image_processor is None
        ):
            return None

        try:
            from PIL import Image
            import torch

            image = Image.open(
                io.BytesIO(image_bytes)
            ).convert("RGB")

            inputs = self.image_processor(
                images=image,
                return_tensors="pt",
            )

            with torch.no_grad():
                outputs = self.image_model.get_image_features(
                    **inputs
                )

            vector = (
                outputs
                .detach()
                .cpu()
                .numpy()
                .reshape(-1)
            )

            if vector.size == 0:
                return None

            norm = float(np.linalg.norm(vector))

            if not np.isfinite(norm) or norm <= 0:
                return None

            vector = vector / norm

            return vector.astype(
                np.float32
            ).tolist()

        except Exception:
            return None

    # =========================================================
    # IMAGE SIMILARITY
    # =========================================================

    def compute_image_similarity(
        self,
        emb1: Any,
        emb2: Any,
    ) -> float:
        """
        Calculate cosine similarity between two normalized
        CLIP embeddings.

        The result is converted from [-1, 1] to [0, 1].
        """

        if not emb1 or not emb2:
            return 0.0

        try:
            if not isinstance(
                emb1,
                (list, tuple),
            ):
                return 0.0

            if not isinstance(
                emb2,
                (list, tuple),
            ):
                return 0.0

            if (
                len(emb1) == 0
                or len(emb2) == 0
            ):
                return 0.0

            if (
                len(emb1) > self.MAX_EMBEDDING_LENGTH
                or len(emb2) > self.MAX_EMBEDDING_LENGTH
            ):
                return 0.0

            if len(emb1) != len(emb2):
                return 0.0

            a = np.asarray(
                emb1,
                dtype=np.float32,
            )

            b = np.asarray(
                emb2,
                dtype=np.float32,
            )

            if (
                not np.all(np.isfinite(a))
                or not np.all(np.isfinite(b))
            ):
                return 0.0

            norm_a = float(np.linalg.norm(a))
            norm_b = float(np.linalg.norm(b))

            if norm_a <= 0 or norm_b <= 0:
                return 0.0

            cosine = float(
                np.dot(a, b)
                / (norm_a * norm_b)
            )

            cosine = max(
                -1.0,
                min(1.0, cosine),
            )

            score = (
                cosine + 1.0
            ) / 2.0

            return round(
                max(
                    0.0,
                    min(1.0, score),
                ),
                4,
            )

        except (
            TypeError,
            ValueError,
            OverflowError,
        ):
            return 0.0

    # =========================================================
    # TEXT SIMILARITY
    # =========================================================

    def compute_text_similarity(
        self,
        text1: str,
        text2: str,
    ) -> float:
        text1 = self._clean(text1)
        text2 = self._clean(text2)

        if not text1 or not text2:
            return 0.0

        try:
            score = SequenceMatcher(
                None,
                text1,
                text2,
            ).ratio()

            return round(
                max(
                    0.0,
                    min(1.0, score),
                ),
                4,
            )

        except (
            TypeError,
            ValueError,
        ):
            return 0.0

    # =========================================================
    # TOKEN SIMILARITY
    # =========================================================

    def compute_token_similarity(
        self,
        text1: str,
        text2: str,
    ) -> float:
        tokens1 = self._tokens(text1)
        tokens2 = self._tokens(text2)

        if not tokens1 or not tokens2:
            return 0.0

        union = tokens1.union(tokens2)

        if not union:
            return 0.0

        intersection = tokens1.intersection(tokens2)

        score = len(intersection) / len(union)

        return round(
            max(
                0.0,
                min(1.0, score),
            ),
            4,
        )

    # =========================================================
    # FIELD SIMILARITY
    # =========================================================

    def compute_field_similarity(
        self,
        value1: Any,
        value2: Any,
    ) -> float:
        value1 = self._clean(value1)
        value2 = self._clean(value2)

        if not value1 or not value2:
            return 0.0

        if value1 == value2:
            return 1.0

        try:
            score = SequenceMatcher(
                None,
                value1,
                value2,
            ).ratio()

            return round(
                max(
                    0.0,
                    min(1.0, score),
                ),
                4,
            )

        except (
            TypeError,
            ValueError,
        ):
            return 0.0

    # =========================================================
    # COMPLETE ITEM COMPARISON
    # =========================================================

    def compare_items(
        self,
        item1,
        item2,
    ) -> dict:
        """
        Produce one explainable similarity result.

        This method is kept compatible with the rest of the
        CampusFind backend. The main matching workflow can use
        the individual component methods as well.
        """

        def get(item, key):
            if isinstance(item, dict):
                return item.get(key, "") or ""

            return getattr(
                item,
                key,
                "",
            ) or ""

        def text_fields(item):
            return [
                str(get(item, "title")),
                str(get(item, "category")),
                str(get(item, "subcategory")),
                str(get(item, "color")),
                str(get(item, "brand")),
                str(get(item, "model")),
                str(get(item, "material")),
                str(get(item, "identifying_features")),
                str(get(item, "description")),
            ]

        def location_fields(item):
            return [
                str(get(item, "location_name")),
                str(get(item, "campus_building")),
                str(get(item, "floor")),
                str(get(item, "nearby_landmark")),
            ]

        full_text1 = " ".join(text_fields(item1))
        full_text2 = " ".join(text_fields(item2))

        location1 = " ".join(
            location_fields(item1)
        )

        location2 = " ".join(
            location_fields(item2)
        )

        text_score = self.compute_text_similarity(
            full_text1,
            full_text2,
        )

        keyword_score = self.compute_token_similarity(
            full_text1,
            full_text2,
        )

        category_score = self.compute_field_similarity(
            get(item1, "category"),
            get(item2, "category"),
        )

        color_score = self.compute_field_similarity(
            get(item1, "color"),
            get(item2, "color"),
        )

        brand_score = self.compute_field_similarity(
            get(item1, "brand"),
            get(item2, "brand"),
        )

        location_score = self.compute_field_similarity(
            location1,
            location2,
        )

        image_score = self.compute_image_similarity(
            get(item1, "image_embedding"),
            get(item2, "image_embedding"),
        )

        # =====================================================
        # WEIGHTED SCORE
        # =====================================================

        # Only use the image component when BOTH items actually
        # have valid image embeddings. This prevents the default
        # 0.0 image score from being interpreted as a real signal.
        has_image_embeddings = (
            bool(get(item1, "image_embedding"))
            and bool(get(item2, "image_embedding"))
            and image_score > 0.0
        )

        if has_image_embeddings:
            weights = {
                "image": 0.35,
                "text": 0.20,
                "keywords": 0.15,
                "category": 0.10,
                "color": 0.08,
                "brand": 0.07,
                "location": 0.05,
            }
        else:
            weights = {
                "text": 0.30,
                "keywords": 0.20,
                "category": 0.18,
                "color": 0.12,
                "brand": 0.10,
                "location": 0.10,
            }

        components = {
            "image": image_score,
            "text": text_score,
            "keywords": keyword_score,
            "category": category_score,
            "color": color_score,
            "brand": brand_score,
            "location": location_score,
        }

        final_score = sum(
            components[key] * weight
            for key, weight in weights.items()
        )

        final_score = max(
            0.0,
            min(1.0, final_score),
        )

        # =====================================================
        # EXPLANATION
        # =====================================================

        reasons = []

        if category_score >= 0.80:
            reasons.append(
                "Same category"
            )

        if color_score >= 0.80:
            reasons.append(
                "Similar colour"
            )

        if brand_score >= 0.80:
            reasons.append(
                "Same or similar brand"
            )

        if location_score >= 0.70:
            reasons.append(
                "Similar campus location"
            )

        if keyword_score >= 0.25:
            reasons.append(
                "Matching descriptive keywords"
            )

        if has_image_embeddings and image_score >= 0.70:
            reasons.append(
                "Strong image similarity"
            )

        if not reasons:
            reasons.append(
                "General item similarity"
            )

        return {
            "score": round(
                final_score,
                4,
            ),
            "percentage": round(
                final_score * 100,
                1,
            ),
            "components": {
                key: round(
                    value,
                    4,
                )
                for key, value in components.items()
            },
            "reasons": reasons,
            "is_suggestion": True,
            "warning": (
                "AI match score is a suggestion "
                "and is not proof of ownership."
            ),
        }


embedding_service = EmbeddingService()