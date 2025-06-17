#!/usr/bin/env python3
"""
OpenFoodFacts Nutritional Info Importer

This script imports ingredient data from an OpenFoodFacts CSV file
into the recipe database.
"""

import argparse
import sys
import logging
import os
from pathlib import Path
import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch
from psycopg2 import sql

# Add parent directory to path to find shared modules
sys.path.append(str(Path(__file__).parent.parent))

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def validate_csv_file(csv_path: str) -> Path:
    """Validate that the CSV file exists and is readable."""
    path = Path(csv_path)
    
    if not path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")
    
    if not path.is_file():
        raise ValueError(f"Path is not a file: {csv_path}")
    
    if path.suffix.lower() not in ['.csv', '.gz']:
        logger.warning(f"File doesn't have expected extension (.csv or .gz): {csv_path}")
    
    logger.info(f"✅ CSV file validated: {path.absolute()}")
    return path


def import_ingredients_from_csv(csv_path: Path) -> dict:
    """
    Import ingredients from OpenFoodFacts CSV into the database.
    
    Args:
        csv_path: Path to the OpenFoodFacts CSV file
        
    Returns:
        dict: Summary of import results
    """
    logger.info(f"🚀 Starting import from {csv_path}")
    
    # Initialize results
    results = {
        'file_path': str(csv_path),
        'file_size_mb': round(csv_path.stat().st_size / (1024 * 1024), 2),
        'rows_processed': 0,
        'rows_imported': 0,
        'rows_skipped': 0,
        'rows_skipped_no_nutrition': 0,
        'rows_skipped_duplicate_name': 0,
        'rows_skipped_non_american': 0,
        'rows_merged_duplicates': 0,
        'duplicate_codes': 0,
        'errors': []
    }
    
    # Track seen product names to avoid duplicates
    seen_product_names = set()
    
    # Batch duplicate processing for performance - use dict for easy merging
    duplicate_queue = {}  # product_name_clean -> queue_item
    
    conn = None
    
    try:
        # Get database connection
        conn = get_database_connection()
        
        # Get target columns for database
        target_columns = get_table_columns()
        
        # Read CSV file
        logger.info("📋 Reading CSV file...")
        
        # Read CSV in chunks to handle large files with error handling for malformed rows
        chunk_size = 10000
        csv_params = {
            'sep': '\t',
            'chunksize': chunk_size,
            'low_memory': False,
            'on_bad_lines': 'warn',  # Warn about bad lines but continue
            'encoding_errors': 'replace',  # Replace encoding errors
            'dtype': str,  # Read all columns as strings first to avoid type errors
        }
        
        if csv_path.suffix.lower() == '.gz':
            csv_params['compression'] = 'gzip'
        
        logger.info("CSV parsing parameters:")
        logger.info(f"  - Chunk size: {chunk_size}")
        logger.info( "  - Bad lines handling: warn and skip")
        logger.info( "  - Encoding errors: replace")
        
        try:
            df_reader = pd.read_csv(csv_path, **csv_params)
        except Exception as csv_error:
            logger.error(f"Failed to open CSV file: {csv_error}")
            raise
        
        # Analyze CSV structure before processing (read first chunk to get column info)
        logger.info("📋 Analyzing CSV structure...")
        first_chunk = next(iter(df_reader))
        csv_columns = set(first_chunk.columns)
        
        logger.info(f"CSV has {len(csv_columns)} columns")
        logger.info(f"Target table expects {len(target_columns)} columns")
        
        # Check which target columns are missing from CSV
        missing_cols = [col for col in target_columns if col not in csv_columns]
        if missing_cols:
            logger.warning(f"Missing CSV columns (will be set to NULL): {missing_cols}")
        
        # Show sample of available relevant columns
        available_targets = [col for col in target_columns if col in csv_columns]
        logger.info(f"Available target columns: {len(available_targets)}/{len(target_columns)}")
        
        # Re-create the reader since we consumed the first chunk
        df_reader = pd.read_csv(csv_path, **csv_params)
        
        # Get accurate chunk estimate by counting total lines
        logger.info("📊 Estimating total number of chunks...")
        chunk_size = 10000
        total_lines = -1 # TODO: IMPLEMENT AN EFFICIENT & ACCURATE WAY TO CALCULATE THIS
        estimated_chunks = 390  # TODO: IMPLEMENT AN EFFICIENT & ACCURATE WAY TO CALCULATE THIS
        logger.info(f"📊 File has ~{total_lines:,} lines, estimated {estimated_chunks} chunks of {chunk_size:,} rows each")
        
        # Process chunks with accurate progress tracking
        total_processed = 0
        
        for chunk_num, df_chunk in enumerate(df_reader, 1):
            # Progress message with accurate estimate
            logger.info(f"Processing chunk {chunk_num} of ~{estimated_chunks} ({len(df_chunk)} rows)...")
            
            # Prepare batch data
            batch_data = []
            rows_in_chunk = 0
            
            for _, row in df_chunk.iterrows():
                # Skip rows without a product code
                if pd.isna(row.get('code')) or not str(row.get('code')).strip():
                    results['rows_skipped'] += 1
                    continue
                
                # Skip rows without product name
                product_name = row.get('product_name')
                if pd.isna(product_name) or not str(product_name).strip():
                    results['rows_skipped'] += 1
                    continue
                
                # Handle duplicate product names by queuing for batch processing
                product_name_clean = str(product_name).strip().lower()
                if product_name_clean in seen_product_names:
                    # Check if already in queue
                    if product_name_clean in duplicate_queue:
                        # Merge with existing queue item
                        existing_item = duplicate_queue[product_name_clean]
                        merged_row = merge_queue_items(existing_item['row'], row, csv_columns, target_columns)
                        existing_item['row'] = merged_row
                    else:
                        # Add new item to queue
                        duplicate_queue[product_name_clean] = {
                            'product_name_clean': product_name_clean,
                            'row': row,
                            'csv_columns': csv_columns,
                            'target_columns': target_columns
                        }
                    results['rows_skipped_duplicate_name'] += 1
                    continue
                
                # Check if product has meaningful nutritional data
                has_nutrition = any([
                    not pd.isna(row.get('energy-kcal_100g')),
                    not pd.isna(row.get('proteins_100g')),
                    not pd.isna(row.get('carbohydrates_100g')),
                    not pd.isna(row.get('fat_100g'))
                ])
                
                if not has_nutrition:
                    results['rows_skipped_no_nutrition'] += 1
                    continue
                
                # Filter for American products only
                if not is_american_product(row):
                    results['rows_skipped_non_american'] += 1
                    continue
                
                # Add to seen product names
                seen_product_names.add(product_name_clean)
                
                # Prepare row data
                row_data = prepare_row_data(row, csv_columns, target_columns)
                batch_data.append(row_data)
                rows_in_chunk += 1
                
                # Process in smaller batches for memory efficiency
                if len(batch_data) >= 1000:
                    imported, duplicates, errors = insert_batch_data(conn, target_columns, batch_data)
                    results['rows_imported'] += imported
                    results['duplicate_codes'] += duplicates
                    results['errors'].extend(errors)
                    
                    results['rows_processed'] += len(batch_data)
                    total_processed += len(batch_data)
                    batch_data = []
            
            # Process remaining batch data
            if batch_data:
                imported, duplicates, errors = insert_batch_data(conn, target_columns, batch_data)
                results['rows_imported'] += imported
                results['duplicate_codes'] += duplicates
                results['errors'].extend(errors)
                
                results['rows_processed'] += len(batch_data)
                total_processed += len(batch_data)
            
            logger.info(f"Chunk {chunk_num} processed: {rows_in_chunk} valid rows")
            
            # Process queued duplicates every 10 chunks for better performance
            if chunk_num % 10 == 0 and duplicate_queue:
                process_duplicate_queue_batch(conn, duplicate_queue, results)
                duplicate_queue = {}  # Clear the queue after processing
            
            # Commit every 10 chunks to avoid losing too much progress
            if chunk_num % 10 == 0:
                conn.commit()
                logger.info(f"✅ Progress committed after chunk {chunk_num} ({results['rows_imported']} rows imported so far)")
        
        # Process any remaining queued duplicates
        if duplicate_queue:
            process_duplicate_queue_batch(conn, duplicate_queue, results)
        
        # Final commit
        if conn:
            conn.commit()
            logger.info("✅ Final transaction committed")
        
        logger.info(f"✅ Import completed: {results['rows_imported']} rows imported")
        
    except pd.errors.ParserError as e:
        # Handle CSV parsing errors specifically
        if conn:
            conn.commit()  # Commit what we have so far
            logger.info("✅ Committed partial progress before CSV error")
        
        error_msg = f"CSV parsing error: {e}"
        logger.error(error_msg)
        logger.error("This usually means there are malformed rows in the CSV file")
        logger.error("Consider using CSV repair tools or filtering the problematic rows")
        results['errors'].append(error_msg)
        
    except Exception as e:
        if conn:
            conn.rollback()
            logger.error("Transaction rolled back due to error")
        
        error_msg = f"Import failed: {e}"
        logger.error(error_msg)
        results['errors'].append(error_msg)
        raise
        
    finally:
        if conn:
            conn.close()
            logger.info("Database connection closed")
    
    return results


def insert_batch_data(conn, target_columns, batch_data):
    """Insert a batch of data into the database."""
    imported = 0
    duplicates = 0
    errors = []
    
    try:
        # Prepare SQL for batch insert
        # Use database column names (replace dashes with underscores for SQL)
        db_columns = [col.replace('-', '_') for col in target_columns]
        
        # Build INSERT statement with ON CONFLICT handling
        columns_sql = ', '.join(db_columns)
        
        # Create placeholders with special handling for allergens column
        placeholders = []
        for i, col in enumerate(db_columns):
            if col == 'allergens':
                # Cast text array to enum array for allergens
                placeholders.append('%s::recipe_manager.allergen_enum[]')
            else:
                placeholders.append('%s')
        
        placeholders_sql = ', '.join(placeholders)
        
        insert_sql = f"""
            INSERT INTO nutritional_info ({columns_sql})
            VALUES ({placeholders_sql})
            ON CONFLICT (code) DO UPDATE SET
                {', '.join([f'{col} = EXCLUDED.{col}' for col in db_columns[1:]])},  -- Skip 'code' column
                updated_at = now()
        """
        
        with conn.cursor() as cursor:
            # Execute batch insert
            execute_batch(cursor, insert_sql, batch_data, page_size=1000)
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
                db_col_name = col_name.replace('-', '_')
                
                if value is not None and isinstance(value, (int, float)):
                    # Check for values that might cause precision issues
                    if col_name in ['vitamin_a_100g', 'vitamin_b6_100g', 'vitamin_b12_100g', 
                                    'vitamin_c_100g', 'vitamin_d_100g', 'vitamin_e_100g', 'vitamin_k_100g',
                                    'calcium_100g', 'iron_100g', 'magnesium_100g', 'potassium_100g', 
                                    'sodium_100g', 'zinc_100g']:
                        if abs(value) >= 10000:
                            logger.error(f"     🚨 {db_col_name}: {value} (EXCEEDS DECIMAL(10,6) LIMIT)")
                            has_issues = True
                        elif abs(value) >= 1000:
                            logger.error(f"     ⚠️  {db_col_name}: {value} (HIGH VALUE)")
                        elif value != 0:
                            logger.error(f"     ✅ {db_col_name}: {value}")
                    elif col_name.endswith('_100g') or col_name == 'nutriscore_score':
                        if abs(value) >= 100000:
                            logger.error(f"     🚨 {db_col_name}: {value} (EXCEEDS DECIMAL(8,3) LIMIT)")
                            has_issues = True
                        elif abs(value) >= 10000:
                            logger.error(f"     ⚠️  {db_col_name}: {value} (HIGH VALUE)")
                        elif value != 0:
                            logger.error(f"     ✅ {db_col_name}: {value}")
                elif value is not None and col_idx < 10:  # Show first 10 non-numeric values
                    logger.error(f"     📝 {db_col_name}: '{value}'")
            
            if has_issues:
                problematic_rows.append(row_idx)
        
        if len(batch_data) > 5:
            logger.error(f"   ... and {len(batch_data) - 5} more rows not shown")
        
        # Try to recover by inserting rows individually
        logger.error("🔄 Attempting individual row inserts to salvage good data...")
        
        # Rollback the failed batch transaction
        conn.rollback()
        
        # Try inserting each row individually
        success_count = 0
        fail_count = 0
        
        with conn.cursor() as cursor:
            for row_idx, row_data in enumerate(batch_data):
                try:
                    cursor.execute(insert_sql, row_data)
                    success_count += 1
                except Exception as row_error:
                    fail_count += 1
                    if fail_count <= 5:  # Log first 5 individual failures
                        product_code = row_data[0] if row_data else 'unknown'
                        logger.error(f"     Row {row_idx + 1} (code: {product_code}) failed: {row_error}")
        
        imported = success_count
        logger.error(f"🔄 Individual insert results: {success_count} succeeded, {fail_count} failed")
        
        if fail_count > 0:
            errors.append(f"Batch failed, individual recovery: {success_count}/{len(batch_data)} rows saved")
        
        # Update the main error message
        errors.append(error_msg)
    
    return imported, duplicates, errors


def print_results(results: dict):
    """Print a nice summary of the import results."""
    print(f"\n{'='*50}")
    print("📊 IMPORT RESULTS")
    print(f"{'='*50}")
    print(f"File: {results['file_path']}")
    print(f"File size: {results['file_size_mb']} MB")
    print(f"Rows processed: {results['rows_processed']:,}")
    print(f"Rows imported (new): {results['rows_imported']:,}")
    print(f"Rows merged (duplicates): {results['rows_merged_duplicates']:,}")
    print(f"Total products in database: {results['rows_imported'] + results['rows_merged_duplicates']:,}")
    print("")
    print("📋 FILTERING RESULTS:")
    print(f"Rows skipped (general): {results['rows_skipped']:,}")
    print(f"Rows skipped (duplicate names): {results['rows_skipped_duplicate_name']:,}")
    print(f"Rows skipped (no nutrition data): {results['rows_skipped_no_nutrition']:,}")
    print(f"Rows skipped (non-American): {results['rows_skipped_non_american']:,}")
    print(f"Duplicate codes: {results['duplicate_codes']:,}")
    
    # Calculate filtering efficiency  
    total_rows = results['rows_processed'] + results['rows_skipped'] + results['rows_skipped_duplicate_name'] + results['rows_skipped_no_nutrition'] + results['rows_skipped_non_american']
    if total_rows > 0:
        total_products = results['rows_imported'] + results['rows_merged_duplicates']
        import_rate = (total_products / total_rows) * 100
        print("")
        print("📈 EFFICIENCY:")
        print(f"Total rows examined: {total_rows:,}")
        print(f"Import rate: {import_rate:.1f}%")
    
    if results['errors']:
        print("")
        print(f"❌ Errors: {len(results['errors'])}")
        for error in results['errors'][:5]:  # Show first 5 errors
            print(f"  - {error}")
        if len(results['errors']) > 5:
            print(f"  ... and {len(results['errors']) - 5} more errors")
    else:
        print("✅ No errors")
    print(f"{'='*50}\n")


def get_database_connection():
    """Get a database connection using environment variables."""
    try:
        # Get database configuration from environment
        db_config = {
            'host': os.getenv('POSTGRES_HOST', 'localhost'),
            'database': os.getenv('POSTGRES_DB', 'recipe_manager'),
            'user': os.getenv('DB_MAINT_USER', 'db_maint_user'),
            'password': os.getenv('DB_MAINT_PASSWORD', ''),
            'port': os.getenv('POSTGRES_PORT', '5432')
        }
        
        logger.info(f"Connecting to database: {db_config['user']}@{db_config['host']}:{db_config['port']}/{db_config['database']}")
        
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
        'code',
        'product_name',
        'generic_name',
        'brands',
        'categories',
        
        # Classification data
        'allergens',
        'food_groups',
        'nutriscore_score',
        'nutriscore_grade',
        
        # Macro-nutrients
        'energy-kcal_100g',  # CSV name with dash
        'carbohydrates_100g',
        'cholesterol_100g', 
        'proteins_100g',
        
        # Sugars
        'sugars_100g',
        'added-sugars_100g',  # CSV name with dash
        
        # Fats
        'fat_100g',
        'saturated-fat_100g',  # CSV name with dash
        'monounsaturated-fat_100g',  # CSV name with dash
        'polyunsaturated-fat_100g',  # CSV name with dash
        'omega-3-fat_100g',  # CSV name with dash
        'omega-6-fat_100g',  # CSV name with dash
        'omega-9-fat_100g',  # CSV name with dash
        'trans-fat_100g',  # CSV name with dash
        
        # Fibers
        'fiber_100g',
        'soluble-fiber_100g',  # CSV name with dash
        'insoluble-fiber_100g',  # CSV name with dash
        
        # Vitamins
        'vitamin-a_100g',  # CSV name with dash
        'vitamin-b6_100g',  # CSV name with dash
        'vitamin-b12_100g',  # CSV name with dash
        'vitamin-c_100g',  # CSV name with dash
        'vitamin-d_100g',  # CSV name with dash
        'vitamin-e_100g',  # CSV name with dash
        'vitamin-k_100g',  # CSV name with dash
        
        # Minerals
        'calcium_100g',
        'iron_100g',
        'magnesium_100g',
        'potassium_100g',
        'sodium_100g',
        'zinc_100g'
    ]


def clean_numeric_value(value, column_name=None):
    """Clean and convert a value to a numeric type, handling various formats and database precision limits."""
    if pd.isna(value) or value == '' or value is None:
        return None
    
    try:
        # Convert to string and strip whitespace
        str_val = str(value).strip()
        
        # Handle empty strings
        if not str_val or str_val.lower() == 'nan':
            return None
            
        # Try to convert to float
        numeric_val = float(str_val)
        
        # Handle infinite or NaN values
        if not (numeric_val == numeric_val and abs(numeric_val) != float('inf')):
            return None
        
        # Apply database precision limits based on column type
        if column_name:
            # Vitamins and minerals: DECIMAL(10,6) - max value 9999.999999
            vitamin_mineral_columns = [
                'vitamin-a_100g', 'vitamin-b6_100g', 'vitamin-b12_100g', 
                'vitamin-c_100g', 'vitamin-d_100g', 'vitamin-e_100g', 'vitamin-k_100g',
                'calcium_100g', 'iron_100g', 'magnesium_100g', 'potassium_100g', 
                'sodium_100g', 'zinc_100g'
            ]
            
            if column_name in vitamin_mineral_columns:
                if abs(numeric_val) >= 10000:  # Precision limit for DECIMAL(10,6)
                    logger.debug(f"Value {numeric_val} for {column_name} exceeds DECIMAL(10,6) limit, setting to NULL")
                    return None
                    
            # Macro-nutrients: DECIMAL(8,3) - max value 99999.999  
            elif column_name.endswith('_100g') or column_name == 'nutriscore_score':
                if abs(numeric_val) >= 100000:  # Precision limit for DECIMAL(8,3)
                    logger.debug(f"Value {numeric_val} for {column_name} exceeds DECIMAL(8,3) limit, setting to NULL")
                    return None
        
        # General sanity check for extremely large values
        if abs(numeric_val) >= 1e6:  # 1 million - likely data error
            return None
            
        return numeric_val
        
    except (ValueError, TypeError):
        return None


def clean_nutriscore_grade(value):
    """Clean and validate nutriscore_grade values."""
    if pd.isna(value) or value == '' or value is None:
        return None
    
    try:
        # Convert to string and clean
        str_val = str(value).strip().lower()
        
        # Handle empty strings
        if not str_val or str_val.lower() == 'nan':
            return None
        
        # Valid nutriscore grades are a, b, c, d, e
        if str_val in ['a', 'b', 'c', 'd', 'e']:
            return str_val
        
        # Handle some common variations/errors
        if str_val.startswith('a'):
            return 'a'
        elif str_val.startswith('b'):
            return 'b'
        elif str_val.startswith('c'):
            return 'c'
        elif str_val.startswith('d'):
            return 'd'
        elif str_val.startswith('e'):
            return 'e'
        
        # If we can't parse it, log and return None
        logger.debug(f"Invalid nutriscore_grade value: '{value}', setting to NULL")
        return None
        
    except (ValueError, TypeError):
        return None


def prepare_row_data(row, csv_columns, target_columns):
    """Prepare a single row of data for database insertion."""
    row_data = []
    
    # Define which columns are numeric and need cleaning
    numeric_columns = [
        'nutriscore_score',
        'energy-kcal_100g', 'carbohydrates_100g', 'cholesterol_100g', 'proteins_100g',
        'sugars_100g', 'added-sugars_100g', 'fat_100g', 'saturated-fat_100g',
        'monounsaturated-fat_100g', 'polyunsaturated-fat_100g', 'omega-3-fat_100g',
        'omega-6-fat_100g', 'omega-9-fat_100g', 'trans-fat_100g', 'fiber_100g', 'soluble-fiber_100g',
        'insoluble-fiber_100g', 'vitamin-a_100g', 'vitamin-b6_100g', 'vitamin-b12_100g',
        'vitamin-c_100g', 'vitamin-d_100g', 'vitamin-e_100g', 'vitamin-k_100g',
        'calcium_100g', 'iron_100g', 'magnesium_100g', 'potassium_100g', 'sodium_100g', 'zinc_100g'
    ]
    
    for col in target_columns:
        if col in csv_columns:
            value = row[col]
            
            # Handle allergens column specially - convert to enum array
            if col == 'allergens':
                allergen_enums = map_allergens_to_enum(value)
                # Convert to PostgreSQL array format
                if allergen_enums:
                    value = allergen_enums
                else:
                    value = None
            # Handle numeric columns with precision limits
            elif col in numeric_columns:
                value = clean_numeric_value(value, col)
            # Handle nutriscore_grade specifically
            elif col == 'nutriscore_grade':
                value = clean_nutriscore_grade(value)
            # Handle text columns
            elif value is not None and not pd.isna(value):
                value = str(value).strip()
                if not value:  # Empty string
                    value = None
            else:
                value = None
                
            row_data.append(value)
        else:
            # Column not in CSV, set to None
            row_data.append(None)
    
    return row_data


def is_american_product(row):
    """Check if a product is from the United States."""
    try:
        # Check the countries field
        countries = row.get('countries', '')
        countries_tags = row.get('countries_tags', '')
        countries_en = row.get('countries_en', '')
        
        # List of potential American identifiers
        american_identifiers = [
            'united states', 'usa', 'us', 'united-states',
            'en:united-states', 'en:usa', 'en:us'
        ]
        
        # Check all country fields
        for field in [countries, countries_tags, countries_en]:
            if pd.isna(field):
                continue
            
            field_str = str(field).lower()
            
            # Check if any American identifier is in the field
            for identifier in american_identifiers:
                if identifier in field_str:
                    return True
        
        # If no American identifiers found, not an American product
        return False
        
    except Exception as e:
        # If there's an error, default to not American to be safe
        logger.debug(f"Error checking if product is American: {e}")
        return False


def merge_duplicate_with_database(conn, new_row, csv_columns, target_columns, results):
    """Query existing product from database and update with merged data."""
    try:
        product_name_clean = str(new_row.get('product_name')).strip().lower()
        
        # Create a savepoint for this operation
        with conn.cursor() as cursor:
            cursor.execute("SAVEPOINT merge_duplicate")
            
        # Query existing product from database
        with conn.cursor() as cursor:
            # Find existing product by product name (case-insensitive)
            cursor.execute("""
                SELECT * FROM nutritional_info 
                WHERE LOWER(TRIM(product_name)) = %s 
                LIMIT 1
            """, (product_name_clean,))
            
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
                if col == 'code':  # Skip primary identifier
                    continue
                    
                db_col = col.replace('-', '_')  # Convert CSV names to DB names
                new_value = new_row.get(col)
                existing_value = existing_dict.get(db_col)
                
                # Clean and validate the new value
                if col in ['nutriscore_score'] or col.endswith('_100g'):
                    new_value = clean_numeric_value(new_value, col)
                elif col == 'nutriscore_grade':
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
                update_values.append(existing_dict['nutritional_info_id'])  # WHERE clause
                update_sql = f"""
                    UPDATE nutritional_info 
                    SET {', '.join(update_fields)}, updated_at = now()
                    WHERE nutritional_info_id = %s
                """
                cursor.execute(update_sql, update_values)
                
                if cursor.rowcount > 0:
                    results['rows_imported'] += 1  # Count as successful merge
            
            # Release the savepoint
            cursor.execute("RELEASE SAVEPOINT merge_duplicate")
                
    except Exception as e:
        # Rollback to savepoint on error
        try:
            with conn.cursor() as cursor:
                cursor.execute("ROLLBACK TO SAVEPOINT merge_duplicate")
        except Exception:
            pass  # Ignore rollback errors
            
        error_msg = f"Failed to merge duplicate product '{new_row.get('product_name', 'Unknown')}': {e}"
        logger.debug(error_msg)  # Reduce log level to debug
        # Don't add to results['errors'] to avoid spam


def should_update_field(existing_value, new_value, column_name):
    """Determine if a field should be updated based on merge logic."""
    # Don't update if new value is null/empty
    if new_value is None or new_value == '':
        return False
    
    # Always update if existing is null/empty
    if existing_value is None or existing_value == '':
        return True
    
    # For numeric nutrition fields, prefer non-zero values
    if column_name.endswith('_100g') or column_name == 'nutriscore_score':
        try:
            existing_num = float(existing_value) if existing_value is not None else 0
            new_num = float(new_value) if new_value is not None else 0
            
            # Update if existing is 0 and new is non-zero
            if existing_num == 0 and new_num > 0:
                return True
            
            # Don't update if we already have a good value
            return False
            
        except (ValueError, TypeError):
            return False
    
    # For text fields, prefer longer/more detailed content
    if column_name in ['brands', 'categories', 'allergens']:
        return len(str(new_value)) > len(str(existing_value))
    
    # Default: don't update (preserve first occurrence)
    return False


def merge_database_row(existing_dict, new_row, target_columns):
    """Merge new row data with existing database row."""
    merged_data = []
    
    for col in target_columns:
        db_col = col.replace('-', '_')  # Convert CSV names to DB names
        existing_value = existing_dict.get(db_col)
        new_value = new_row.get(col)
        
        # Use merging logic to determine best value
        if should_update_field(existing_value, new_value, col):
            merged_data.append(new_value)
        else:
            merged_data.append(existing_value)
    
    return merged_data


def insert_single_row(conn, target_columns, row_data, results):
    """Insert a single row (fallback for when database lookup fails)."""
    try:
        with conn.cursor() as cursor:
            # Build insert SQL
            db_columns = [col.replace('-', '_') for col in target_columns]
            placeholders = ', '.join(['%s'] * len(target_columns))
            insert_sql = f"""
                INSERT INTO nutritional_info ({', '.join(db_columns)}) 
                VALUES ({placeholders})
                ON CONFLICT (code) DO UPDATE SET
                {', '.join([f'{col} = EXCLUDED.{col}' for col in db_columns[1:]])},
                updated_at = now()
            """
            
            cursor.execute(insert_sql, row_data)
            if cursor.rowcount > 0:
                results['rows_imported'] += 1
                
    except Exception as e:
        error_msg = f"Failed to insert single row: {e}"
        logger.error(error_msg)
        results['errors'].append(error_msg)
    

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
                merged_db_row = convert_raw_row_to_db_format(existing_product, queue_item['row'], queue_item['target_columns'])
                success = update_existing_product_batch(conn, existing_product, merged_db_row, queue_item['target_columns'])
                
                if success:
                    processed_count += 1
                    results['rows_merged_duplicates'] += 1
                else:
                    failed_count += 1
                    # Stop processing if we have too many failures
                    if failed_count >= 5:
                        logger.error(f"🚨 STOPPING: Too many merge failures ({failed_count} failures)")
                        logger.error("💡 This indicates a systematic issue with the duplicate merging logic")
                        logger.error("🔧 Please fix the merge logic before continuing")
                        raise Exception(f"Duplicate merge failures exceed threshold ({failed_count} failures)")
        
        if failed_count > 0:
            logger.warning(f"⚠️  Batch completed with {failed_count} merge failures out of {len(duplicate_queue)} attempts")
        
        logger.info(f"✅ Batch processed {processed_count} unique duplicate products")
        
    except Exception as e:
        error_msg = f"❌ DUPLICATE BATCH PROCESSING FAILED: {e}"
        logger.error(error_msg)
        results['errors'].append(f"Batch duplicate processing failed: {e}")
        # Re-raise to stop the import
        raise
    


def batch_query_existing_products(conn, product_names):
    """Query multiple existing products in a single database call."""
    if not product_names:
        return {}
    
    try:
        with conn.cursor() as cursor:
            # Use IN clause for batch query
            placeholders = ','.join(['%s'] * len(product_names))
            cursor.execute(f"""
                SELECT * FROM nutritional_info 
                WHERE LOWER(TRIM(product_name)) IN ({placeholders})
            """, product_names)
            
            # Get column names
            db_columns = [desc[0] for desc in cursor.description]
            
            # Build result dictionary
            existing_products = {}
            for row in cursor.fetchall():
                row_dict = dict(zip(db_columns, row))
                product_name_clean = row_dict['product_name'].strip().lower()
                existing_products[product_name_clean] = row_dict
            
            return existing_products
            
    except Exception as e:
        logger.error(f"Failed to batch query existing products: {e}")
        return {}


def merge_single_duplicate(existing_row, new_row, target_columns):
    """Merge new row data with existing database row."""
    merged_row = existing_row.copy()
    
    for col in target_columns:
        if col == 'code':  # Skip primary identifier
            continue
            
        db_col = col.replace('-', '_')
        existing_value = existing_row.get(db_col)
        new_value = new_row.get(col)
        
        # Special handling for allergens
        if col == 'allergens':
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
        if col in ['nutriscore_score'] or col.endswith('_100g'):
            new_value = clean_numeric_value(new_value, col)
        elif col == 'nutriscore_grade':
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


def update_existing_product_batch(conn, original_row, merged_row, target_columns):
    """Update a single existing product with merged data."""
    try:
        # Find fields that have changed
        update_fields = []
        update_values = []
        
        for col in target_columns:
            if col == 'code':  # Skip primary identifier
                continue
                
            db_col = col.replace('-', '_')
            original_value = original_row.get(db_col)
            merged_value = merged_row.get(db_col)
        
            # Only update if value has actually changed
            if original_value != merged_value:
                if db_col == 'allergens':
                    # Special handling for allergens - ensure it's properly formatted
                    if isinstance(merged_value, list):
                        update_fields.append(f"{db_col} = %s::recipe_manager.allergen_enum[]")
                    else:
                        # Skip invalid allergen data
                        logger.warning(f"⚠️  Skipping invalid allergen data for product {original_row.get('nutritional_info_id')}: {merged_value}")
                        continue
                else:
                    update_fields.append(f"{db_col} = %s")
                update_values.append(merged_value)
        
        # Execute update if we have changes
        if update_fields:
            update_values.append(original_row['nutritional_info_id'])
            
            with conn.cursor() as cursor:
                update_sql = f"""
                    UPDATE nutritional_info 
                    SET {', '.join(update_fields)}, updated_at = now()
                    WHERE nutritional_info_id = %s
                """
                cursor.execute(update_sql, update_values)
                
    except Exception as e:
        # CHANGED: Report errors to console immediately
        error_msg = f"❌ MERGE UPDATE FAILED: Product ID {original_row.get('nutritional_info_id', 'unknown')}: {e}"
        logger.error(error_msg)  # Changed from debug to error
        
        # Also add a counter to track these errors
        return False  # Indicate failure
    
    return True  # Indicate success


def convert_raw_row_to_db_format(existing_product, raw_row, target_columns):
    """Convert raw CSV row to database format for comparison."""
    db_row = existing_product.copy()
    
    for col in target_columns:
        if col == 'code':  # Skip primary identifier
            continue
            
        db_col = col.replace('-', '_')  # Convert CSV names to DB names
        raw_value = raw_row.get(col)
        existing_value = existing_product.get(db_col)
        
        # Special handling for allergens - APPLY MAPPING
        if col == 'allergens':
            if raw_value and not pd.isna(raw_value):
                clean_value = map_allergens_to_enum(raw_value)
            else:
                clean_value = None
        # Clean and validate other values
        elif col in ['nutriscore_score'] or col.endswith('_100g'):
            clean_value = clean_numeric_value(raw_value, col)
        elif col == 'nutriscore_grade':
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
        if (pd.isna(existing_value) or existing_value is None or existing_value == '') and \
           not (pd.isna(new_value) or new_value is None or new_value == ''):
            merged_row[col] = new_value
        
        # For numeric nutrition fields, prefer non-zero values
        elif col in ['energy-kcal_100g', 'proteins_100g', 'carbohydrates_100g', 'fat_100g'] and \
             col in target_columns:
            try:
                existing_num = float(existing_value) if not pd.isna(existing_value) else 0
                new_num = float(new_value) if not pd.isna(new_value) else 0
                
                # If existing is 0 but new has a value, use new
                if existing_num == 0 and new_num > 0:
                    merged_row[col] = new_value
                # Otherwise keep existing (first occurrence preference)
            except (ValueError, TypeError):
                pass  # Keep existing value
        
        # Special handling for allergens (now arrays)
        elif col == 'allergens':
            existing_allergens = map_allergens_to_enum(existing_value) if existing_value else []
            new_allergens = map_allergens_to_enum(new_value) if new_value else []
            
            # Combine allergen arrays, removing duplicates
            combined_allergens = list(set(existing_allergens + new_allergens))
            if combined_allergens:
                # Store the combined raw string for now (will be processed later)
                merged_row[col] = ', '.join([f"en:{allergen.lower()}" for allergen in combined_allergens])
        
        # For text fields, prefer longer/more detailed content
        elif col in ['brands', 'categories']:
            if len(str(new_value)) > len(str(existing_value)):
                merged_row[col] = new_value
    
    return merged_row


def map_allergens_to_enum(allergen_string):
    """Map raw allergen string from CSV to standardized enum values."""
    if pd.isna(allergen_string) or not allergen_string or allergen_string.strip() == '':
        return []
    
    # Define comprehensive mapping from CSV values to enum values
    allergen_mapping = {
        # Milk and dairy (various languages and formats)
        'MILK': [
            'milk', 'milch', 'lait', 'leite', 'mleko', 'latte', 'mléko', 'mjölk',
            'kuhmilch', 'cow milk', "cow's milk", 'dairy', 'dairy products',
            'milk products', 'milk derivatives', 'milkfat', 'butter', 'butterfat',
            'cream', 'cheese', 'whey', 'casein', 'lactose', 'yogurt', 'yoghurt',
            'cheddar', 'mozzarella', 'emmental', 'milk protein', 'milk solids',
            'cultured milk', 'pasteurized milk', 'nonfat milk', 'whole milk',
            'milchprodukte', 'milchbestandteile', 'milcheiweiß', 'milcheiweiss'
        ],
        
        # Eggs (various languages)
        'EGGS': [
            'eggs', 'egg', 'eier', 'ovo', 'uova', 'jajka', 'eieren', 'œuf',
            'hühnerei', 'egg white', 'egg powder', 'eigelb', 'albumin'
        ],
        
        # Wheat and gluten
        'WHEAT': [
            'wheat', 'weizen', 'blé', 'trigo', 'wheat flour', 'wheat gluten',
            'weizenmehl', 'wheat starch', 'wheat derivatives', 'durum wheat',
            'wheat protein', 'weizenprotein', 'hartweizengrieß'
        ],
        
        'GLUTEN': [
            'gluten', 'glutenhaltiges getreide', 'cereals containing gluten',
            'céréales contenant du gluten', 'gluten-containing cereals'
        ],
        
        # Soybeans
        'SOYBEANS': [
            'soy', 'soja', 'soya', 'soybeans', 'sojabohnen', 'soybean',
            'soy protein', 'soy lecithin', 'sojaprotein', 'sojaöl'
        ],
        
        # Tree nuts (general and specific)
        'TREE_NUTS': [
            'tree nuts', 'nuts', 'nüsse', 'noix', 'fruits à coque',
            'frutta a guscio', 'tree nut', 'nut allergy'
        ],
        
        'ALMONDS': [
            'almonds', 'almond', 'mandeln', 'amandes', 'mandorle', 'almendras',
            'almond butter', 'almond flour', 'almond milk'
        ],
        
        'CASHEWS': [
            'cashews', 'cashew', 'cashew nuts', 'cashew-nüsse', 'cashewkeme'
        ],
        
        'HAZELNUTS': [
            'hazelnuts', 'hazelnut', 'haselnüsse', 'haselnuss', 'hazlenut'
        ],
        
        'WALNUTS': [
            'walnuts', 'walnut', 'walnüsse', 'wallnuts', 'black walnuts'
        ],
        
        # Peanuts
        'PEANUTS': [
            'peanuts', 'peanut', 'erdnüsse', 'arachides', 'pinda',
            'peanut butter', 'peanut oil', 'groundnuts'
        ],
        
        # Fish and seafood
        'FISH': [
            'fish', 'fisch', 'poisson', 'pescado', 'pesce', 'vis',
            'anchovy', 'anchovies', 'sardines', 'tuna', 'salmon',
            'hoki', 'pollock', 'bonito', 'herring', 'flying fish'
        ],
        
        'SHELLFISH': [
            'shellfish', 'crustacean', 'shrimp', 'prawns', 'crab',
            'lobster', 'crayfish', 'garnelen', 'molluscs', 'mollusks',
            'oyster', 'mussel', 'clam', 'scallop'
        ],
        
        # Sesame
        'SESAME': [
            'sesame', 'sesame seeds', 'sésame', 'sesamsaat',
            'graines de sésame', 'white sesame seeds'
        ],
        
        # Mustard
        'MUSTARD': [
            'mustard', 'senf', 'moutarde', 'mustard seed', 'mustard seeds',
            'gelbsenfsaat', 'braunsenfsaat'
        ],
        
        # Celery
        'CELERY': [
            'celery', 'sellerie', 'céleri', 'celery powder',
            'schnittselerie', 'schnittsellerie'
        ],
        
        # Sulphites
        'SULPHITES': [
            'sulphites', 'sulfites', 'sulfit', 'sulfur dioxide',
            'metabisulphite', 'sodium metabisulphite', 'kaliummetabisulfit',
            'ammoniumsulfit', 'natriummetabisulfit'
        ],
        
        # Coconut
        'COCONUT': [
            'coconut', 'coconuts', 'noix de coco', 'coconut oil'
        ],
        
        # Alcohol
        'ALCOHOL': [
            'alcohol', 'alkohol', 'ethanol'
        ],
        
        # Phenylalanine
        'PHENYLALANINE': [
            'phenylalanine', 'phenylalalnine', 'phenilananin',
            'phenylalaninquelle'
        ],
        
        'LUPIN': [
            'lupin', 'lupine', 'lupins'
        ],
        
        'CORN': [
            'corn', 'maize', 'mais', 'corn starch', 'corn flour',
            'yellow corn', 'sweet corn'
        ],
        
        'YEAST': [
            'yeast', 'hefe', 'levure', 'baker yeast', 'nutritional yeast'
        ],
        
        'GELATIN': [
            'gelatin', 'gelatine', 'beef gelatin', 'pork gelatin'
        ],
        
        'KIWI': [
            'kiwi', 'kiwi fruit'
        ],
        
        # Religious/Dietary
        'PORK': [
            'pork', 'schwein', 'porc', 'pig', 'ham', 'bacon',
            'pork gelatin', 'lard'
        ],
        
        'BEEF': [
            'beef', 'rind', 'bœuf', 'cow', 'cattle', 'beef gelatin'
        ],
        
        # Additives/Chemicals
        'SULFUR_DIOXIDE': [
            'sulfur dioxide', 'sulphur dioxide', 'so2', 'e220'
        ]
    }
    
    # Split allergen string by common delimiters
    allergen_parts = []
    for delimiter in [',', ';', '|', '/', '+', '&', ' and ', ' et ', ' und ']:
        if delimiter in allergen_string:
            allergen_parts = allergen_string.split(delimiter)
            break
    
    if not allergen_parts:
        allergen_parts = [allergen_string]
    
    # Clean and normalize each part
    found_allergens = set()
    
    for part in allergen_parts:
        # Clean the part
        clean_part = part.strip().lower()
        
        # Remove common prefixes
        for prefix in ['en:', 'de:', 'fr:', 'es:', 'it:', 'contains:', 'contains ', 'enthält']:
            if clean_part.startswith(prefix):
                clean_part = clean_part[len(prefix):].strip()
        
        # Skip empty or very short parts
        if len(clean_part) < 3:
            continue
            
        # Skip obvious non-allergens
        skip_terms = [
            'none', 'nil', 'n/a', 'no known allergens', 'keine',
            'warning', 'may contain', 'traces', 'produced in',
            'manufactured on', 'water', 'salt', 'sugar'
        ]
        if any(skip in clean_part for skip in skip_terms):
            continue
        
        # Find matching allergens
        for enum_value, patterns in allergen_mapping.items():
            for pattern in patterns:
                if pattern.lower() in clean_part or clean_part in pattern.lower():
                    found_allergens.add(enum_value)
                    break
    
    return list(found_allergens)


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Import ingredients from OpenFoodFacts CSV into recipe database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s /data/openfoodfacts.csv
  %(prog)s /data/en.openfoodfacts.org.products.csv.gz
        """
    )
    
    parser.add_argument(
        'csv_path',
        help='Path to the OpenFoodFacts CSV file (can be .csv or .csv.gz)'
    )
    
    args = parser.parse_args()
    
    try:
        # Validate input file
        csv_path = validate_csv_file(args.csv_path)
        
        # Log configuration
        logger.info("🔧 Configuration:")
        logger.info(f"  CSV file: {csv_path}")
        
        # Run the import
        results = import_ingredients_from_csv(csv_path)
        
        # Print results
        print_results(results)
        
        # Exit with appropriate code
        if results['errors']:
            logger.warning("Import completed with errors")
            sys.exit(1)
        else:
            logger.info("Import completed successfully")
            sys.exit(0)
            
    except KeyboardInterrupt:
        logger.info("Import interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Import failed: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()

