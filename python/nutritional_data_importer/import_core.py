"""
Core import logic for OpenFoodFacts data.
"""

import logging
import pandas as pd
from pathlib import Path
from database import get_database_connection, get_table_columns, insert_batch_data
from data_processing import prepare_row_data, is_american_product
from duplicate_handling import merge_queue_items, process_duplicate_queue_batch

logger = logging.getLogger(__name__)

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