# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Core import logic for USDA FoodData Central data."""

from typing import Any

from cli_utils.console import (
    console,
    create_progress,
    print_db_connected,
    print_error,
    print_skip_message,
)

from .csv_validation import USDADataFiles
from .data_processing import parse_foods_csv, stream_food_nutrients
from .database import (
    get_database_connection,
    get_fdc_id_to_ingredient_id_map,
    insert_food_with_nutrients,
    insert_ingredient_portions,
)
from .portion_processing import stream_portions


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
    results: dict[str, Any] = {
        "foods_imported": 0,
        "foods_skipped": 0,
        "portions_imported": 0,
        "portions_skipped": 0,
        "total_foods_in_source": 0,
        "errors": [],
    }

    conn = None

    try:
        # Get database connection
        with console.status("[bold green]Connecting to database..."):
            conn = get_database_connection()
            cursor = conn.cursor()

        host = conn.info.host or "localhost"
        port = str(conn.info.port or 5432)
        print_db_connected(host, port)

        console.rule("[bold blue]📥 Import")
        console.print()

        # Step 1: Parse food.csv with progress
        with create_progress() as progress:
            task = progress.add_task("[cyan]Parsing food.csv", total=None)
            foods = parse_foods_csv(data_files.food_csv)
            results["total_foods_in_source"] = len(foods)
            progress.update(
                task,
                completed=len(foods),
                total=len(foods),
                description=f"[green]Parsed food.csv ({len(foods):,} foods)",
            )

        # Step 2: Stream food_nutrient.csv with progress bar
        with create_progress() as progress:
            task = progress.add_task(
                "[cyan]Importing nutrients",
                total=len(foods),
            )

            batch_count = 0
            for food_data in stream_food_nutrients(data_files.food_nutrient_csv, foods):
                try:
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
                    progress.advance(task)

                    if batch_count >= 1000:
                        conn.commit()
                        batch_count = 0

                except Exception as e:
                    results["foods_skipped"] += 1
                    error_msg = f"Failed to insert food {food_data.fdc_id}: {e}"
                    if len(results["errors"]) < 100:
                        results["errors"].append(error_msg)
                    conn.rollback()

        conn.commit()

        # Show skip count if any
        skipped = results["total_foods_in_source"] - results["foods_imported"]
        if skipped > 0:
            print_skip_message(skipped, "incomplete data")

        # Step 3: Import portion data if food_portion.csv exists
        if data_files.food_portion_csv:
            fdc_to_ingredient = get_fdc_id_to_ingredient_id_map(cursor)
            valid_fdc_ids = set(fdc_to_ingredient.keys())

            # Count total portions for progress bar
            portion_count = sum(
                1 for _ in stream_portions(data_files.food_portion_csv, valid_fdc_ids)
            )

            with create_progress() as progress:
                task = progress.add_task(
                    "[cyan]Importing portions",
                    total=portion_count,
                )

                portion_batch: list[dict] = []
                batch_size = 1000

                for portion in stream_portions(
                    data_files.food_portion_csv, valid_fdc_ids
                ):
                    portion_batch.append(
                        {
                            "fdc_id": portion.fdc_id,
                            "portion_description": portion.portion_description,
                            "unit": portion.unit,
                            "modifier": portion.modifier,
                            "gram_weight": portion.gram_weight,
                            "sequence_number": portion.sequence_number,
                        }
                    )
                    progress.advance(task)

                    if len(portion_batch) >= batch_size:
                        inserted, skipped = insert_ingredient_portions(
                            cursor, portion_batch, fdc_to_ingredient
                        )
                        results["portions_imported"] += inserted
                        results["portions_skipped"] += skipped
                        conn.commit()
                        portion_batch = []

                # Insert remaining portions
                if portion_batch:
                    inserted, skipped = insert_ingredient_portions(
                        cursor, portion_batch, fdc_to_ingredient
                    )
                    results["portions_imported"] += inserted
                    results["portions_skipped"] += skipped
                    conn.commit()

            if results["portions_skipped"] > 0:
                print_skip_message(results["portions_skipped"], "no ingredient match")
        else:
            console.print("[dim]Skipping portions (food_portion.csv not found)[/]")

    except Exception as e:
        error_msg = f"Import failed: {e}"
        print_error(error_msg)
        results["errors"].append(error_msg)
        if conn:
            conn.rollback()
        raise

    finally:
        if conn:
            conn.close()

    return results
