# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""USDA FoodData Central nutrient ID mappings.

Maps USDA nutrient IDs to database columns with unit conversion factors.
Reference: https://fdc.nal.usda.gov/
"""

from typing import NamedTuple


class NutrientMapping(NamedTuple):
    """Mapping for a single nutrient."""

    usda_id: int
    usda_unit: str
    conversion_factor: float  # Multiply USDA value by this to get DB value


# Macronutrients: db_column -> NutrientMapping
MACRONUTRIENT_MAPPING: dict[str, NutrientMapping] = {
    "calories_kcal": NutrientMapping(1008, "kcal", 1.0),
    "protein_g": NutrientMapping(1003, "g", 1.0),
    "carbs_g": NutrientMapping(1005, "g", 1.0),
    "fat_g": NutrientMapping(1004, "g", 1.0),
    "saturated_fat_g": NutrientMapping(1258, "g", 1.0),
    "trans_fat_g": NutrientMapping(1257, "g", 1.0),
    "monounsaturated_fat_g": NutrientMapping(1292, "g", 1.0),
    "polyunsaturated_fat_g": NutrientMapping(1293, "g", 1.0),
    "cholesterol_mg": NutrientMapping(1253, "mg", 1.0),
    "sodium_mg": NutrientMapping(1093, "mg", 1.0),
    "fiber_g": NutrientMapping(1079, "g", 1.0),
    "sugar_g": NutrientMapping(2000, "g", 1.0),
    "added_sugar_g": NutrientMapping(1235, "g", 1.0),
}

# Vitamins: db_column -> NutrientMapping
# Note: Some vitamins in USDA are in mg, we store in mcg (multiply by 1000)
VITAMIN_MAPPING: dict[str, NutrientMapping] = {
    "vitamin_a_mcg": NutrientMapping(1106, "mcg", 1.0),
    "vitamin_b6_mcg": NutrientMapping(1175, "mg", 1000.0),  # mg -> mcg
    "vitamin_b12_mcg": NutrientMapping(1178, "mcg", 1.0),
    "vitamin_c_mcg": NutrientMapping(1162, "mg", 1000.0),  # mg -> mcg
    "vitamin_d_mcg": NutrientMapping(1114, "mcg", 1.0),
    "vitamin_e_mcg": NutrientMapping(1109, "mg", 1000.0),  # mg -> mcg
    "vitamin_k_mcg": NutrientMapping(1185, "mcg", 1.0),
}

# Minerals: db_column -> NutrientMapping
MINERAL_MAPPING: dict[str, NutrientMapping] = {
    "calcium_mg": NutrientMapping(1087, "mg", 1.0),
    "iron_mg": NutrientMapping(1089, "mg", 1.0),
    "magnesium_mg": NutrientMapping(1090, "mg", 1.0),
    "potassium_mg": NutrientMapping(1092, "mg", 1.0),
    "zinc_mg": NutrientMapping(1095, "mg", 1.0),
}

# Build reverse mapping: usda_id -> (table_type, db_column, conversion_factor)
USDA_ID_TO_COLUMN: dict[int, tuple[str, str, float]] = {}

for col, mapping in MACRONUTRIENT_MAPPING.items():
    USDA_ID_TO_COLUMN[mapping.usda_id] = (
        "macronutrients",
        col,
        mapping.conversion_factor,
    )

for col, mapping in VITAMIN_MAPPING.items():
    USDA_ID_TO_COLUMN[mapping.usda_id] = ("vitamins", col, mapping.conversion_factor)

for col, mapping in MINERAL_MAPPING.items():
    USDA_ID_TO_COLUMN[mapping.usda_id] = ("minerals", col, mapping.conversion_factor)

# Set of all USDA nutrient IDs we care about
TRACKED_NUTRIENT_IDS: set[int] = set(USDA_ID_TO_COLUMN.keys())


def get_db_column_for_nutrient(nutrient_id: int) -> tuple[str, str, float] | None:
    """Get the database table, column name, and conversion factor for a USDA nutrient ID.

    Args:
        nutrient_id: USDA FoodData Central nutrient ID

    Returns:
        Tuple of (table_name, column_name, conversion_factor) or None if not tracked
    """
    return USDA_ID_TO_COLUMN.get(nutrient_id)
