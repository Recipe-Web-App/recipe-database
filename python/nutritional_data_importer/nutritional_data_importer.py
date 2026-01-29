#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""USDA FoodData Central Nutritional Data Importer.

This script imports nutritional data from USDA FoodData Central CSV files
into the recipe database nutrition tables.
"""

import argparse
import logging
import sys
from pathlib import Path

from csv_validation import validate_usda_directory
from import_core import import_usda_data

# Add parent directory to path to find shared modules
sys.path.append(str(Path(__file__).parent.parent))

# Set up logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


def print_results(results: dict) -> None:
    """Print a summary of the import results."""
    print(f"\n{'='*50}")
    print("IMPORT RESULTS")
    print(f"{'='*50}")
    print(f"Total foods in source: {results.get('total_foods_in_source', 0):,}")
    print(f"Foods imported: {results['foods_imported']:,}")
    print(f"Foods skipped: {results['foods_skipped']:,}")

    if results["errors"]:
        print("")
        print(f"Errors: {len(results['errors'])}")
        for error in results["errors"][:5]:
            print(f"  - {error}")
        if len(results["errors"]) > 5:
            print(f"  ... and {len(results['errors']) - 5} more errors")
    else:
        print("No errors")
    print(f"{'='*50}\n")


def main() -> None:
    """Import USDA FoodData Central data into recipe database."""
    parser = argparse.ArgumentParser(
        description="Import USDA FoodData Central data into recipe database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s /data/FoodData_Central_foundation_food_csv_2024-04-18
  %(prog)s --data-dir /path/to/usda/csv

The data directory should contain:
  - food.csv           (food items with fdc_id, description)
  - food_nutrient.csv  (nutrient values per food)
  - nutrient.csv       (nutrient definitions)

Download from: https://fdc.nal.usda.gov/download-datasets.html
        """,
    )

    parser.add_argument(
        "data_dir",
        nargs="?",
        help="Path to the extracted USDA FoodData Central CSV directory",
    )
    parser.add_argument(
        "--data-dir",
        dest="data_dir_opt",
        help="Alternative way to specify the data directory",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )

    args = parser.parse_args()

    # Get data directory from either positional or optional argument
    data_dir = args.data_dir or args.data_dir_opt
    if not data_dir:
        parser.error("Data directory is required")

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        # Validate input directory
        logger.info(f"Validating USDA data directory: {data_dir}")
        data_files = validate_usda_directory(data_dir)

        # Run the import
        logger.info("Starting import...")
        results = import_usda_data(data_files)

        # Print results
        print_results(results)

        # Exit with appropriate code
        if results["errors"]:
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


if __name__ == "__main__":
    main()
