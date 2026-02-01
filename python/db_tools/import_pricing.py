#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Download and import pricing data from USDA and Kaggle sources.

This script handles the complete pricing import workflow:
1. Download USDA datasets automatically (or use provided files)
2. Seed food group pricing from USDA FMAP data or defaults
3. Import ingredient pricing from USDA Fruit & Vegetable Prices
4. Import ingredient pricing from USDA Meat Price Spreads
5. Optional fallback import from Kaggle grocery dataset

Usage:
    python -m db_tools.import_pricing                    # Full auto workflow
    python -m db_tools.import_pricing --keep-files       # Keep downloaded files
    python -m db_tools.import_pricing --skip-fvp         # Skip fruit/veg import
    python -m db_tools.import_pricing --usda-fvp PATH    # Use manual file path
"""

import argparse
import sys
import time
from decimal import Decimal
from pathlib import Path

import httpx
from cli_utils.console import (
    console,
    create_download_progress,
    create_progress,
    get_pricing_stats_from_db,
    print_done,
    print_error,
    print_food_group_price_chart,
    print_header,
    print_price_distribution_chart,
    print_pricing_coverage_chart,
    print_pricing_import_summary,
    print_success,
    print_warning,
)
from cli_utils.database import get_database_connection
from cli_utils.environment import get_data_dir, load_env

# Add parent to path for nutritional_data_importer imports
sys.path.insert(0, str(Path(__file__).parents[1]))

from nutritional_data_importer.database import (  # noqa: E402
    get_ingredients_without_pricing,
    upsert_food_group_pricing,
    upsert_ingredient_pricing,
)
from nutritional_data_importer.pricing_processing import (  # noqa: E402
    fuzzy_match_ingredient,
    parse_fmap_data,
    parse_kaggle_grocery_data,
    parse_usda_fvp_data,
    parse_usda_meat_data,
)

# USDA Download URLs (from ERS data products pages)
# FVP: https://www.ers.usda.gov/data-products/fruit-and-vegetable-prices
# Meat: https://www.ers.usda.gov/data-products/meat-price-spreads
USDA_FVP_URLS = {
    "fruits": "https://www.ers.usda.gov/media/6210/all-fruits-average-prices-csv-format.csv",
    "vegetables": "https://www.ers.usda.gov/media/6240/all-vegetables-average-prices-csv-format.csv",
}
USDA_MEAT_URL = "https://www.ers.usda.gov/media/5024/retail-prices-for-beef-pork-poultry-cuts-eggs-and-dairy-products.csv"


def download_file(url: str, dest: Path, force: bool = False) -> bool:
    """Download a file with progress bar.

    Args:
        url: URL to download
        dest: Destination path
        force: Force re-download even if file exists

    Returns:
        True if download succeeded or file exists, False on error
    """
    if dest.exists() and not force:
        size_kb = dest.stat().st_size / 1024
        console.print(
            f"[bold green]✓[/] File exists: [cyan]{dest.name}[/] ({size_kb:.1f} KB)"
        )
        console.print("  [dim]Use --force-download to re-download[/]")
        return True

    console.print(f"[bold blue]↓[/] Downloading: [cyan]{url}[/]")

    try:
        with httpx.stream("GET", url, follow_redirects=True, timeout=60.0) as response:
            response.raise_for_status()

            total = int(response.headers.get("content-length", 0))

            with create_download_progress() as progress:
                task = progress.add_task(
                    f"[cyan]{dest.name}",
                    total=total if total > 0 else None,
                )

                with open(dest, "wb") as f:
                    for chunk in response.iter_bytes(chunk_size=8192):
                        f.write(chunk)
                        progress.advance(task, len(chunk))

        size_kb = dest.stat().st_size / 1024
        print_success(f"Downloaded {dest.name} ({size_kb:.1f} KB)")
        return True

    except httpx.HTTPStatusError as e:
        print_error(f"HTTP error: {e.response.status_code} - {url}")
        return False
    except httpx.RequestError as e:
        print_error(f"Download failed: {e}")
        return False


def cleanup_files(files: list[Path], keep: bool) -> None:
    """Clean up downloaded files.

    Args:
        files: List of file paths to clean up
        keep: If True, keep files instead of deleting
    """
    if keep:
        console.print("[dim]Keeping downloaded files (--keep-files)[/]")
        return

    console.print("[bold blue]🧹[/] Cleaning up temporary files...")

    for file_path in files:
        if file_path.exists():
            file_path.unlink()
            console.print(f"  [dim]Removed {file_path.name}[/]")


def seed_food_group_pricing(cursor, fmap_path: Path | None = None) -> int:
    """Seed food group pricing from FMAP data or defaults.

    Args:
        cursor: Database cursor
        fmap_path: Optional path to FMAP Excel file

    Returns:
        Number of food groups seeded
    """
    console.print("[bold blue]🏷️[/] Seeding food group pricing...")

    count = 0

    if fmap_path and fmap_path.exists():
        # Parse FMAP data and aggregate by food group
        console.print(f"  [dim]Using FMAP data from {fmap_path}[/]")
        for pricing in parse_fmap_data(fmap_path):
            upsert_food_group_pricing(
                cursor,
                food_group=pricing.food_group,
                price_per_100g=float(pricing.avg_price_per_100g),
                data_source=pricing.data_source,
                notes=pricing.notes,
            )
            count += 1
            console.print(
                f"  [green]✓[/] {pricing.food_group}: "
                f"${pricing.avg_price_per_100g}/100g"
            )
    else:
        # Use fallback defaults based on USDA FMAP averages
        console.print("  [dim]Using default FMAP-based averages[/]")
        defaults = {
            "VEGETABLES": (Decimal("0.35"), "Fresh vegetables average"),
            "FRUITS": (Decimal("0.45"), "Fresh fruits average"),
            "GRAINS": (Decimal("0.15"), "Dry grains (rice, flour, oats)"),
            "LEGUMES": (Decimal("0.20"), "Dry beans, lentils, chickpeas"),
            "NUTS_SEEDS": (Decimal("1.50"), "Mixed nuts and seeds"),
            "SPICES_HERBS": (Decimal("2.00"), "Dried spices and herbs"),
            "MEAT": (Decimal("1.20"), "Beef, pork, lamb average"),
            "POULTRY": (Decimal("0.80"), "Chicken, turkey average"),
            "SEAFOOD": (Decimal("1.80"), "Fish and shellfish average"),
            "DAIRY": (Decimal("0.40"), "Milk, cheese, yogurt, eggs"),
            "BEVERAGES": (Decimal("0.10"), "Non-alcoholic beverages"),
            "PROCESSED_FOODS": (Decimal("0.60"), "Packaged/processed foods"),
            "UNKNOWN": (Decimal("0.50"), "Fallback for unclassified"),
        }

        for food_group, (price, notes) in defaults.items():
            upsert_food_group_pricing(
                cursor,
                food_group=food_group,
                price_per_100g=float(price),
                data_source="USDA_FMAP",
                notes=notes,
            )
            count += 1
            console.print(f"  [green]✓[/] {food_group}: ${price}/100g")

    return count


def import_usda_fvp(
    cursor, file_path: Path, source_year: int = 2023
) -> tuple[int, int]:
    """Import pricing from USDA Fruit & Vegetable Prices dataset.

    Args:
        cursor: Database cursor
        file_path: Path to FVP Excel/CSV file
        source_year: Year of the price data

    Returns:
        Tuple of (imported_count, skipped_count)
    """
    console.print("[bold blue]🥬[/] Importing USDA Fruit & Vegetable Prices...")
    console.print(f"  [dim]Source: {file_path}[/]")

    # Collect items first for progress bar
    items = list(parse_usda_fvp_data(file_path, source_year))
    imported = 0
    skipped = 0

    with create_progress() as progress:
        task = progress.add_task("[cyan]Importing FVP pricing", total=len(items))

        for pricing in items:
            # Try to match to existing ingredient
            ingredient_id = fuzzy_match_ingredient(cursor, pricing.name)

            if ingredient_id:
                upsert_ingredient_pricing(
                    cursor,
                    ingredient_id=ingredient_id,
                    price_per_100g=float(pricing.price_per_100g),
                    data_source=pricing.data_source,
                    source_year=pricing.source_year,
                    notes=pricing.notes,
                )
                imported += 1
            else:
                skipped += 1

            progress.advance(task)

    console.print(f"  [dim]Imported {imported}, skipped {skipped} (no match)[/]")
    return imported, skipped


def import_usda_meat(
    cursor, file_path: Path, source_year: int | None = None
) -> tuple[int, int]:
    """Import pricing from USDA Meat Price Spreads dataset.

    Args:
        cursor: Database cursor
        file_path: Path to Meat Price Spreads CSV
        source_year: Optional year override

    Returns:
        Tuple of (imported_count, skipped_count)
    """
    console.print("[bold blue]🥩[/] Importing USDA Meat Price Spreads...")
    console.print(f"  [dim]Source: {file_path}[/]")

    # Collect items first for progress bar
    items = list(parse_usda_meat_data(file_path, source_year))
    imported = 0
    skipped = 0

    with create_progress() as progress:
        task = progress.add_task("[cyan]Importing meat pricing", total=len(items))

        for pricing in items:
            # Try to match to existing ingredient
            ingredient_id = fuzzy_match_ingredient(cursor, pricing.name)

            if ingredient_id:
                upsert_ingredient_pricing(
                    cursor,
                    ingredient_id=ingredient_id,
                    price_per_100g=float(pricing.price_per_100g),
                    data_source=pricing.data_source,
                    source_year=pricing.source_year,
                    notes=pricing.notes,
                )
                imported += 1
            else:
                skipped += 1

            progress.advance(task)

    console.print(f"  [dim]Imported {imported}, skipped {skipped} (no match)[/]")
    return imported, skipped


def import_kaggle_fallback(cursor, csv_path: Path) -> tuple[int, int]:
    """Import pricing from Kaggle grocery dataset for remaining ingredients.

    Only imports for ingredients that don't already have pricing.

    Args:
        cursor: Database cursor
        csv_path: Path to Kaggle grocery CSV

    Returns:
        Tuple of (imported_count, skipped_count)
    """
    console.print("[bold blue]🛒[/] Importing Kaggle fallback pricing...")
    console.print(f"  [dim]Source: {csv_path}[/]")

    # Get ingredients without pricing
    missing = get_ingredients_without_pricing(cursor)
    missing_ids = {row[0] for row in missing}
    console.print(f"  [dim]{len(missing_ids)} ingredients need pricing[/]")

    # Collect items first for progress bar
    items = list(parse_kaggle_grocery_data(csv_path))
    imported = 0
    skipped = 0

    with create_progress() as progress:
        task = progress.add_task("[cyan]Importing Kaggle pricing", total=len(items))

        for pricing in items:
            # Try to match to existing ingredient
            ingredient_id = fuzzy_match_ingredient(cursor, pricing.name)

            if ingredient_id and ingredient_id in missing_ids:
                upsert_ingredient_pricing(
                    cursor,
                    ingredient_id=ingredient_id,
                    price_per_100g=float(pricing.price_per_100g),
                    data_source=pricing.data_source,
                    source_year=pricing.source_year,
                    notes=pricing.notes,
                )
                imported += 1
                missing_ids.discard(ingredient_id)
            else:
                skipped += 1

            progress.advance(task)

    console.print(f"  [dim]Imported {imported}, skipped {skipped}[/]")
    console.print(f"  [dim]{len(missing_ids)} ingredients still need pricing[/]")
    return imported, skipped


def main() -> int:
    """Run the pricing import workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Download and import pricing data from USDA sources",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                           # Full auto workflow
  %(prog)s --keep-files              # Keep downloaded files
  %(prog)s --skip-fvp                # Skip fruit/vegetable import
  %(prog)s --skip-meat               # Skip meat import
  %(prog)s --usda-fvp data/fvp.xlsx  # Use manual file path

Data Sources:
  USDA FVP      https://www.ers.usda.gov/data-products/fruit-and-vegetable-prices
  USDA MEAT     https://www.ers.usda.gov/data-products/meat-price-spreads
  Kaggle        https://www.kaggle.com/datasets/elvinrustam/grocery-dataset
        """,
    )

    # Download control
    parser.add_argument(
        "--force-download",
        action="store_true",
        help="Force re-download even if files exist",
    )
    parser.add_argument(
        "--keep-files",
        action="store_true",
        help="Keep downloaded files after import",
    )

    # Skip options
    parser.add_argument(
        "--skip-food-groups",
        action="store_true",
        help="Skip seeding food group pricing defaults",
    )
    parser.add_argument(
        "--skip-fvp",
        action="store_true",
        help="Skip USDA Fruit & Vegetable Prices import",
    )
    parser.add_argument(
        "--skip-meat",
        action="store_true",
        help="Skip USDA Meat Price Spreads import",
    )

    # Manual file overrides
    parser.add_argument(
        "--fmap",
        type=Path,
        metavar="PATH",
        help="Path to USDA FMAP Excel file (for food group pricing)",
    )
    parser.add_argument(
        "--usda-fvp",
        type=Path,
        metavar="PATH",
        help="Path to USDA Fruit & Vegetable Prices file (overrides download)",
    )
    parser.add_argument(
        "--usda-meat",
        type=Path,
        metavar="PATH",
        help="Path to USDA Meat Price Spreads file (overrides download)",
    )
    parser.add_argument(
        "--kaggle",
        type=Path,
        metavar="PATH",
        help="Path to Kaggle grocery dataset CSV (fallback)",
    )

    parser.add_argument(
        "--source-year",
        type=int,
        default=2023,
        help="Year of price data (default: 2023)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )

    args = parser.parse_args()

    # Print header
    print_header(
        "💰 Pricing Data Importer",
        "Download and import pricing from USDA sources",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    start_time = time.time()

    # Build paths for downloads
    data_dir = get_data_dir() / "imports" / "pricing"
    data_dir.mkdir(parents=True, exist_ok=True)

    downloaded_files: list[Path] = []

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()
    console.print(f"  [bold]Source year[/]   [cyan]{args.source_year}[/]")
    console.print(f"  [bold]Data dir[/]      [cyan]{data_dir}[/]")
    console.print()

    try:
        # Check database connection
        with console.status("[bold green]Checking database connection..."):
            conn = get_database_connection()
            cursor = conn.cursor()
            host = conn.info.host or "localhost"
            port = conn.info.port or 5432
        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    # Track totals
    total_food_groups = 0
    total_imported = 0
    total_skipped = 0
    errors: list[str] = []

    try:
        # Step 1: Seed food group pricing
        if not args.skip_food_groups:
            console.rule("[bold blue]📊 Food Group Pricing")
            console.print()
            total_food_groups = seed_food_group_pricing(cursor, args.fmap)
            conn.commit()
            print_success(f"Seeded {total_food_groups} food group prices")
            console.print()

        # Step 2: Download and import USDA FVP
        if not args.skip_fvp:
            console.rule("[bold blue]📥 USDA Fruit & Vegetable Prices")
            console.print()

            # Determine file path (manual or download)
            if args.usda_fvp and args.usda_fvp.exists():
                fvp_path = args.usda_fvp
            else:
                # Download both fruits and vegetables files
                for name, url in USDA_FVP_URLS.items():
                    dest = data_dir / f"usda_fvp_{name}.csv"
                    if download_file(url, dest, force=args.force_download):
                        downloaded_files.append(dest)
                        # Import this file
                        imported, skipped = import_usda_fvp(
                            cursor, dest, args.source_year
                        )
                        total_imported += imported
                        total_skipped += skipped
                        conn.commit()
                    else:
                        errors.append(f"Failed to download {name} FVP data")

                fvp_path = None  # Already processed

            # If manual path provided, import it
            if fvp_path:
                imported, skipped = import_usda_fvp(cursor, fvp_path, args.source_year)
                total_imported += imported
                total_skipped += skipped
                conn.commit()

            print_success("FVP import complete")
            console.print()

        # Step 3: Download and import USDA Meat
        if not args.skip_meat:
            console.rule("[bold blue]📥 USDA Meat Price Spreads")
            console.print()

            # Determine file path (manual or download)
            if args.usda_meat and args.usda_meat.exists():
                meat_path = args.usda_meat
            else:
                meat_path = data_dir / "usda_meat_retail.csv"
                if not download_file(
                    USDA_MEAT_URL, meat_path, force=args.force_download
                ):
                    errors.append("Failed to download meat price data")
                    meat_path = None
                else:
                    downloaded_files.append(meat_path)

            if meat_path:
                imported, skipped = import_usda_meat(
                    cursor, meat_path, args.source_year
                )
                total_imported += imported
                total_skipped += skipped
                conn.commit()
                print_success("Meat import complete")
            console.print()

        # Step 4: Import Kaggle fallback (if provided)
        if args.kaggle and args.kaggle.exists():
            console.rule("[bold blue]📥 Kaggle Fallback")
            console.print()
            imported, skipped = import_kaggle_fallback(cursor, args.kaggle)
            total_imported += imported
            total_skipped += skipped
            conn.commit()
            print_success("Kaggle import complete")
            console.print()

        # Print summary and charts
        duration = time.time() - start_time

        console.rule("[bold blue]📊 Import Summary")
        console.print()

        print_pricing_import_summary(
            food_groups_seeded=total_food_groups,
            ingredients_imported=total_imported,
            ingredients_skipped=total_skipped,
            duration=duration,
            errors=errors if errors else None,
        )

        # Generate and display charts
        if total_imported > 0 or total_food_groups > 0:
            with console.status("[bold green]Generating charts..."):
                stats = get_pricing_stats_from_db(cursor)

            if stats.get("by_source"):
                print_pricing_coverage_chart(
                    by_source=stats["by_source"],
                    total_ingredients=stats.get("total_ingredients", 0),
                )

            if stats.get("price_distribution"):
                print_price_distribution_chart(
                    price_buckets=stats["price_distribution"],
                )

            if stats.get("by_food_group"):
                print_food_group_price_chart(
                    by_food_group=stats["by_food_group"],
                )

        conn.close()

        # Cleanup
        cleanup_files(downloaded_files, args.keep_files)

        print_done(
            f"Pricing import complete! {total_imported} imported, "
            f"{total_skipped} skipped"
        )

        return 1 if errors else 0

    except KeyboardInterrupt:
        console.print()
        print_warning("Import interrupted by user")
        cleanup_files(downloaded_files, args.keep_files)
        return 130

    except Exception as e:
        print_error(f"Import failed: {e}")
        if args.verbose:
            console.print_exception()
        cleanup_files(downloaded_files, args.keep_files)
        return 1


if __name__ == "__main__":
    sys.exit(main())
