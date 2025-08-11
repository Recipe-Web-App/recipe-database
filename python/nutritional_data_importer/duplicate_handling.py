# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Duplicate handling and merging logic for OpenFoodFacts data import."""

import contextlib
import logging

import pandas as pd
from allergen_mapping import map_allergens_to_enum
from data_cleaning import clean_numeric_value, clean_nutriscore_grade
from data_processing import prepare_row_data, should_update_field
from database import (
    batch_query_existing_products,
    get_nutritional_info_table,
    get_sqlalchemy_engine,
    insert_single_row,
    update_existing_product_batch,
)
from sqlalchemy import text, update

logger = logging.getLogger(__name__)


def merge_duplicate_with_database(conn, new_row, csv_columns, target_columns, results):
    """Query existing product from database and update with merged data."""
    try:
        product_name_clean = str(new_row.get("product_name")).strip().lower()

        # Create a savepoint for this operation
        with conn.cursor() as cursor:
            cursor.execute("SAVEPOINT merge_duplicate")

        # Query existing product from database
        with conn.cursor() as cursor:
            # Find existing product by product name (case-insensitive)
            cursor.execute(
                """
                SELECT * FROM nutritional_info
                WHERE LOWER(TRIM(product_name)) = %s
                LIMIT 1
            """,
                (product_name_clean,),
            )

            existing_row = cursor.fetchone()
            if not existing_row:
                # No existing product found, treat as new
                cursor.execute("RELEASE SAVEPOINT merge_duplicate")
                row_data = prepare_row_data(new_row, csv_columns, target_columns)
                return insert_single_row(conn, target_columns, row_data, results)

            # Get column names from cursor description
            db_columns = [desc[0] for desc in cursor.description]
            existing_dict = dict(zip(db_columns, existing_row))

            # Build UPDATE query for non-null values only
            update_fields = []
            update_values = []

            for col in target_columns:
                if col == "code":  # Skip primary identifier
                    continue

                db_col = col.replace("-", "_")  # Convert CSV names to DB names
                new_value = new_row.get(col)
                existing_value = existing_dict.get(db_col)

                # Clean and validate the new value
                if col in ["nutriscore_score"] or col.endswith("_100g"):
                    new_value = clean_numeric_value(new_value, col)
                elif col == "nutriscore_grade":
                    new_value = clean_nutriscore_grade(new_value)
                elif new_value is not None and not pd.isna(new_value):
                    new_value = str(new_value).strip()
                    if not new_value:
                        new_value = None
                else:
                    new_value = None

                # Only update if new value improves on existing
                if should_update_field(existing_value, new_value, col):
                    update_fields.append(f"{db_col} = %s")
                    update_values.append(new_value)

            # Execute update if we have fields to update
            if update_fields:
                # Get SQLAlchemy table object
                table = get_nutritional_info_table()
                engine = get_sqlalchemy_engine()

                # Build update dictionary from changed fields
                update_dict = {}
                for i, field_expr in enumerate(update_fields):
                    if " = " in field_expr:
                        field_name = field_expr.split(" = ")[0].strip()
                        update_dict[field_name] = update_values[i]

                # Add updated_at timestamp
                update_dict["updated_at"] = text("now()")

                with engine.connect() as sqlalchemy_conn:
                    stmt = (
                        update(table)
                        .where(
                            table.c.nutritional_info_id
                            == existing_dict["nutritional_info_id"]
                        )
                        .values(update_dict)
                    )

                    result = sqlalchemy_conn.execute(stmt)
                    sqlalchemy_conn.commit()

                    if result.rowcount > 0:
                        results["rows_imported"] += 1  # Count as successful merge

            # Release the savepoint
            cursor.execute("RELEASE SAVEPOINT merge_duplicate")

    except Exception as e:
        # Rollback to savepoint on error
        with contextlib.suppress(Exception), conn.cursor() as cursor:
            cursor.execute("ROLLBACK TO SAVEPOINT merge_duplicate")

        error_msg = (
            f"Failed to merge duplicate product "
            f"'{new_row.get('product_name', 'Unknown')}': {e}"
        )
        logger.debug(error_msg)  # Reduce log level to debug
        # Don't add to results['errors'] to avoid spam


def process_duplicate_queue_batch(conn, duplicate_queue, results):
    """Process queued duplicates in batch for better performance."""
    if not duplicate_queue:
        return

    logger.info(f"📊 Processing {len(duplicate_queue)} queued duplicates in batch...")

    try:
        # duplicate_queue is now a dict: product_name_clean -> queue_item
        product_names = list(duplicate_queue.keys())
        existing_products = batch_query_existing_products(conn, product_names)

        # Process each duplicate
        processed_count = 0
        failed_count = 0

        for product_name, queue_item in duplicate_queue.items():
            existing_product = existing_products.get(product_name)

            if existing_product:
                # Convert raw row to database format and update
                merged_db_row = convert_raw_row_to_db_format(
                    existing_product, queue_item["row"], queue_item["target_columns"]
                )
                success = update_existing_product_batch(
                    conn, existing_product, merged_db_row, queue_item["target_columns"]
                )

                if success:
                    processed_count += 1
                    results["rows_merged_duplicates"] += 1
                else:
                    failed_count += 1
                    # Stop processing if we have too many failures
                    if failed_count >= 5:
                        logger.error(
                            (
                                f"🚨 STOPPING: Too many merge failures "
                                f"({failed_count} failures)"
                            )
                        )
                        logger.error(
                            "💡 This indicates a systematic issue with the "
                            "duplicate merging logic"
                        )
                        logger.error("🔧 Please fix the merge logic before continuing")
                        raise Exception(
                            f"Duplicate merge failures exceed threshold "
                            f"({failed_count} failures)"
                        )

        if failed_count > 0:
            logger.warning(
                (
                    f"⚠️  Batch completed with {failed_count} merge failures out of "
                    f"{len(duplicate_queue)} attempts"
                )
            )

        logger.info(f"✅ Batch processed {processed_count} unique duplicate products")

    except Exception as e:
        error_msg = f"❌ DUPLICATE BATCH PROCESSING FAILED: {e}"
        logger.error(error_msg)
        results["errors"].append(f"Batch duplicate processing failed: {e}")
        # Re-raise to stop the import
        raise


def merge_single_duplicate(existing_row, new_row, target_columns):
    """Merge new row data with existing database row."""
    merged_row = existing_row.copy()

    for col in target_columns:
        if col == "code":  # Skip primary identifier
            continue

        db_col = col.replace("-", "_")
        existing_value = existing_row.get(db_col)
        new_value = new_row.get(col)

        # Special handling for allergens
        if col == "allergens":
            # Convert existing raw allergen string to enum format
            if existing_value and isinstance(existing_value, str):
                existing_allergens = map_allergens_to_enum(existing_value)
            else:
                existing_allergens = existing_value if existing_value else []

            # Convert new raw allergen string to enum format
            if new_value and isinstance(new_value, str):
                new_allergens = map_allergens_to_enum(new_value)
            else:
                new_allergens = new_value if new_value else []

            # Combine and deduplicate allergens
            if existing_allergens or new_allergens:
                combined_allergens = list(set(existing_allergens + new_allergens))
                merged_row[db_col] = combined_allergens
            continue

        # Clean and validate the new value for other fields
        if col in ["nutriscore_score"] or col.endswith("_100g"):
            new_value = clean_numeric_value(new_value, col)
        elif col == "nutriscore_grade":
            new_value = clean_nutriscore_grade(new_value)
        elif new_value is not None and not pd.isna(new_value):
            new_value = str(new_value).strip()
            if not new_value:
                new_value = None
        else:
            new_value = None

        # Apply merge logic
        if should_update_field(existing_value, new_value, col):
            merged_row[db_col] = new_value

    return merged_row


def convert_raw_row_to_db_format(existing_product, raw_row, target_columns):
    """Convert raw CSV row to database format for comparison."""
    db_row = existing_product.copy()

    for col in target_columns:
        if col == "code":  # Skip primary identifier
            continue

        db_col = col.replace("-", "_")  # Convert CSV names to DB names
        raw_value = raw_row.get(col)
        existing_value = existing_product.get(db_col)

        # Special handling for allergens - APPLY MAPPING
        if col == "allergens":
            if raw_value and not pd.isna(raw_value):
                clean_value = map_allergens_to_enum(raw_value)
            else:
                clean_value = None
        # Clean and validate other values
        elif col in ["nutriscore_score"] or col.endswith("_100g"):
            clean_value = clean_numeric_value(raw_value, col)
        elif col == "nutriscore_grade":
            clean_value = clean_nutriscore_grade(raw_value)
        elif raw_value is not None and not pd.isna(raw_value):
            clean_value = str(raw_value).strip()
            if not clean_value:
                clean_value = None
        else:
            clean_value = None

        # Apply merge logic
        if should_update_field(existing_value, clean_value, col):
            db_row[db_col] = clean_value

    return db_row


def merge_queue_items(existing_row, new_row, csv_columns, target_columns):
    """Merge a new row with an existing queued row."""
    merged_row = existing_row.copy()

    for col in csv_columns:
        existing_value = existing_row.get(col)
        new_value = new_row.get(col)

        # If existing value is missing/null, use new value
        if (
            pd.isna(existing_value) or existing_value is None or existing_value == ""
        ) and not (pd.isna(new_value) or new_value is None or new_value == ""):
            merged_row[col] = new_value

        # For numeric nutrition fields, prefer non-zero values
        elif (
            col
            in ["energy-kcal_100g", "proteins_100g", "carbohydrates_100g", "fat_100g"]
            and col in target_columns
        ):
            try:
                existing_num = (
                    float(existing_value) if not pd.isna(existing_value) else 0
                )
                new_num = float(new_value) if not pd.isna(new_value) else 0

                # If existing is 0 but new has a value, use new
                if existing_num == 0 and new_num > 0:
                    merged_row[col] = new_value
                # Otherwise keep existing (first occurrence preference)
            except (ValueError, TypeError):
                pass  # Keep existing value

        # Special handling for allergens (now arrays)
        elif col == "allergens":
            existing_allergens = (
                map_allergens_to_enum(existing_value) if existing_value else []
            )
            new_allergens = map_allergens_to_enum(new_value) if new_value else []

            # Combine allergen arrays, removing duplicates
            combined_allergens = list(set(existing_allergens + new_allergens))
            # Store the combined raw string for now (will be processed later)
            merged_row[col] = (
                ", ".join([f"en:{allergen.lower()}" for allergen in combined_allergens])
                if combined_allergens
                else None
            )

        # For text fields, prefer longer/more detailed content
        elif col in ["brands", "categories"] and len(str(new_value)) > len(
            str(existing_value)
        ):
            merged_row[col] = new_value

    return merged_row


def merge_database_row(existing_dict, new_row, target_columns):
    """Merge new row data with existing database row."""
    merged_data = []

    for col in target_columns:
        db_col = col.replace("-", "_")  # Convert CSV names to DB names
        existing_value = existing_dict.get(db_col)
        new_value = new_row.get(col)

        # Use merging logic to determine best value
        if should_update_field(existing_value, new_value, col):
            merged_data.append(new_value)
        else:
            merged_data.append(existing_value)

    return merged_data
