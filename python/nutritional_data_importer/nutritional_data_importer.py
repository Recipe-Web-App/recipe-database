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

# Add parent directory to path to find shared modules
sys.path.append(str(Path(__file__).parent.parent))

from csv_validation import validate_csv_file
from import_core import import_ingredients_from_csv

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


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

