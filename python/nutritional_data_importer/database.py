# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Database connection and operations for USDA FoodData Central import."""

import logging
import socket

from cli_utils.database import get_database_connection as _get_db_connection
from cli_utils.environment import get_config

logger = logging.getLogger(__name__)


def get_database_connection():
    """Get a database connection using environment variables."""
    try:
        config = get_config()

        logger.info("Database connection configuration:")
        logger.info(f"  Host: {config.host}")
        logger.info(f"  Database: {config.database}")
        logger.info(f"  User: {config.user}")
        logger.info(f"  Port: {config.port}")

        # Test DNS resolution
        logger.info(f"Testing DNS resolution for host: {config.host}")
        ip = socket.gethostbyname(config.host)
        logger.info(f"DNS resolution successful: {config.host} -> {ip}")

        conn = _get_db_connection()
        conn.autocommit = False

        # Set search path
        with conn.cursor() as cursor:
            cursor.execute("SET search_path TO recipe_manager;")
        conn.commit()

        logger.info("Database connection established")
        return conn

    except Exception as e:
        logger.error(f"Failed to connect to database: {e}")
        raise


def upsert_ingredient(
    cursor, fdc_id: int, description: str, name: str | None = None
) -> int:
    """Insert or update an ingredient, return ingredient_id.

    Args:
        cursor: Database cursor
        fdc_id: USDA FoodData Central ID
        description: USDA food description
        name: Optional canonical name (defaults to description)

    Returns:
        The ingredient_id of the inserted/updated row
    """
    ingredient_name = name or description

    cursor.execute(
        """
        INSERT INTO recipe_manager.ingredients (name, fdc_id, usda_food_description)
        VALUES (%s, %s, %s)
        ON CONFLICT (name) DO UPDATE SET
            fdc_id = EXCLUDED.fdc_id,
            usda_food_description = EXCLUDED.usda_food_description,
            updated_at = now()
        RETURNING ingredient_id
        """,
        (ingredient_name, fdc_id, description),
    )
    result = cursor.fetchone()
    return result[0]


def upsert_nutrition_profile(
    cursor,
    ingredient_id: int,
    serving_size_g: float = 100.0,
    fdc_data_type: str | None = None,
) -> int:
    """Insert or update a nutrition profile, return nutrition_profile_id.

    Args:
        cursor: Database cursor
        ingredient_id: FK to ingredients table
        serving_size_g: Reference serving size in grams
        fdc_data_type: USDA data type (foundation_food, sr_legacy_food, etc.)

    Returns:
        The nutrition_profile_id of the inserted/updated row
    """
    cursor.execute(
        """
        INSERT INTO recipe_manager.nutrition_profiles
            (ingredient_id, serving_size_g, data_source, fdc_data_type)
        VALUES (%s, %s, 'USDA', %s)
        ON CONFLICT (ingredient_id) DO UPDATE SET
            serving_size_g = EXCLUDED.serving_size_g,
            fdc_data_type = EXCLUDED.fdc_data_type,
            updated_at = now()
        RETURNING nutrition_profile_id
        """,
        (ingredient_id, serving_size_g, fdc_data_type),
    )
    result = cursor.fetchone()
    return result[0]


def upsert_macronutrients(
    cursor, profile_id: int, data: dict[str, float | None]
) -> None:
    """Insert or update macronutrients for a nutrition profile.

    Args:
        cursor: Database cursor
        profile_id: FK to nutrition_profiles table
        data: Dict of column_name -> value
    """
    columns = [
        "calories_kcal",
        "protein_g",
        "carbs_g",
        "fat_g",
        "saturated_fat_g",
        "trans_fat_g",
        "monounsaturated_fat_g",
        "polyunsaturated_fat_g",
        "cholesterol_mg",
        "sodium_mg",
        "fiber_g",
        "sugar_g",
        "added_sugar_g",
    ]

    values = [data.get(col) for col in columns]

    # Build the INSERT statement dynamically
    col_list = ", ".join(columns)
    placeholders = ", ".join(["%s"] * len(columns))
    update_clause = ", ".join([f"{col} = EXCLUDED.{col}" for col in columns])

    # Column names are from hardcoded list, values are parameterized
    cursor.execute(
        f"""
        INSERT INTO recipe_manager.macronutrients
            (nutrition_profile_id, {col_list})
        VALUES (%s, {placeholders})
        ON CONFLICT (nutrition_profile_id) DO UPDATE SET
            {update_clause}
        """,  # nosec B608
        (profile_id, *values),
    )


def upsert_vitamins(cursor, profile_id: int, data: dict[str, float | None]) -> None:
    """Insert or update vitamins for a nutrition profile.

    Args:
        cursor: Database cursor
        profile_id: FK to nutrition_profiles table
        data: Dict of column_name -> value (all in mcg)
    """
    columns = [
        "vitamin_a_mcg",
        "vitamin_b6_mcg",
        "vitamin_b12_mcg",
        "vitamin_c_mcg",
        "vitamin_d_mcg",
        "vitamin_e_mcg",
        "vitamin_k_mcg",
    ]

    values = [data.get(col) for col in columns]

    col_list = ", ".join(columns)
    placeholders = ", ".join(["%s"] * len(columns))
    update_clause = ", ".join([f"{col} = EXCLUDED.{col}" for col in columns])

    # Column names are from hardcoded list, values are parameterized
    cursor.execute(
        f"""
        INSERT INTO recipe_manager.vitamins
            (nutrition_profile_id, {col_list})
        VALUES (%s, {placeholders})
        ON CONFLICT (nutrition_profile_id) DO UPDATE SET
            {update_clause}
        """,  # nosec B608
        (profile_id, *values),
    )


def upsert_minerals(cursor, profile_id: int, data: dict[str, float | None]) -> None:
    """Insert or update minerals for a nutrition profile.

    Args:
        cursor: Database cursor
        profile_id: FK to nutrition_profiles table
        data: Dict of column_name -> value (all in mg)
    """
    columns = [
        "calcium_mg",
        "iron_mg",
        "magnesium_mg",
        "potassium_mg",
        "zinc_mg",
    ]

    values = [data.get(col) for col in columns]

    col_list = ", ".join(columns)
    placeholders = ", ".join(["%s"] * len(columns))
    update_clause = ", ".join([f"{col} = EXCLUDED.{col}" for col in columns])

    # Column names are from hardcoded list, values are parameterized
    cursor.execute(
        f"""
        INSERT INTO recipe_manager.minerals
            (nutrition_profile_id, {col_list})
        VALUES (%s, {placeholders})
        ON CONFLICT (nutrition_profile_id) DO UPDATE SET
            {update_clause}
        """,  # nosec B608
        (profile_id, *values),
    )


def insert_food_with_nutrients(
    cursor,
    fdc_id: int,
    description: str,
    data_type: str,
    macros: dict[str, float | None],
    vitamins: dict[str, float | None],
    minerals: dict[str, float | None],
) -> int:
    """Insert a complete food record with all nutrient data.

    Args:
        cursor: Database cursor
        fdc_id: USDA FoodData Central ID
        description: Food description
        data_type: USDA data type
        macros: Macronutrient values
        vitamins: Vitamin values
        minerals: Mineral values

    Returns:
        The ingredient_id of the inserted record
    """
    # Insert ingredient
    ingredient_id = upsert_ingredient(cursor, fdc_id, description)

    # Insert nutrition profile
    profile_id = upsert_nutrition_profile(
        cursor, ingredient_id, serving_size_g=100.0, fdc_data_type=data_type
    )

    # Insert nutrient data
    upsert_macronutrients(cursor, profile_id, macros)
    upsert_vitamins(cursor, profile_id, vitamins)
    upsert_minerals(cursor, profile_id, minerals)

    return ingredient_id


def get_fdc_id_to_ingredient_id_map(cursor) -> dict[int, int]:
    """Get a mapping of fdc_id to ingredient_id for all ingredients.

    Args:
        cursor: Database cursor

    Returns:
        Dict mapping fdc_id -> ingredient_id
    """
    cursor.execute("""
        SELECT fdc_id, ingredient_id
        FROM recipe_manager.ingredients
        WHERE fdc_id IS NOT NULL
        """)
    return {row[0]: row[1] for row in cursor.fetchall()}


def insert_ingredient_portions(
    cursor,
    portions: list[dict],
    fdc_to_ingredient: dict[int, int],
) -> tuple[int, int]:
    """Batch insert ingredient portions.

    Args:
        cursor: Database cursor
        portions: List of portion dicts with keys:
            fdc_id, portion_description, unit, modifier, gram_weight, sequence_number
        fdc_to_ingredient: Mapping of fdc_id -> ingredient_id

    Returns:
        Tuple of (inserted_count, skipped_count)
    """
    inserted = 0
    skipped = 0

    for portion in portions:
        fdc_id = portion["fdc_id"]
        ingredient_id = fdc_to_ingredient.get(fdc_id)

        if ingredient_id is None:
            skipped += 1
            continue

        try:
            cursor.execute(
                """
                INSERT INTO recipe_manager.ingredient_portions
                    (ingredient_id, portion_description, unit, modifier,
                     gram_weight, sequence_number, data_source)
                VALUES (%s, %s, %s, %s, %s, %s, 'USDA')
                ON CONFLICT (ingredient_id, portion_description) DO UPDATE SET
                    unit = EXCLUDED.unit,
                    modifier = EXCLUDED.modifier,
                    gram_weight = EXCLUDED.gram_weight,
                    sequence_number = EXCLUDED.sequence_number,
                    updated_at = now()
                """,
                (
                    ingredient_id,
                    portion["portion_description"],
                    portion["unit"],
                    portion.get("modifier"),
                    portion["gram_weight"],
                    portion.get("sequence_number"),
                ),
            )
            inserted += 1
        except Exception as e:
            logger.warning(f"Failed to insert portion for fdc_id {fdc_id}: {e}")
            skipped += 1

    return inserted, skipped
