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
import sys
import time
from pathlib import Path

from cli_utils.console import (
    console,
    get_import_stats_from_db,
    print_config,
    print_done,
    print_error,
    print_header,
    print_import_summary,
    print_nutrient_coverage,
    print_top_ingredients_table,
    print_unit_chart,
)
from cli_utils.environment import get_config

from .csv_validation import validate_usda_directory
from .database import get_database_connection
from .import_core import import_usda_data


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

    # Print styled header
    print_header(
        "🍎 USDA FoodData Central Importer",
        "Nutritional data import from USDA FoodData Central",
    )

    # Print configuration
    config = get_config()

    print_config(
        {
            "Dataset": Path(data_dir).name,
            "Database": f"{config.host}:{config.port}",
            "Schema": config.schema,
            "DB Name": config.database,
        }
    )

    start_time = time.time()

    try:
        # Validate input directory
        with console.status("[bold green]Validating USDA data directory..."):
            data_files = validate_usda_directory(data_dir)
        console.print(
            f"[bold green]✓[/] Found valid USDA dataset at [cyan]{data_dir}[/]"
        )
        console.print()

        # Run the import
        results = import_usda_data(data_files)

        duration = time.time() - start_time

        # Print summary panel
        print_import_summary(
            foods_imported=results["foods_imported"],
            foods_skipped=results["foods_skipped"],
            portions_imported=results["portions_imported"],
            portions_skipped=results["portions_skipped"],
            duration=duration,
            errors=results["errors"] if results["errors"] else None,
        )

        # Display charts if we imported data
        if results["foods_imported"] > 0:
            with console.status("[bold green]Generating charts..."):
                conn = get_database_connection()
                cursor = conn.cursor()
                stats = get_import_stats_from_db(cursor)
                conn.close()

            # Show portions by unit chart
            if stats.get("unit_counts"):
                print_unit_chart(stats["unit_counts"])

            # Show nutrient coverage chart
            if stats.get("total_foods", 0) > 0:
                print_nutrient_coverage(
                    total_foods=stats["total_foods"],
                    with_macros=stats.get("with_macros", 0),
                    with_vitamins=stats.get("with_vitamins", 0),
                    with_minerals=stats.get("with_minerals", 0),
                )

            # Show top ingredients table
            if stats.get("top_ingredients"):
                print_top_ingredients_table(stats["top_ingredients"])

        # Print done message
        print_done(f"All done! Data ready in {config.schema} schema.")

        # Exit with appropriate code
        if results["errors"]:
            sys.exit(1)
        else:
            sys.exit(0)

    except KeyboardInterrupt:
        console.print()
        console.print("[bold yellow]![/] Import interrupted by user")
        sys.exit(130)
    except Exception as e:
        print_error(f"Import failed: {e}")
        if args.verbose:
            console.print_exception()
        sys.exit(1)


if __name__ == "__main__":
    main()
