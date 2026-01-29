# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Database connection and operations for USDA FoodData Central import."""

import logging
import os
import socket

import psycopg2

logger = logging.getLogger(__name__)


def get_database_connection():
    """Get a database connection using environment variables."""
    try:
        host = os.getenv("POSTGRES_HOST")
        database = os.getenv("POSTGRES_DB")
        user = os.getenv("DB_MAINT_USER")
        password = os.getenv("DB_MAINT_PASSWORD")
        port = os.getenv("POSTGRES_PORT", "5432")

        logger.info("Database connection configuration:")
        logger.info(f"  POSTGRES_HOST: {host or 'NOT SET'}")
        logger.info(f"  POSTGRES_DB: {database or 'NOT SET'}")
        logger.info(f"  DB_MAINT_USER: {user or 'NOT SET'}")
        logger.info(f"  POSTGRES_PORT: {port}")

        missing_vars = []
        if not host:
            missing_vars.append("POSTGRES_HOST")
        if not database:
            missing_vars.append("POSTGRES_DB")
        if not user:
            missing_vars.append("DB_MAINT_USER")
        if not password:
            missing_vars.append("DB_MAINT_PASSWORD")

        if missing_vars:
            raise ValueError(
                f"Missing required environment variables: {', '.join(missing_vars)}"
            )

        # Test DNS resolution
        logger.info(f"Testing DNS resolution for host: {host}")
        ip = socket.gethostbyname(host)
        logger.info(f"DNS resolution successful: {host} -> {ip}")

        conn = psycopg2.connect(
            host=host,
            database=database,
            user=user,
            password=password,
            port=port,
        )
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
