#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Download and import USDA FoodData Central nutritional data.

This script handles the complete workflow:
1. Download USDA FoodData Central ZIP from fdc.nal.usda.gov
2. Extract CSV files
3. Import into database with progress visualization
4. Clean up temporary files

Usage:
    python -m db_tools.import_nutrition
    python -m db_tools.import_nutrition --dataset foundation_food --date 2024-04-18
    python -m db_tools.import_nutrition --keep-files
"""

import argparse
import shutil
import sys
import time
import zipfile
from pathlib import Path

import httpx
from cli_utils.console import (
    console,
    create_download_progress,
    print_done,
    print_error,
    print_header,
    print_success,
    print_warning,
)
from cli_utils.database import get_database_connection
from cli_utils.environment import get_data_dir, load_env

# Add parent to path for nutritional_data_importer imports
sys.path.insert(0, str(Path(__file__).parents[1]))

from nutritional_data_importer.csv_validation import (  # noqa: E402
    validate_usda_directory,
)
from nutritional_data_importer.import_core import import_usda_data  # noqa: E402

# USDA FoodData Central configuration
USDA_BASE_URL = "https://fdc.nal.usda.gov/fdc-datasets"
VALID_DATASETS = ["sr_legacy_food", "foundation_food"]


def build_usda_url(dataset: str, date: str) -> tuple[str, str]:
    """Build USDA download URL and filename.

    Args:
        dataset: Dataset name (sr_legacy_food or foundation_food)
        date: Release date (e.g., 2024-04-18 or 2018-04)

    Returns:
        Tuple of (url, filename)
    """
    filename = f"FoodData_Central_{dataset}_csv_{date}.zip"
    url = f"{USDA_BASE_URL}/{filename}"
    return url, filename


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
        size_mb = dest.stat().st_size / (1024 * 1024)
        console.print(
            f"[bold green]✓[/] File already exists: [cyan]{dest.name}[/] "
            f"({size_mb:.1f} MB)"
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

        size_mb = dest.stat().st_size / (1024 * 1024)
        print_success(f"Downloaded {dest.name} ({size_mb:.1f} MB)")
        return True

    except httpx.HTTPStatusError as e:
        print_error(f"HTTP error: {e.response.status_code} - {url}")
        return False
    except httpx.RequestError as e:
        print_error(f"Download failed: {e}")
        return False


def extract_zip(zip_path: Path, extract_dir: Path) -> Path | None:
    """Extract ZIP file and return path to CSV files.

    Args:
        zip_path: Path to ZIP file
        extract_dir: Directory to extract to

    Returns:
        Path to directory containing CSV files, or None on error
    """
    console.print(f"[bold blue]📦[/] Extracting: [cyan]{zip_path.name}[/]")

    try:
        # Clear extraction directory
        if extract_dir.exists():
            shutil.rmtree(extract_dir)
        extract_dir.mkdir(parents=True, exist_ok=True)

        with zipfile.ZipFile(zip_path, "r") as zf:
            # Count files for progress
            members = zf.namelist()

            with console.status(f"[bold green]Extracting {len(members)} files..."):
                zf.extractall(extract_dir)

        # Find the extracted subdirectory (USDA ZIPs contain a dated subdirectory)
        subdirs = [
            d
            for d in extract_dir.iterdir()
            if d.is_dir() and d.name.startswith("FoodData_Central_")
        ]

        if subdirs:
            # Move contents up one level
            subdir = subdirs[0]
            for item in subdir.iterdir():
                shutil.move(str(item), str(extract_dir / item.name))
            subdir.rmdir()

        # Verify required files
        required = ["food.csv", "food_nutrient.csv", "nutrient.csv"]
        missing = [f for f in required if not (extract_dir / f).exists()]

        if missing:
            print_error(f"Missing required files: {', '.join(missing)}")
            return None

        # List extracted files
        csv_files = sorted(extract_dir.glob("*.csv"))
        print_success(f"Extracted {len(csv_files)} CSV files")

        for csv_file in csv_files[:5]:
            size_mb = csv_file.stat().st_size / (1024 * 1024)
            console.print(f"  [dim]{csv_file.name}: {size_mb:.1f} MB[/]")
        if len(csv_files) > 5:
            console.print(f"  [dim]... and {len(csv_files) - 5} more[/]")

        return extract_dir

    except zipfile.BadZipFile:
        print_error(f"Invalid ZIP file: {zip_path}")
        return None
    except Exception as e:
        print_error(f"Extraction failed: {e}")
        return None


def cleanup_files(zip_path: Path, extract_dir: Path, keep: bool) -> None:
    """Clean up downloaded and extracted files.

    Args:
        zip_path: Path to ZIP file
        extract_dir: Extraction directory
        keep: If True, keep files instead of deleting
    """
    if keep:
        console.print("[dim]Keeping downloaded files (--keep-files)[/]")
        return

    console.print("[bold blue]🧹[/] Cleaning up temporary files...")

    if zip_path.exists():
        zip_path.unlink()
        console.print(f"  [dim]Removed {zip_path.name}[/]")

    if extract_dir.exists():
        shutil.rmtree(extract_dir)
        console.print(f"  [dim]Removed {extract_dir.name}/[/]")


def main() -> int:
    """Run the main import workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Download and import USDA FoodData Central nutritional data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                                    # Use defaults (sr_legacy_food)
  %(prog)s --dataset foundation_food          # Use Foundation Foods dataset
  %(prog)s --date 2024-04-18                  # Specify release date
  %(prog)s --force-download                   # Force re-download
  %(prog)s --keep-files                       # Keep files after import

Datasets:
  sr_legacy_food    - SR Legacy (~7,800 foods, recommended)
  foundation_food   - Foundation Foods (~2,600 foods)

Download page: https://fdc.nal.usda.gov/download-datasets.html
        """,
    )

    parser.add_argument(
        "--dataset",
        choices=VALID_DATASETS,
        default="sr_legacy_food",
        help="USDA dataset to download (default: sr_legacy_food)",
    )
    parser.add_argument(
        "--date",
        default="2018-04",
        help="Dataset release date (default: 2018-04 for SR Legacy)",
    )
    parser.add_argument(
        "--force-download",
        action="store_true",
        help="Force re-download even if file exists",
    )
    parser.add_argument(
        "--keep-files",
        action="store_true",
        help="Keep downloaded files after import",
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
        "🍎 USDA FoodData Central Importer",
        "Download and import nutritional data",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    start_time = time.time()

    # Build paths
    data_dir = get_data_dir() / "imports"
    data_dir.mkdir(parents=True, exist_ok=True)

    url, filename = build_usda_url(args.dataset, args.date)
    zip_path = data_dir / filename
    extract_dir = data_dir / "usda_data"

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()
    console.print(f"  [bold]Dataset[/]     [cyan]{args.dataset}[/]")
    console.print(f"  [bold]Date[/]        [cyan]{args.date}[/]")
    console.print(f"  [bold]URL[/]         [cyan]{url}[/]")
    console.print()

    try:
        # Check database connection
        with console.status("[bold green]Checking database connection..."):
            conn = get_database_connection()
            host = conn.info.host or "localhost"
            port = conn.info.port or 5432
            conn.close()
        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    console.rule("[bold blue]📥 Download & Extract")
    console.print()

    try:
        # Download
        if not download_file(url, zip_path, force=args.force_download):
            return 1

        console.print()

        # Extract
        csv_dir = extract_zip(zip_path, extract_dir)
        if csv_dir is None:
            return 1

        console.print()

        # Validate and import
        console.rule("[bold blue]📊 Import")
        console.print()

        with console.status("[bold green]Validating USDA data files..."):
            data_files = validate_usda_directory(str(csv_dir))
        print_success("USDA data files validated")
        console.print()

        # Run the import
        results = import_usda_data(data_files)

        # Check for errors
        if results["errors"]:
            print_warning(f"Import completed with {len(results['errors'])} warnings")

        console.print()

        # Cleanup
        cleanup_files(zip_path, extract_dir, args.keep_files)

        duration = time.time() - start_time
        console.print()
        print_done(
            f"Import complete! {results['foods_imported']:,} foods, "
            f"{results['portions_imported']:,} portions in {duration:.1f}s"
        )

        return 1 if results["errors"] else 0

    except KeyboardInterrupt:
        console.print()
        print_warning("Import interrupted by user")
        cleanup_files(zip_path, extract_dir, args.keep_files)
        return 130

    except Exception as e:
        print_error(f"Import failed: {e}")
        if args.verbose:
            console.print_exception()
        return 1


if __name__ == "__main__":
    sys.exit(main())
