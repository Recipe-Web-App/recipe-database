# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Data processing utilities for USDA FoodData Central import.

Handles parsing and transforming USDA CSV data into database-ready format.
"""

import contextlib
import logging
from pathlib import Path
from typing import Iterator

import pandas as pd

from .allergen_inference import AllergenMatch, infer_allergens
from .data_cleaning import (
    apply_conversion_factor,
    clean_description,
    clean_numeric_value,
)
from .food_group_mapping import get_food_group
from .usda_mapping import TRACKED_NUTRIENT_IDS, get_db_column_for_nutrient

logger = logging.getLogger(__name__)


class FoodNutrientData:
    """Container for a food item with its nutrients."""

    def __init__(
        self,
        fdc_id: int,
        description: str,
        data_type: str,
        food_category_id: int | None = None,
    ):
        """Initialize with food metadata from USDA food.csv."""
        self.fdc_id = fdc_id
        self.description = description
        self.data_type = data_type
        self.food_group = get_food_group(food_category_id)
        self.macros: dict[str, float | None] = {}
        self.vitamins: dict[str, float | None] = {}
        self.minerals: dict[str, float | None] = {}
        self.allergens: list[AllergenMatch] = infer_allergens(description)

    def add_nutrient(self, nutrient_id: int, amount: float) -> bool:
        """Add a nutrient value to the appropriate category.

        Args:
            nutrient_id: USDA nutrient ID
            amount: Raw amount from USDA

        Returns:
            True if nutrient was added, False if not tracked
        """
        mapping = get_db_column_for_nutrient(nutrient_id)
        if mapping is None:
            return False

        table_type, column, conversion_factor = mapping
        converted_value = apply_conversion_factor(
            clean_numeric_value(amount), conversion_factor
        )

        if table_type == "macronutrients":
            self.macros[column] = converted_value
        elif table_type == "vitamins":
            self.vitamins[column] = converted_value
        elif table_type == "minerals":
            self.minerals[column] = converted_value

        return True

    def is_importable(self) -> bool:
        """Check if this food should be imported.

        Only imports complete food entries (foundation_food or sr_legacy_food).
        Filters out sub-samples and agricultural acquisitions.

        Returns:
            True if this is a complete food with all core macros
        """
        # Only import complete food types (not sub-samples or acquisitions)
        valid_types = {"foundation_food", "sr_legacy_food"}
        if self.data_type not in valid_types:
            return False

        # Require all core macros for recipe calculations
        core_macros = ["calories_kcal", "protein_g", "fat_g", "carbs_g"]
        return all(self.macros.get(m) is not None for m in core_macros)


def parse_foods_csv(food_csv: Path) -> dict[int, tuple[str, str, int | None]]:
    """Parse food.csv to extract fdc_id -> (description, data_type, category_id) mapping.

    Args:
        food_csv: Path to food.csv

    Returns:
        Dict mapping fdc_id to (description, data_type, food_category_id)
    """
    logger.info(f"Parsing food.csv from {food_csv}")

    foods: dict[int, tuple[str, str, int | None]] = {}

    # Read in chunks to handle large files
    for chunk in pd.read_csv(food_csv, chunksize=10000, low_memory=False):
        for _, row in chunk.iterrows():
            fdc_id = row.get("fdc_id")
            description = row.get("description")
            data_type = row.get("data_type", "")
            food_category_id = row.get("food_category_id")

            if pd.isna(fdc_id) or pd.isna(description):
                continue

            try:
                fdc_id = int(fdc_id)
                description = clean_description(str(description))
                category_id = (
                    int(food_category_id) if not pd.isna(food_category_id) else None
                )
                if description:
                    foods[fdc_id] = (
                        description,
                        str(data_type) if data_type else "",
                        category_id,
                    )
            except (ValueError, TypeError):
                continue

    logger.info(f"Parsed {len(foods)} foods from food.csv")
    return foods


def parse_nutrients_csv(nutrient_csv: Path) -> dict[int, str]:
    """Parse nutrient.csv to build nutrient_id -> name mapping.

    Args:
        nutrient_csv: Path to nutrient.csv

    Returns:
        Dict mapping nutrient_id to nutrient name
    """
    logger.info(f"Parsing nutrient.csv from {nutrient_csv}")

    nutrients: dict[int, str] = {}

    df = pd.read_csv(nutrient_csv)
    for _, row in df.iterrows():
        nutrient_id = row.get("id")
        name = row.get("name", "")

        if pd.isna(nutrient_id):
            continue

        try:
            nutrients[int(nutrient_id)] = str(name)
        except (ValueError, TypeError):
            continue

    logger.info(f"Parsed {len(nutrients)} nutrients from nutrient.csv")
    return nutrients


def stream_food_nutrients(
    food_nutrient_csv: Path,
    foods: dict[int, tuple[str, str, int | None]],
    chunk_size: int = 50000,
) -> Iterator[FoodNutrientData]:
    """Stream food nutrient data, yielding complete FoodNutrientData objects.

    This processes the food_nutrient.csv file which contains nutrient values
    for each food. Since a single food has multiple nutrient rows, we accumulate
    nutrients until we see a new fdc_id.

    Args:
        food_nutrient_csv: Path to food_nutrient.csv
        foods: Dict from parse_foods_csv (fdc_id -> description, data_type, category_id)
        chunk_size: Rows per chunk for memory efficiency

    Yields:
        FoodNutrientData objects with complete nutrient data
    """
    logger.info(f"Streaming food_nutrient.csv from {food_nutrient_csv}")

    current_food: FoodNutrientData | None = None
    current_fdc_id: int | None = None
    rows_processed = 0

    for chunk in pd.read_csv(food_nutrient_csv, chunksize=chunk_size, low_memory=False):
        for _, row in chunk.iterrows():
            rows_processed += 1

            fdc_id = row.get("fdc_id")
            nutrient_id = row.get("nutrient_id")
            amount = row.get("amount")

            if pd.isna(fdc_id) or pd.isna(nutrient_id):
                continue

            try:
                fdc_id = int(fdc_id)
                nutrient_id = int(nutrient_id)
            except (ValueError, TypeError):
                continue

            # Skip nutrients we don't track
            if nutrient_id not in TRACKED_NUTRIENT_IDS:
                continue

            # Skip foods we don't have metadata for
            if fdc_id not in foods:
                continue

            # If we've moved to a new food, yield the previous one if it has data
            if fdc_id != current_fdc_id:
                if current_food is not None and current_food.is_importable():
                    yield current_food

                # Start new food
                description, data_type, food_category_id = foods[fdc_id]
                current_food = FoodNutrientData(
                    fdc_id, description, data_type, food_category_id
                )
                current_fdc_id = fdc_id

            # Add nutrient to current food
            if current_food is not None and not pd.isna(amount):
                with contextlib.suppress(ValueError, TypeError):
                    current_food.add_nutrient(nutrient_id, float(amount))

        if rows_processed % 500000 == 0:
            logger.info(f"Processed {rows_processed:,} nutrient rows...")

    # Don't forget the last food (if it has data)
    if current_food is not None and current_food.is_importable():
        yield current_food

    logger.info(f"Finished processing {rows_processed:,} nutrient rows")
