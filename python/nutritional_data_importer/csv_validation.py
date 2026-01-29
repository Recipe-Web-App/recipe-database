# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""CSV file validation utilities for USDA FoodData Central data import."""

import logging
from pathlib import Path

logger = logging.getLogger(__name__)


class USDADataFiles:
    """Container for validated USDA data file paths."""

    def __init__(
        self,
        food_csv: Path,
        food_nutrient_csv: Path,
        nutrient_csv: Path,
        food_portion_csv: Path | None = None,
    ):
        """Initialize with paths to required USDA CSV files."""
        self.food_csv = food_csv
        self.food_nutrient_csv = food_nutrient_csv
        self.nutrient_csv = nutrient_csv
        self.food_portion_csv = food_portion_csv


def validate_usda_directory(data_dir: str) -> USDADataFiles:
    """Validate that the USDA data directory contains required CSV files.

    USDA FoodData Central downloads have this structure:
        FoodData_Central_*_csv_YYYY-MM-DD/
        +-- food.csv                 # Food items with fdc_id, description
        +-- food_nutrient.csv        # Nutrient values per food
        +-- nutrient.csv             # Nutrient definitions

    Args:
        data_dir: Path to the extracted USDA data directory

    Returns:
        USDADataFiles with validated paths

    Raises:
        FileNotFoundError: If directory or required files don't exist
        ValueError: If path is not a directory
    """
    path = Path(data_dir)

    if not path.exists():
        raise FileNotFoundError(f"USDA data directory not found: {data_dir}")

    if not path.is_dir():
        raise ValueError(f"Path is not a directory: {data_dir}")

    # Check for required files
    required_files = {
        "food.csv": path / "food.csv",
        "food_nutrient.csv": path / "food_nutrient.csv",
        "nutrient.csv": path / "nutrient.csv",
    }

    missing_files = []
    for name, file_path in required_files.items():
        if not file_path.exists():
            missing_files.append(name)
        elif not file_path.is_file():
            raise ValueError(f"Expected file but found directory: {file_path}")

    if missing_files:
        raise FileNotFoundError(
            f"Missing required USDA CSV files in {data_dir}: {', '.join(missing_files)}"
        )

    # Log file sizes for debugging
    for name, file_path in required_files.items():
        size_mb = file_path.stat().st_size / (1024 * 1024)
        logger.info(f"  {name}: {size_mb:.2f} MB")

    # Check for optional food_portion.csv (for portion weight data)
    food_portion_path = path / "food_portion.csv"
    food_portion_csv: Path | None = None
    if food_portion_path.exists() and food_portion_path.is_file():
        size_mb = food_portion_path.stat().st_size / (1024 * 1024)
        logger.info(f"  food_portion.csv: {size_mb:.2f} MB (optional, found)")
        food_portion_csv = food_portion_path
    else:
        logger.info("  food_portion.csv: not found (optional, skipping portions)")

    logger.info(f"Validated USDA data directory: {path.absolute()}")

    return USDADataFiles(
        food_csv=required_files["food.csv"],
        food_nutrient_csv=required_files["food_nutrient.csv"],
        nutrient_csv=required_files["nutrient.csv"],
        food_portion_csv=food_portion_csv,
    )
