# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Data cleaning utilities for OpenFoodFacts data import."""

import logging
import re

import pandas as pd

logger = logging.getLogger(__name__)


def parse_serving_size(serving_size_str):
    """Parse a free-text serving size string to extract quantity and standardized unit.

    Prioritizes weight/volume in parentheses over serving descriptions.

    Args:
        serving_size_str: Raw string from 'serving_size' column

    Returns:
        tuple: (quantity, unit_enum) or (None, None) if parsing fails
    """
    if (
        pd.isna(serving_size_str)
        or not serving_size_str
        or serving_size_str.strip() == ""
    ):
        return None, None

    s = serving_size_str.lower().strip()

    # First priority: Look for weight/volume in parentheses like "(29 g)" or "(28 ml)"
    paren_match = re.search(r"\(([^)]*)\)", s)
    if paren_match:
        paren_content = paren_match.group(1).strip()
        # Try to extract number and unit from parentheses
        paren_number = re.search(r"(\d+(?:\.\d+)?)", paren_content)
        if paren_number:
            paren_quantity = float(paren_number.group(1))

            # Check for weight/volume units in parentheses
            paren_unit_patterns = [
                ("ML", [r"\bml\b", r"\bmilliliter\b"]),
                ("L", [r"\bl\b(?!\w)", r"\bliter\b"]),
                ("KG", [r"\bkg\b", r"\bkilogram\b"]),
                ("G", [r"\bg\b(?!\w)", r"\bgram\b", r"\bgr\b"]),
                ("OZ", [r"\boz\b", r"\bonce\b", r"\bounce\b"]),
                ("LB", [r"\blb\b", r"\bpound\b"]),
            ]

            for enum_val, patterns in paren_unit_patterns:
                for pattern in patterns:
                    if re.search(pattern, paren_content):
                        return paren_quantity, enum_val

    # Second priority: Parse the main serving description
    quantity = None

    # Handle fractions like "1/3", "0.25", etc.
    fraction_match = re.search(r"(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)", s)
    if fraction_match:
        numerator = float(fraction_match.group(1))
        denominator = float(fraction_match.group(2))
        quantity = numerator / denominator
    else:
        # Look for decimal numbers
        number_match = re.search(r"(\d+(?:\.\d+)?)", s)
        if number_match:
            quantity = float(number_match.group(1))

    # Unit mapping - order matters (more specific first)
    unit_patterns = [
        ("TBSP", [r"\btbsp\b", r"\btablespoon\b"]),
        ("TSP", [r"\btsp\b", r"\bteaspoon\b"]),
        ("CUP", [r"\bcup\b", r"\bcups\b"]),
        ("ML", [r"\bml\b", r"\bmilliliter\b"]),
        ("L", [r"\bl\b(?!\w)", r"\bliter\b"]),
        ("KG", [r"\bkg\b", r"\bkilogram\b"]),
        ("G", [r"\bg\b(?!\w)", r"\bgram\b", r"\bgr\b"]),
        ("OZ", [r"\boz\b", r"\bonce\b", r"\bounce\b"]),
        ("LB", [r"\blb\b", r"\bpound\b"]),
        ("SLICE", [r"\bslice\b", r"\bslices\b"]),
        ("PIECE", [r"\bpiece\b", r"\bpieces\b"]),
        ("CAN", [r"\bcan\b"]),
        ("BOTTLE", [r"\bbottle\b"]),
        ("PACKET", [r"\bpacket\b", r"\bpkg\b", r"\bpackage\b"]),
        ("UNIT", [r"\bunit\b", r"\bunits\b"]),
    ]

    unit = None
    for enum_val, patterns in unit_patterns:
        for pattern in patterns:
            if re.search(pattern, s):
                unit = enum_val
                break
        if unit:
            break

    # Special cases for common serving descriptions
    if not unit:
        if any(word in s for word in ["cookie", "cracker", "whole"]) or any(
            word in s for word in ["stick", "bar"]
        ):
            unit = "PIECE"
        elif any(word in s for word in ["serving", "portion"]) or (s and quantity):
            unit = "UNIT"

    # If we found a unit but no quantity, default to 1.0
    if unit and quantity is None:
        quantity = 1.0

    return quantity, unit


def clean_numeric_value(value, column_name=None):
    """Clean and convert a value to a numeric type.

    Handles various formats and database precision limits.
    """
    if pd.isna(value) or value == "" or value is None:
        return None

    try:
        # Convert to string and strip whitespace
        str_val = str(value).strip()

        # Handle empty strings
        if not str_val or str_val.lower() == "nan":
            return None

        # Try to convert to float
        numeric_val = float(str_val)

        # Handle infinite or NaN values
        if not (numeric_val == numeric_val and abs(numeric_val) != float("inf")):
            return None

        # Apply database precision limits based on column type
        if column_name:
            # Vitamins and minerals: DECIMAL(10,6) - max value 9999.999999
            vitamin_mineral_columns = [
                "vitamin-a_100g",
                "vitamin-b6_100g",
                "vitamin-b12_100g",
                "vitamin-c_100g",
                "vitamin-d_100g",
                "vitamin-e_100g",
                "vitamin-k_100g",
                "calcium_100g",
                "iron_100g",
                "magnesium_100g",
                "potassium_100g",
                "sodium_100g",
                "zinc_100g",
            ]

            if column_name in vitamin_mineral_columns:
                if abs(numeric_val) >= 10000:  # Precision limit for DECIMAL(10,6)
                    logger.debug(
                        (
                            f"Value {numeric_val} for {column_name} exceeds "
                            "DECIMAL(10,6) limit, setting to NULL"
                        )
                    )
                    return None
                # Round to 6 decimal places
                numeric_val = round(numeric_val, 6)
            # Macro-nutrients and serving quantity: DECIMAL(8,3) - max value 99999.999
            elif (
                column_name.endswith("_100g")
                or column_name == "nutriscore_score"
                or column_name == "serving_quantity"
            ):
                if abs(numeric_val) >= 100000:  # Precision limit for DECIMAL(8,3)
                    logger.debug(
                        f"Value {numeric_val} for {column_name} exceeds "
                        "DECIMAL(8,3) limit, setting to NULL"
                    )
                    return None
                # Round to 3 decimal places
                numeric_val = round(numeric_val, 3)

        # General sanity check for extremely large values
        if abs(numeric_val) >= 1e6:  # 1 million - likely data error
            return None

        return numeric_val

    except (ValueError, TypeError):
        return None


def clean_nutriscore_grade(value):
    """Clean and validate nutriscore_grade values."""
    if pd.isna(value) or value == "" or value is None:
        return None

    try:
        # Convert to string and clean
        str_val = str(value).strip().lower()

        # Handle empty strings
        if not str_val or str_val.lower() == "nan":
            return None

        # Valid nutriscore grades are a, b, c, d, e
        if str_val in ["a", "b", "c", "d", "e"]:
            return str_val

        # Handle some common variations/errors
        if str_val.startswith("a"):
            return "a"
        elif str_val.startswith("b"):
            return "b"
        elif str_val.startswith("c"):
            return "c"
        elif str_val.startswith("d"):
            return "d"
        elif str_val.startswith("e"):
            return "e"

        # If we can't parse it, log and return None
        logger.debug(f"Invalid nutriscore_grade value: '{value}', setting to NULL")
        return None

    except (ValueError, TypeError):
        return None
