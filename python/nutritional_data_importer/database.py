# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Database connection and operations for OpenFoodFacts data import."""

import logging
import os

import psycopg2
from data_cleaning import clean_numeric_value
from sqlalchemy import MetaData, Table, create_engine, select, text, update
from sqlalchemy.dialects.postgresql import insert as pg_insert

logger = logging.getLogger(__name__)

# Global SQLAlchemy objects
_engine = None
_metadata = None
_nutritional_info_table = None


def get_sqlalchemy_engine():
    """Get SQLAlchemy engine using environment variables."""
    global _engine
    if _engine is None:
        database_url = (
            f"postgresql://{os.getenv('DB_USERNAME')}:"
            f"{os.getenv('DB_PASSWORD')}@{os.getenv('DB_HOST')}:"
            f"{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME')}"
        )
        _engine = create_engine(database_url)
    return _engine


def get_nutritional_info_table():
    """Get SQLAlchemy Table object for nutritional_info."""
    global _metadata, _nutritional_info_table
    if _nutritional_info_table is None:
        engine = get_sqlalchemy_engine()
        _metadata = MetaData()
        _nutritional_info_table = Table(
            "nutritional_info", _metadata, schema="recipe_manager", autoload_with=engine
        )
    return _nutritional_info_table


def get_database_connection():
    """Get a database connection using environment variables."""
    try:
        # Get database configuration from environment
        db_config = {
            "host": os.getenv("POSTGRES_HOST", "localhost"),
            "database": os.getenv("POSTGRES_DB", "recipe_manager"),
            "user": os.getenv("DB_MAINT_USER", "db_maint_user"),
            "password": os.getenv("DB_MAINT_PASSWORD", ""),
            "port": os.getenv("POSTGRES_PORT", "5432"),
        }

        logger.info(
            (
                f"Connecting to database: {db_config['user']}@{db_config['host']}:"
                f"{db_config['port']}/{db_config['database']}"
            )
        )

        # Create connection
        conn = psycopg2.connect(**db_config)
        conn.autocommit = False  # Use transactions

        # Set search path to recipe_manager schema
        with conn.cursor() as cursor:
            cursor.execute("SET search_path TO recipe_manager;")
        conn.commit()

        logger.info("✅ Database connection established")
        return conn

    except Exception as e:
        logger.error(f"Failed to connect to database: {e}")
        raise


def get_table_columns():
    """Define the mapping between CSV columns and database columns."""
    return [
        # Basic identifiers and info
        "code",
        "product_name",
        "generic_name",
        "brands",
        "categories",
        "serving_quantity",
        "serving_measurement",
        # Classification data
        "allergens",
        "food_groups",
        "nutriscore_score",
        "nutriscore_grade",
        # Macro-nutrients
        "energy-kcal_100g",  # CSV name with dash
        "carbohydrates_100g",
        "cholesterol_100g",
        "proteins_100g",
        # Sugars
        "sugars_100g",
        "added-sugars_100g",  # CSV name with dash
        # Fats
        "fat_100g",
        "saturated-fat_100g",  # CSV name with dash
        "monounsaturated-fat_100g",  # CSV name with dash
        "polyunsaturated-fat_100g",  # CSV name with dash
        "omega-3-fat_100g",  # CSV name with dash
        "omega-6-fat_100g",  # CSV name with dash
        "omega-9-fat_100g",  # CSV name with dash
        "trans-fat_100g",  # CSV name with dash
        # Fibers
        "fiber_100g",
        "soluble-fiber_100g",  # CSV name with dash
        "insoluble-fiber_100g",  # CSV name with dash
        # Vitamins
        "vitamin-a_100g",  # CSV name with dash
        "vitamin-b6_100g",  # CSV name with dash
        "vitamin-b12_100g",  # CSV name with dash
        "vitamin-c_100g",  # CSV name with dash
        "vitamin-d_100g",  # CSV name with dash
        "vitamin-e_100g",  # CSV name with dash
        "vitamin-k_100g",  # CSV name with dash
        # Minerals
        "calcium_100g",
        "iron_100g",
        "magnesium_100g",
        "potassium_100g",
        "sodium_100g",
        "zinc_100g",
    ]


def insert_single_row(conn, target_columns, row_data, results):
    """Insert a single row (fallback for when database lookup fails)."""
    try:
        # Get SQLAlchemy table object
        table = get_nutritional_info_table()
        engine = get_sqlalchemy_engine()

        # Sanitize column names and validate against table schema
        db_columns = [col.replace("-", "_") for col in target_columns]
        valid_columns = [col for col in db_columns if col in table.columns]

        if len(valid_columns) != len(db_columns):
            invalid_cols = set(db_columns) - set(table.columns.keys())
            raise ValueError(f"Invalid column names: {invalid_cols}")

        # Create data dictionary for the row
        row_dict = dict(zip(valid_columns, row_data))

        # Create PostgreSQL INSERT with ON CONFLICT using SQLAlchemy
        stmt = pg_insert(table).values(row_dict)

        # Build update dictionary for ON CONFLICT clause (exclude primary key)
        update_dict = {
            col.name: stmt.excluded[col.name]
            for col in table.columns
            if col.name in valid_columns and col.name != "code"
        }
        update_dict["updated_at"] = text("now()")

        stmt = stmt.on_conflict_do_update(index_elements=["code"], set_=update_dict)

        with engine.connect() as sqlalchemy_conn:
            result = sqlalchemy_conn.execute(stmt)
            sqlalchemy_conn.commit()
            if result.rowcount > 0:
                results["rows_imported"] += 1

    except Exception as e:
        error_msg = f"Failed to insert single row: {e}"
        logger.error(error_msg)
        results["errors"].append(error_msg)


def insert_batch_data(conn, target_columns, batch_data):
    """Insert a batch of data into the database."""
    imported = 0
    duplicates = 0
    errors = []

    try:
        # Get SQLAlchemy table object
        table = get_nutritional_info_table()
        engine = get_sqlalchemy_engine()

        # Sanitize column names and validate against table schema
        db_columns = [col.replace("-", "_") for col in target_columns]
        valid_columns = [col for col in db_columns if col in table.columns]

        if len(valid_columns) != len(db_columns):
            invalid_cols = set(db_columns) - set(table.columns.keys())
            raise ValueError(f"Invalid column names: {invalid_cols}")

        # Convert batch data to list of dictionaries
        batch_dicts = []
        for row_data in batch_data:
            row_dict = dict(zip(valid_columns, row_data))

            # Handle special case for allergens column (cast to enum array)
            if "allergens" in row_dict and row_dict["allergens"]:
                # SQLAlchemy will handle the type casting automatically
                pass

            batch_dicts.append(row_dict)

        # Create PostgreSQL INSERT with ON CONFLICT using SQLAlchemy
        stmt = pg_insert(table)

        # Build update dictionary for ON CONFLICT clause (exclude primary key)
        update_dict = {
            col.name: stmt.excluded[col.name]
            for col in table.columns
            if col.name in valid_columns and col.name != "code"
        }
        update_dict["updated_at"] = text("now()")

        stmt = stmt.on_conflict_do_update(index_elements=["code"], set_=update_dict)

        with engine.connect() as sqlalchemy_conn:
            # Execute batch insert
            sqlalchemy_conn.execute(stmt, batch_dicts)
            sqlalchemy_conn.commit()
            # For ON CONFLICT DO UPDATE, rowcount is not reliable
            # Count the actual rows processed instead
            imported = len(batch_data)

    except Exception as e:
        # Enhanced error reporting
        error_msg = f"Batch insert failed: {e}"
        logger.error(error_msg)

        # Log detailed diagnostic information
        logger.error("📊 BATCH INSERT DIAGNOSTICS:")
        logger.error(f"   Batch size: {len(batch_data)} rows")
        logger.error(f"   Target columns: {len(target_columns)}")

        # Check for problematic values in the batch
        logger.error("🔍 SCANNING BATCH FOR PROBLEMATIC VALUES:")
        problematic_rows = []

        for row_idx, row_data in enumerate(batch_data[:5]):  # Check first 5 rows
            logger.error(f"   Row {row_idx + 1} data:")
            has_issues = False

            for col_idx, (col_name, value) in enumerate(zip(target_columns, row_data)):
                db_col_name = col_name.replace("-", "_")

                if value is not None and isinstance(value, (int, float)):
                    # Check for values that might cause precision issues
                    if col_name in [
                        "vitamin_a_100g",
                        "vitamin_b6_100g",
                        "vitamin_b12_100g",
                        "vitamin_c_100g",
                        "vitamin_d_100g",
                        "vitamin_e_100g",
                        "vitamin_k_100g",
                        "calcium_100g",
                        "iron_100g",
                        "magnesium_100g",
                        "potassium_100g",
                        "sodium_100g",
                        "zinc_100g",
                    ]:
                        if abs(value) >= 10000:
                            logger.error(
                                (
                                    f"     🚨 {db_col_name}: {value} "
                                    "(EXCEEDS DECIMAL(10,6) LIMIT)"
                                )
                            )
                            has_issues = True
                        elif abs(value) >= 1000:
                            logger.error(f"     ⚠️  {db_col_name}: {value} (HIGH)")
                        elif value != 0:
                            logger.error(f"     ✅ {db_col_name}: {value}")
                    elif col_name.endswith("_100g") or col_name == "nutriscore_score":
                        if abs(value) >= 100000:
                            logger.error(
                                (
                                    f"     🚨 {db_col_name}: {value} "
                                    "(EXCEEDS DECIMAL(8,3) LIMIT)"
                                )
                            )
                            has_issues = True
                        elif abs(value) >= 10000:
                            logger.error(f"     ⚠️  {db_col_name}: {value} (HIGH)")
                        elif value != 0:
                            logger.error(f"     ✅ {db_col_name}: {value}")
                elif (
                    value is not None and col_idx < 10
                ):  # Show first 10 non-numeric values
                    logger.error(f"     📝 {db_col_name}: '{value}'")

            if has_issues:
                problematic_rows.append(row_idx)

        if len(batch_data) > 5:
            logger.error(f"   ... and {len(batch_data) - 5} more rows not shown")

        # Try to recover by inserting rows individually
        logger.error("🔄 Attempting individual row inserts to salvage good data...")

        # Rollback the failed batch transaction
        conn.rollback()

        # Try inserting each row individually using insert_single_row
        success_count = 0
        fail_count = 0
        individual_results = {"rows_imported": 0, "errors": []}

        for row_idx, row_data in enumerate(batch_data):
            try:
                insert_single_row(conn, target_columns, row_data, individual_results)
                success_count += 1
            except Exception as row_error:
                fail_count += 1
                if fail_count <= 5:  # Log first 5 individual failures
                    product_code = row_data[0] if row_data else "unknown"
                    logger.error(
                        (
                            f"     Row {row_idx + 1} (code: {product_code}) "
                            f"failed: {row_error}"
                        )
                    )

        imported = success_count
        logger.error(
            (
                f"🔄 Individual insert results: {success_count} succeeded, "
                f"{fail_count} failed"
            )
        )

        if fail_count > 0:
            errors.append(
                (
                    "Batch failed, individual recovery: "
                    f"{success_count}/{len(batch_data)} rows saved"
                )
            )

        # Update the main error message
        errors.append(error_msg)

    return imported, duplicates, errors


def batch_query_existing_products(conn, product_names):
    """Query multiple existing products in a single database call."""
    if not product_names:
        return {}

    try:
        # Get SQLAlchemy table object
        table = get_nutritional_info_table()
        engine = get_sqlalchemy_engine()

        with engine.connect() as sqlalchemy_conn:
            # Use SQLAlchemy for safe IN clause query
            stmt = select(table).where(
                text("LOWER(TRIM(product_name))").in_(
                    [name.strip().lower() for name in product_names]
                )
            )

            result = sqlalchemy_conn.execute(stmt)

            # Build result dictionary
            existing_products = {}
            for row in result:
                row_dict = dict(row._mapping)
                product_name_clean = row_dict["product_name"].strip().lower()
                existing_products[product_name_clean] = row_dict

            return existing_products

    except Exception as e:
        logger.error(f"Failed to batch query existing products: {e}")
        return {}


def update_existing_product_batch(conn, original_row, merged_row, target_columns):
    """Update a single existing product with merged data."""
    try:
        # Find fields that have changed
        update_fields = []
        update_values = []

        for col in target_columns:
            if col == "code":  # Skip primary identifier
                continue

            db_col = col.replace("-", "_")
            original_value = original_row.get(db_col)
            merged_value = merged_row.get(db_col)

            # Apply numeric cleaning/rounding for numeric fields to match DB precision
            if (
                col.endswith("_100g")
                or col == "nutriscore_score"
                or col == "serving_quantity"
            ):
                merged_value = clean_numeric_value(merged_value, col)

            # Only update if value has actually changed
            if original_value != merged_value:
                if db_col == "allergens":
                    # Special handling for allergens - ensure it's properly formatted
                    if isinstance(merged_value, list):
                        update_fields.append(
                            f"{db_col} = %s::recipe_manager.allergen_enum[]"
                        )
                    else:
                        # Skip invalid allergen data
                        logger.warning(
                            (
                                "⚠️  Skipping invalid allergen data for product "
                                f"{original_row.get('nutritional_info_id')}: "
                                f"{merged_value}"
                            )
                        )
                        continue
                else:
                    update_fields.append(f"{db_col} = %s")
                update_values.append(merged_value)

        # Execute update if we have changes
        if update_fields:
            # Get SQLAlchemy table object
            table = get_nutritional_info_table()
            engine = get_sqlalchemy_engine()

            # Build update dictionary from changed fields
            update_dict = {}
            value_index = 0
            for field_expr in update_fields:
                if " = " in field_expr:
                    field_name = field_expr.split(" = ")[0]
                    if "::" in field_expr:
                        # Handle special cast syntax (like allergens)
                        field_name = field_name.strip()
                    update_dict[field_name] = update_values[value_index]
                    value_index += 1

            # Add updated_at timestamp
            update_dict["updated_at"] = text("now()")

            with engine.connect() as sqlalchemy_conn:
                stmt = (
                    update(table)
                    .where(
                        table.c.nutritional_info_id
                        == original_row["nutritional_info_id"]
                    )
                    .values(update_dict)
                )

                sqlalchemy_conn.execute(stmt)
                sqlalchemy_conn.commit()

    except Exception as e:
        # CHANGED: Report errors to console immediately
        error_msg = (
            f"❌ MERGE UPDATE FAILED: Product ID "
            f"{original_row.get('nutritional_info_id', 'unknown')}: {e}"
        )
        logger.error(error_msg)  # Changed from debug to error

        # Also add a counter to track these errors
        return False  # Indicate failure

    return True  # Indicate success
