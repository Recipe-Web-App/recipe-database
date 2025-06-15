#!/usr/bin/env python3
"""
OpenFoodFacts Nutritional Info Importer

This script imports ingredient data from an OpenFoodFacts CSV file
into the recipe database.
"""

import argparse
import sys
import logging
from pathlib import Path
import pandas as pd
import gzip

# Add parent directory to path to find shared modules
sys.path.append(str(Path(__file__).parent.parent))

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
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
        'ingredients_found': 0,
        'ingredients_inserted': 0,
        'errors': []
    }
    
    try:
        # Read CSV headers and first few rows
        logger.info("📋 Reading CSV file to analyze structure...")
        
        # Handle both regular CSV and gzipped CSV
        if csv_path.suffix.lower() == '.gz':
            # For gzipped files, read with pandas
            logger.info("Reading gzipped CSV file...")
            df_sample = pd.read_csv(csv_path, compression='gzip', nrows=5, sep='\t')
        else:
            # For regular CSV files
            logger.info("Reading CSV file...")
            df_sample = pd.read_csv(csv_path, nrows=5, sep='\t')
        
        # Print CSV structure information
        print("\n" + "="*80)
        print("📊 CSV FILE STRUCTURE ANALYSIS")
        print("="*80)
        print(f"File: {csv_path}")
        print(f"File size: {results['file_size_mb']} MB")
        print(f"Number of columns: {len(df_sample.columns)}")
        print(f"Sample rows read: {len(df_sample)}")
        
        print("\n📋 COLUMN HEADERS:")
        print("-" * 80)
        for i, col in enumerate(df_sample.columns, 1):
            print(f"{i:3d}. {col}")
        
        print("\n🔍 FIRST FEW ROWS (showing first 10 columns):")
        print("-" * 80)
        # Show first 10 columns to avoid overwhelming output
        sample_cols = df_sample.columns[:10]
        print(df_sample[sample_cols].to_string(index=False))
        
        if len(df_sample.columns) > 10:
            print(f"\n... and {len(df_sample.columns) - 10} more columns")
        
        print("\n📈 COLUMN DATA TYPES (first 20):")
        print("-" * 80)
        for i, (col, dtype) in enumerate(df_sample.dtypes.head(20).items(), 1):
            print(f"{i:3d}. {col:<40} {dtype}")
        
        if len(df_sample.dtypes) > 20:
            print(f"... and {len(df_sample.dtypes) - 20} more columns")
        
        print("="*80)
        
        # Update results with what we found
        results['rows_processed'] = len(df_sample)
        results['total_columns'] = len(df_sample.columns)
        
        # TODO: Add actual database import logic here
        logger.info("🔄 Database import not yet implemented - currently just analyzing CSV structure")
        
    except Exception as e:
        error_msg = f"Failed to read CSV file: {e}"
        logger.error(error_msg)
        results['errors'].append(error_msg)
        raise
    
    logger.info("📊 Import analysis completed")
    return results


def print_results(results: dict):
    """Print a nice summary of the import results."""
    print(f"\n{'='*50}")
    print("📊 IMPORT RESULTS")
    print(f"{'='*50}")
    print(f"File: {results['file_path']}")
    print(f"File size: {results['file_size_mb']} MB")
    print(f"Rows processed: {results['rows_processed']:,}")
    print(f"Ingredients found: {results['ingredients_found']:,}")
    print(f"Ingredients inserted: {results['ingredients_inserted']:,}")
    
    if results['errors']:
        print(f"❌ Errors: {len(results['errors'])}")
        for error in results['errors'][:5]:  # Show first 5 errors
            print(f"  - {error}")
        if len(results['errors']) > 5:
            print(f"  ... and {len(results['errors']) - 5} more errors")
    else:
        print("✅ No errors")
    print(f"{'='*50}\n")


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Import ingredients from OpenFoodFacts CSV into recipe database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s /data/openfoodfacts.csv
  %(prog)s /data/en.openfoodfacts.org.products.csv.gz
  %(prog)s --dry-run /data/openfoodfacts.csv
        """
    )
    
    parser.add_argument(
        'csv_path',
        help='Path to the OpenFoodFacts CSV file (can be .csv or .csv.gz)'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Run without making database changes (for testing)'
    )
    
    parser.add_argument(
        '--max-rows',
        type=int,
        help='Maximum number of rows to process (for testing)'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose logging'
    )
    
    args = parser.parse_args()
    
    # Set log level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        # Validate input file
        csv_path = validate_csv_file(args.csv_path)
        
        # Log configuration
        logger.info("🔧 Configuration:")
        logger.info(f"  CSV file: {csv_path}")
        logger.info(f"  Dry run: {args.dry_run}")
        logger.info(f"  Max rows: {args.max_rows or 'unlimited'}")
        logger.info(f"  Verbose: {args.verbose}")
        
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
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()


