# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Portion processing utilities for USDA FoodData Central import.

Handles parsing and transforming USDA portion data from food_portion.csv
into database-ready format for ingredient_portions table.
"""

import contextlib
import logging
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

import pandas as pd

logger = logging.getLogger(__name__)


# Unit normalization patterns - order matters (more specific first)
UNIT_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    # Volume units
    (re.compile(r"\btablespoons?\b|\btbsps?\b", re.IGNORECASE), "TBSP"),
    (re.compile(r"\bteaspoons?\b|\btsps?\b", re.IGNORECASE), "TSP"),
    (re.compile(r"\bcups?\b", re.IGNORECASE), "CUP"),
    (re.compile(r"\bmilliliters?\b|\bml\b", re.IGNORECASE), "ML"),
    (re.compile(r"\bliters?\b|\bl\b", re.IGNORECASE), "L"),
    # Weight units
    (re.compile(r"\bgrams?\b|\bg\b", re.IGNORECASE), "G"),
    (re.compile(r"\bkilograms?\b|\bkg\b", re.IGNORECASE), "KG"),
    (re.compile(r"\bounces?\b|\boz\b", re.IGNORECASE), "OZ"),
    (re.compile(r"\bpounds?\b|\blb\b", re.IGNORECASE), "LB"),
    # Count units - specific first
    (re.compile(r"\bslices?\b", re.IGNORECASE), "SLICE"),
    (re.compile(r"\bcloves?\b", re.IGNORECASE), "CLOVE"),
    # Generic count units (fallback)
    (
        re.compile(
            r"\bpieces?\b|\bwhole\b|\bmedium\b|\blarge\b|\bsmall\b|\beach\b",
            re.IGNORECASE,
        ),
        "PIECE",
    ),
]


def normalize_unit(portion_description: str) -> str:
    """Normalize USDA portion description to IngredientUnit enum value.

    Scans the description for unit keywords and returns the matching enum.
    Falls back to PIECE for unrecognized patterns.

    Args:
        portion_description: USDA portion description (e.g., "1 cup, chopped")

    Returns:
        Normalized unit string (e.g., "CUP", "TBSP", "PIECE")
    """
    for pattern, unit in UNIT_PATTERNS:
        if pattern.search(portion_description):
            return unit

    # Default to PIECE for unrecognized patterns
    return "PIECE"


@dataclass
class PortionData:
    """Container for a portion record ready for database insertion."""

    fdc_id: int
    portion_description: str
    unit: str
    modifier: str | None
    gram_weight: float
    sequence_number: int | None


def stream_portions(
    food_portion_csv: Path,
    valid_fdc_ids: set[int],
    chunk_size: int = 10000,
) -> Iterator[PortionData]:
    """Stream portion data from food_portion.csv.

    Args:
        food_portion_csv: Path to food_portion.csv
        valid_fdc_ids: Set of fdc_ids that exist in our database
        chunk_size: Rows per chunk for memory efficiency

    Yields:
        PortionData objects ready for database insertion
    """
    logger.info(f"Streaming food_portion.csv from {food_portion_csv}")

    rows_processed = 0
    portions_yielded = 0

    for chunk in pd.read_csv(food_portion_csv, chunksize=chunk_size, low_memory=False):
        for _, row in chunk.iterrows():
            rows_processed += 1

            fdc_id = row.get("fdc_id")
            portion_description = row.get("portion_description", "")
            modifier = row.get("modifier")
            gram_weight = row.get("gram_weight")
            seq_num = row.get("seq_num")

            # Skip rows with missing required fields
            if pd.isna(fdc_id) or pd.isna(gram_weight):
                continue

            # Skip foods not in our database
            try:
                fdc_id = int(fdc_id)
            except (ValueError, TypeError):
                continue

            if fdc_id not in valid_fdc_ids:
                continue

            # Clean and normalize data
            try:
                gram_weight = float(gram_weight)
            except (ValueError, TypeError):
                continue

            if gram_weight <= 0:
                continue

            # Get amount and modifier (which contains unit info in SR Legacy)
            amount = row.get("amount", 1)
            try:
                amount = float(amount)
            except (ValueError, TypeError):
                amount = 1.0

            # Clean modifier - this contains unit info like "cup", "oz", "tbsp"
            mod = None
            if modifier and not pd.isna(modifier):
                mod = str(modifier).strip()
                if not mod:
                    mod = None

            # Build portion description from amount + modifier
            # USDA SR Legacy has empty portion_description, info is in modifier
            portion_desc = (
                str(portion_description).strip()
                if portion_description and not pd.isna(portion_description)
                else ""
            )
            if not portion_desc and mod:
                # Format amount nicely (1.0 -> "1", 0.5 -> "0.5")
                amt_str = str(int(amount)) if amount == int(amount) else str(amount)
                portion_desc = f"{amt_str} {mod}"
            elif not portion_desc:
                portion_desc = "1 serving"

            # Normalize unit based on modifier (which has the unit) or portion_desc
            unit_source = mod if mod else portion_desc
            unit = normalize_unit(unit_source)

            # Clean sequence number
            seq = None
            if seq_num and not pd.isna(seq_num):
                with contextlib.suppress(ValueError, TypeError):
                    seq = int(seq_num)

            portions_yielded += 1
            yield PortionData(
                fdc_id=fdc_id,
                portion_description=portion_desc,
                unit=unit,
                modifier=mod,
                gram_weight=gram_weight,
                sequence_number=seq,
            )

        if rows_processed % 50000 == 0:
            logger.info(f"Processed {rows_processed:,} portion rows...")

    logger.info(
        f"Finished processing {rows_processed:,} portion rows, "
        f"yielded {portions_yielded:,} portions"
    )
