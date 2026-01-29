# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Data cleaning utilities for USDA FoodData Central data import."""

import logging
import math

logger = logging.getLogger(__name__)


def clean_numeric_value(value: float | str | None, precision: int = 3) -> float | None:
    """Clean and convert a value to a numeric type.

    Args:
        value: Raw value from USDA CSV
        precision: Number of decimal places to round to

    Returns:
        Cleaned numeric value or None if invalid
    """
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return None

    if isinstance(value, str):
        value = value.strip()
        if not value or value.lower() == "nan":
            return None

    try:
        numeric_val = float(value)

        # Handle infinite or NaN values
        if math.isnan(numeric_val) or math.isinf(numeric_val):
            return None

        # General sanity check for extremely large values
        if abs(numeric_val) >= 1e9:  # Likely data error
            logger.debug(f"Value {numeric_val} too large, setting to NULL")
            return None

        # Round to specified precision
        return round(numeric_val, precision)

    except (ValueError, TypeError):
        return None


def apply_conversion_factor(value: float | None, factor: float) -> float | None:
    """Apply a unit conversion factor to a value.

    Args:
        value: Numeric value to convert
        factor: Multiplication factor (e.g., 1000 for mg->mcg)

    Returns:
        Converted value or None
    """
    if value is None:
        return None
    return round(value * factor, 3)


def validate_fdc_id(fdc_id: int | str | None) -> int | None:
    """Validate and convert an FDC ID to an integer.

    Args:
        fdc_id: Raw FDC ID value

    Returns:
        Integer FDC ID or None if invalid
    """
    if fdc_id is None:
        return None

    if isinstance(fdc_id, str):
        fdc_id = fdc_id.strip()
        if not fdc_id:
            return None

    try:
        int_id = int(fdc_id)
        if int_id <= 0:
            return None
        return int_id
    except (ValueError, TypeError):
        return None


def clean_description(description: str | None, max_length: int = 255) -> str | None:
    """Clean a food description string.

    Args:
        description: Raw description from USDA
        max_length: Maximum allowed length

    Returns:
        Cleaned description or None
    """
    if description is None:
        return None

    if isinstance(description, float) and math.isnan(description):
        return None

    cleaned = str(description).strip()
    if not cleaned:
        return None

    # Truncate if necessary
    if len(cleaned) > max_length:
        cleaned = cleaned[: max_length - 3] + "..."

    return cleaned
