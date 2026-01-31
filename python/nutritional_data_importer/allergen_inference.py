# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Allergen inference from USDA food descriptions.

Infers allergens based on keyword matching in food descriptions.
Data source is marked as LLM_INFERRED with appropriate confidence scores.
"""

import re
from typing import NamedTuple


class AllergenMatch(NamedTuple):
    """An inferred allergen with confidence score."""

    allergen_type: str
    presence_type: str  # CONTAINS, MAY_CONTAIN
    confidence_score: float


# Non-dairy "butter" patterns (peanut butter, almond butter, cocoa butter, etc.)
_NON_DAIRY_BUTTER_PATTERN = re.compile(
    r"\b(peanut|almond|cashew|sunflower|seed|nut|cocoa|shea|mango|apple|body)"
    r"\s+butter\b",
    re.I,
)

# Keyword patterns: (regex, allergen, confidence)
# Ordered by specificity - more specific patterns first
ALLERGEN_PATTERNS: list[tuple[re.Pattern, str, float]] = [
    # Milk/Dairy
    (re.compile(r"\bmilk\b", re.I), "MILK", 0.90),
    (re.compile(r"\bcream\b(?!\s+of\s+tartar)", re.I), "MILK", 0.85),
    (re.compile(r"\bbutter\b", re.I), "MILK", 0.85),  # Filtered in infer_allergens()
    (re.compile(r"\bcheese\b", re.I), "MILK", 0.90),
    (re.compile(r"\byogurt\b", re.I), "MILK", 0.90),
    (re.compile(r"\bwhey\b", re.I), "MILK", 0.90),
    (re.compile(r"\bcasein\b", re.I), "MILK", 0.90),
    (re.compile(r"\blactose\b", re.I), "MILK", 0.85),
    # Eggs
    (re.compile(r"\beggs?\b", re.I), "EGGS", 0.90),
    (re.compile(r"\begg white", re.I), "EGGS", 0.90),
    (re.compile(r"\begg yolk", re.I), "EGGS", 0.90),
    (re.compile(r"\bmayonnaise\b", re.I), "EGGS", 0.80),
    # Wheat/Gluten
    (re.compile(r"\bwheat\b", re.I), "WHEAT", 0.90),
    (re.compile(r"\bwheat\b", re.I), "GLUTEN", 0.90),
    (
        re.compile(
            r"\bflour,?\s*(all[- ]purpose|bread|cake|pastry|self[- ]rising)", re.I
        ),
        "WHEAT",
        0.85,
    ),
    (
        re.compile(
            r"\bflour,?\s*(all[- ]purpose|bread|cake|pastry|self[- ]rising)", re.I
        ),
        "GLUTEN",
        0.85,
    ),
    (re.compile(r"\bbread\b", re.I), "WHEAT", 0.80),
    (re.compile(r"\bbread\b", re.I), "GLUTEN", 0.80),
    (re.compile(r"\bpasta\b", re.I), "WHEAT", 0.75),
    (re.compile(r"\bnoodles?\b", re.I), "WHEAT", 0.70),
    (re.compile(r"\bbarley\b", re.I), "GLUTEN", 0.90),
    (re.compile(r"\brye\b", re.I), "GLUTEN", 0.90),
    (re.compile(r"\bseitan\b", re.I), "GLUTEN", 0.95),
    # Soy
    (re.compile(r"\bsoy\b", re.I), "SOYBEANS", 0.90),
    (re.compile(r"\bsoya\b", re.I), "SOYBEANS", 0.90),
    (re.compile(r"\btofu\b", re.I), "SOYBEANS", 0.90),
    (re.compile(r"\bedamame\b", re.I), "SOYBEANS", 0.90),
    (re.compile(r"\bmiso\b", re.I), "SOYBEANS", 0.90),
    (re.compile(r"\btempeh\b", re.I), "SOYBEANS", 0.90),
    # Peanuts
    (re.compile(r"\bpeanut", re.I), "PEANUTS", 0.95),
    (re.compile(r"\bgroundnut", re.I), "PEANUTS", 0.95),
    # Tree nuts - specific types
    (re.compile(r"\balmond", re.I), "ALMONDS", 0.95),
    (re.compile(r"\balmond", re.I), "TREE_NUTS", 0.95),
    (re.compile(r"\bcashew", re.I), "CASHEWS", 0.95),
    (re.compile(r"\bcashew", re.I), "TREE_NUTS", 0.95),
    (re.compile(r"\bwalnut", re.I), "WALNUTS", 0.95),
    (re.compile(r"\bwalnut", re.I), "TREE_NUTS", 0.95),
    (re.compile(r"\bhazelnut", re.I), "HAZELNUTS", 0.95),
    (re.compile(r"\bhazelnut", re.I), "TREE_NUTS", 0.95),
    (re.compile(r"\bfilbert", re.I), "HAZELNUTS", 0.95),
    (re.compile(r"\bpecan", re.I), "TREE_NUTS", 0.95),
    (re.compile(r"\bpistachio", re.I), "TREE_NUTS", 0.95),
    (re.compile(r"\bmacadamia", re.I), "TREE_NUTS", 0.95),
    (re.compile(r"\bbrazil\s*nut", re.I), "TREE_NUTS", 0.95),
    (re.compile(r"\bpine\s*nut", re.I), "TREE_NUTS", 0.95),
    (re.compile(r"\bcoconut", re.I), "COCONUT", 0.90),
    # Fish
    (re.compile(r"\bsalmon\b", re.I), "FISH", 0.95),
    (re.compile(r"\btuna\b", re.I), "FISH", 0.95),
    (re.compile(r"\bcod\b", re.I), "FISH", 0.90),
    (re.compile(r"\btilapia\b", re.I), "FISH", 0.95),
    (re.compile(r"\bhaddock\b", re.I), "FISH", 0.95),
    (re.compile(r"\bhalibut\b", re.I), "FISH", 0.95),
    (re.compile(r"\btrout\b", re.I), "FISH", 0.95),
    (re.compile(r"\banchov", re.I), "FISH", 0.95),
    (re.compile(r"\bsardine", re.I), "FISH", 0.95),
    (re.compile(r"\bmackerel\b", re.I), "FISH", 0.95),
    (re.compile(r"\bherring\b", re.I), "FISH", 0.95),
    (re.compile(r"\bfish\b", re.I), "FISH", 0.85),
    # Shellfish
    (re.compile(r"\bshrimp\b", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\bprawn", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\bcrab\b", re.I), "SHELLFISH", 0.90),
    (re.compile(r"\blobster\b", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\bcrayfish\b", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\bcrawfish\b", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\bscallop", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\bclam\b", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\bmussel", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\boyster", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\bsquid\b", re.I), "SHELLFISH", 0.90),
    (re.compile(r"\bcalamari\b", re.I), "SHELLFISH", 0.95),
    (re.compile(r"\boctopus\b", re.I), "SHELLFISH", 0.90),
    # Sesame
    (re.compile(r"\bsesame\b", re.I), "SESAME", 0.95),
    (re.compile(r"\btahini\b", re.I), "SESAME", 0.95),
    # EU allergens
    (re.compile(r"\bmustard\b", re.I), "MUSTARD", 0.85),
    (re.compile(r"\bcelery\b", re.I), "CELERY", 0.90),
    (re.compile(r"\bceleriac\b", re.I), "CELERY", 0.90),
    (re.compile(r"\blupin", re.I), "LUPIN", 0.90),
    (re.compile(r"\bsulfite", re.I), "SULPHITES", 0.85),
    (re.compile(r"\bsulphite", re.I), "SULPHITES", 0.85),
]


def infer_allergens(description: str) -> list[AllergenMatch]:
    """Infer allergens from a food description using keyword matching.

    Args:
        description: Food description text (e.g., from USDA)

    Returns:
        List of AllergenMatch tuples with inferred allergens
    """
    matches: dict[str, AllergenMatch] = {}

    # Pre-check: is this a non-dairy butter product?
    has_non_dairy_butter = _NON_DAIRY_BUTTER_PATTERN.search(description) is not None

    for pattern, allergen, confidence in ALLERGEN_PATTERNS:
        # Skip dairy "butter" match if this is a non-dairy butter product
        if (
            has_non_dairy_butter
            and allergen == "MILK"
            and pattern.pattern == r"\bbutter\b"
        ):
            continue

        # Keep highest confidence match for each allergen
        is_new = allergen not in matches
        is_higher_confidence = (
            not is_new and matches[allergen].confidence_score < confidence
        )
        if pattern.search(description) and (is_new or is_higher_confidence):
            matches[allergen] = AllergenMatch(
                allergen_type=allergen,
                presence_type="CONTAINS",
                confidence_score=confidence,
            )

    return list(matches.values())
