"""
CSV file validation utilities for OpenFoodFacts data import.
"""

import logging
from pathlib import Path

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
