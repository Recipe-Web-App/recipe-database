# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Core import logic for USDA FoodData Central data."""

import logging
from typing import Any

from csv_validation import USDADataFiles
from data_processing import parse_foods_csv, stream_food_nutrients
from database import get_database_connection, insert_food_with_nutrients

logger = logging.getLogger(__name__)


def import_usda_data(data_files: USDADataFiles) -> dict[str, Any]:
    """Import USDA FoodData Central data from CSV files.

    This function orchestrates the multi-CSV import process:
    1. Parse food.csv to get food metadata
    2. Stream food_nutrient.csv to get nutrient values
    3. Insert complete food records into the database

    Args:
        data_files: Validated USDA data file paths

    Returns:
        dict: Summary of import results
    """
    logger.info("Starting USDA FoodData Central import")

    results: dict[str, Any] = {
        "foods_imported": 0,
        "foods_skipped": 0,
        "errors": [],
    }

    conn = None

    try:
        # Get database connection
        conn = get_database_connection()
        cursor = conn.cursor()

        # Step 1: Parse food.csv to build fdc_id -> (description, data_type) lookup
        logger.info("Step 1: Parsing food metadata...")
        foods = parse_foods_csv(data_files.food_csv)
        results["total_foods_in_source"] = len(foods)

        # Step 2: Stream food_nutrient.csv and insert complete records
        logger.info("Step 2: Processing nutrients and inserting records...")

        batch_count = 0
        for food_data in stream_food_nutrients(data_files.food_nutrient_csv, foods):
            try:
                # Insert the complete food record
                insert_food_with_nutrients(
                    cursor,
                    fdc_id=food_data.fdc_id,
                    description=food_data.description,
                    data_type=food_data.data_type,
                    macros=food_data.macros,
                    vitamins=food_data.vitamins,
                    minerals=food_data.minerals,
                )
                results["foods_imported"] += 1
                batch_count += 1

                # Commit every 1000 records for progress
                if batch_count >= 1000:
                    conn.commit()
                    logger.info(
                        f"Progress: {results['foods_imported']:,} foods imported"
                    )
                    batch_count = 0

            except Exception as e:
                results["foods_skipped"] += 1
                error_msg = f"Failed to insert food {food_data.fdc_id}: {e}"
                logger.warning(error_msg)
                if len(results["errors"]) < 100:
                    results["errors"].append(error_msg)
                conn.rollback()

        # Final commit
        conn.commit()
        logger.info("Import completed successfully")

    except Exception as e:
        error_msg = f"Import failed: {e}"
        logger.error(error_msg)
        results["errors"].append(error_msg)
        if conn:
            conn.rollback()
        raise

    finally:
        if conn:
            conn.close()
            logger.info("Database connection closed")

    return results
