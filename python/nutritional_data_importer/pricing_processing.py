# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Pricing data processing for USDA and Kaggle datasets.

Handles parsing and transforming pricing data from:
- USDA FMAP (Food-at-Home Monthly Area Prices) - food group averages
- USDA FVP (Fruit & Vegetable Prices) - ingredient-level
- USDA Meat Price Spreads - ingredient-level
- Kaggle grocery datasets - fallback for remaining ingredients
"""

import logging
import re
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Iterator

import pandas as pd

logger = logging.getLogger(__name__)

# Unit conversion constants
GRAMS_PER_POUND = Decimal("453.592")
GRAMS_PER_100G = Decimal("100")


@dataclass
class FoodGroupPricing:
    """Container for food group average pricing data."""

    food_group: str
    avg_price_per_100g: Decimal
    data_source: str
    notes: str | None = None


@dataclass
class IngredientPricing:
    """Container for ingredient-level pricing data."""

    name: str
    price_per_100g: Decimal
    data_source: str
    source_year: int | None = None
    notes: str | None = None


# USDA FMAP tier -> food_group_enum mapping
# FMAP uses 7 tiers with 90 subcategories
FMAP_TIER_TO_FOOD_GROUP: dict[str, str] = {
    "grains": "GRAINS",
    "vegetables": "VEGETABLES",
    "fruit": "FRUITS",
    "fruits": "FRUITS",
    "dairy": "DAIRY",
    "dairy and plant-based milk products": "DAIRY",
    "meat": "MEAT",
    "meat and protein foods": "MEAT",  # Will need category-level overrides
    "prepared meals": "PROCESSED_FOODS",
    "prepared meals, sides, and salads": "PROCESSED_FOODS",
    "other foods": "PROCESSED_FOODS",  # Default, with category overrides below
}

# FMAP category-level overrides for more precise mapping
# Key is lowercase category name from FMAP data
FMAP_CATEGORY_TO_FOOD_GROUP: dict[str, str] = {
    # Meat/protein tier overrides
    "poultry": "POULTRY",
    "chicken": "POULTRY",
    "turkey": "POULTRY",
    "fish": "SEAFOOD",
    "seafood": "SEAFOOD",
    "shellfish": "SEAFOOD",
    "finfish": "SEAFOOD",
    "eggs": "DAIRY",
    "legumes": "LEGUMES",
    "beans": "LEGUMES",
    "lentils": "LEGUMES",
    "peas": "LEGUMES",
    "tofu": "LEGUMES",
    "nuts": "NUTS_SEEDS",
    "seeds": "NUTS_SEEDS",
    "peanut butter": "NUTS_SEEDS",
    "nut butter": "NUTS_SEEDS",
    # Other foods tier overrides
    "beverages": "BEVERAGES",
    "coffee": "BEVERAGES",
    "tea": "BEVERAGES",
    "juice": "BEVERAGES",
    "soda": "BEVERAGES",
    "soft drink": "BEVERAGES",
    "water": "BEVERAGES",
    "spices": "SPICES_HERBS",
    "herbs": "SPICES_HERBS",
    "seasonings": "SPICES_HERBS",
    "condiments": "PROCESSED_FOODS",
    "sauces": "PROCESSED_FOODS",
    "oils": "PROCESSED_FOODS",
    "fats": "PROCESSED_FOODS",
    "sugar": "PROCESSED_FOODS",
    "sweeteners": "PROCESSED_FOODS",
    "candy": "PROCESSED_FOODS",
    "snacks": "PROCESSED_FOODS",
    "baked goods": "PROCESSED_FOODS",
    "bread": "GRAINS",
    "pasta": "GRAINS",
    "rice": "GRAINS",
    "cereal": "GRAINS",
}


def map_fmap_category_to_food_group(
    category_name: str, tier_name: str | None = None
) -> str:
    """Map FMAP category to food_group_enum value.

    First checks category-level overrides, then falls back to tier mapping.

    Args:
        category_name: FMAP category name (e.g., "Fresh vegetables")
        tier_name: Optional parent tier name for fallback

    Returns:
        food_group_enum value
    """
    category_lower = category_name.lower().strip()

    # Check category-level overrides first
    for pattern, food_group in FMAP_CATEGORY_TO_FOOD_GROUP.items():
        if pattern in category_lower:
            return food_group

    # Fall back to tier mapping
    if tier_name:
        tier_lower = tier_name.lower().strip()
        if tier_lower in FMAP_TIER_TO_FOOD_GROUP:
            return FMAP_TIER_TO_FOOD_GROUP[tier_lower]

    # Default fallback
    return "UNKNOWN"


def parse_fmap_data(
    xlsx_path: Path,
    area: str = "National",
) -> Iterator[FoodGroupPricing]:
    """Parse USDA FMAP Excel data for food group pricing.

    The FMAP dataset contains monthly unit values (price per gram) for
    90 food categories across 15 geographic areas.

    Args:
        xlsx_path: Path to FMAP Excel file
        area: Geographic area to use (default "National")

    Yields:
        FoodGroupPricing objects with averaged prices per food group
    """
    logger.info(f"Parsing FMAP data from {xlsx_path}")

    try:
        # Read the Excel file - structure may vary, try common sheet names
        xl = pd.ExcelFile(xlsx_path)
        sheet_names = xl.sheet_names
        logger.info(f"Found sheets: {sheet_names}")

        # Try to find the main data sheet
        data_sheet = None
        for name in ["Data", "Unit Values", "Prices", sheet_names[0]]:
            if name in sheet_names:
                data_sheet = name
                break

        if not data_sheet:
            data_sheet = sheet_names[0]

        df = pd.read_excel(xlsx_path, sheet_name=data_sheet)
        logger.info(f"Loaded {len(df)} rows from sheet '{data_sheet}'")
        logger.info(f"Columns: {list(df.columns)}")

        # Aggregate by food group
        food_group_prices: dict[str, list[Decimal]] = {}

        for _, row in df.iterrows():
            # Extract category/tier info - column names may vary
            category = None
            tier = None
            price = None

            # Try to find category column
            for col in ["EFPG", "Category", "Food Group", "food_group", "efpg"]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        category = str(val)
                        break

            # Try to find tier column
            for col in ["Tier", "tier", "Tier 1", "tier1"]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        tier = str(val)
                        break

            # Try to find price column (unit value = price per gram)
            for col in [
                "Unit_value_mean_wtd",
                "unit_value_mean",
                "price",
                "mean_price",
            ]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        try:
                            price = Decimal(str(val))
                            break
                        except (ValueError, InvalidOperation):
                            continue

            if category and price and price > 0:
                food_group = map_fmap_category_to_food_group(category, tier)
                if food_group not in food_group_prices:
                    food_group_prices[food_group] = []
                # Convert price per gram to price per 100g
                price_per_100g = price * GRAMS_PER_100G
                food_group_prices[food_group].append(price_per_100g)

        # Calculate averages per food group
        for food_group, prices in food_group_prices.items():
            if prices:
                avg_price = sum(prices) / Decimal(len(prices))
                yield FoodGroupPricing(
                    food_group=food_group,
                    avg_price_per_100g=avg_price.quantize(Decimal("0.0001")),
                    data_source="USDA_FMAP",
                    notes=f"Average of {len(prices)} FMAP categories",
                )

    except Exception as e:
        logger.error(f"Error parsing FMAP data: {e}")
        raise


def parse_usda_fvp_data(
    csv_path: Path,
    source_year: int = 2023,
) -> Iterator[IngredientPricing]:
    """Parse USDA Fruit & Vegetable Prices data.

    The FVP dataset contains prices per pound and per cup equivalent
    for ~150 commonly consumed fruits and vegetables.

    Args:
        csv_path: Path to FVP CSV file (ALL_FRUITS.csv or ALL_VEGETABLES.csv)
        source_year: Year of the price data

    Yields:
        IngredientPricing objects for each fruit/vegetable
    """
    logger.info(f"Parsing USDA FVP data from {csv_path}")

    try:
        df = pd.read_csv(csv_path)
        logger.info(f"Loaded {len(df)} rows")
        logger.info(f"Columns: {list(df.columns)}")

        rows_processed = 0
        items_yielded = 0

        for _, row in df.iterrows():
            rows_processed += 1

            # Extract item name - try common column names
            name = None
            for col in [
                "Fruit",
                "Vegetable",
                "Food",
                "Item",
                "Name",
                "food",
                "item",
                "name",
                "Commodity",
            ]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        name = str(val).strip()
                        break

            if not name:
                continue

            # Extract price per pound - try common column names
            price_per_lb = None
            for col in [
                "AverageRetailPrice",
                "Retail_price_per_pound",
                "price_per_pound",
                "Price_per_lb",
                "retail_price",
                "price",
            ]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        try:
                            price_per_lb = Decimal(str(val).replace("$", "").strip())
                            break
                        except (ValueError, InvalidOperation):
                            continue

            if not price_per_lb or price_per_lb <= 0:
                continue

            # Convert $/lb to $/100g
            # $X/lb ÷ 453.592g/lb × 100g = $X × 100 / 453.592
            price_per_100g = (price_per_lb * GRAMS_PER_100G / GRAMS_PER_POUND).quantize(
                Decimal("0.0001")
            )

            # Extract form (fresh, frozen, canned, etc.) for notes
            form = None
            for col in ["Form", "form", "Type", "type"]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        form = str(val).strip()
                        break

            notes = f"{form}" if form else None

            items_yielded += 1
            yield IngredientPricing(
                name=name,
                price_per_100g=price_per_100g,
                data_source="USDA_FVP",
                source_year=source_year,
                notes=notes,
            )

        logger.info(f"Processed {rows_processed} rows, yielded {items_yielded} items")

    except Exception as e:
        logger.error(f"Error parsing USDA FVP data: {e}")
        raise


def parse_usda_meat_data(
    csv_path: Path,
    source_year: int | None = None,
) -> Iterator[IngredientPricing]:
    """Parse USDA Meat Price Spreads data.

    The Meat Price Spreads dataset contains retail prices for beef, pork,
    poultry, eggs, and dairy products. Data is structured as time series
    with Year, Month, Data_Item, Value columns.

    Args:
        csv_path: Path to Meat Price Spreads CSV
        source_year: Optional year override (auto-detected from data if None)

    Yields:
        IngredientPricing objects for each meat/protein item (averaged prices)
    """
    logger.info(f"Parsing USDA Meat Price Spreads data from {csv_path}")

    try:
        df = pd.read_csv(csv_path)
        logger.info(f"Loaded {len(df)} rows")
        logger.info(f"Columns: {list(df.columns)}")

        # The meat CSV is a time series - aggregate by Data_Item
        # Group by item and take most recent year's average
        item_prices: dict[str, list[tuple[int, Decimal]]] = {}

        for _, row in df.iterrows():
            # Extract item name from Data_Item column
            name = None
            for col in [
                "Data_Item",
                "Item",
                "Product",
                "Cut",
                "item",
                "product",
                "cut",
                "Name",
            ]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        name = str(val).strip()
                        # Clean up "retail price" suffix from Data_Item
                        name = re.sub(
                            r"\s+retail price$", "", name, flags=re.IGNORECASE
                        )
                        break

            if not name:
                continue

            # Extract price from Value column
            price_per_lb = None
            for col in ["Value", "Retail", "Retail_price", "Price", "price", "retail"]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        try:
                            price_per_lb = Decimal(
                                str(val).replace("$", "").replace(",", "").strip()
                            )
                            break
                        except (ValueError, InvalidOperation):
                            continue

            if not price_per_lb or price_per_lb <= 0:
                continue

            # Extract year
            year = source_year or 2024
            for col in ["Year", "year"]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        try:
                            year = int(str(val)[:4])
                            break
                        except ValueError:
                            continue

            # Group prices by item name
            if name not in item_prices:
                item_prices[name] = []
            item_prices[name].append((year, price_per_lb))

        # Now yield one entry per unique item with averaged price
        items_yielded = 0
        for name, year_prices in item_prices.items():
            # Use most recent year's average price
            max_year = max(yp[0] for yp in year_prices)
            recent_prices = [p for y, p in year_prices if y == max_year]

            if not recent_prices:
                continue

            avg_price_per_lb = sum(recent_prices) / Decimal(len(recent_prices))

            # Convert $/lb to $/100g
            price_per_100g = (
                avg_price_per_lb * GRAMS_PER_100G / GRAMS_PER_POUND
            ).quantize(Decimal("0.0001"))

            items_yielded += 1
            yield IngredientPricing(
                name=name,
                price_per_100g=price_per_100g,
                data_source="USDA_MEAT",
                source_year=max_year,
                notes=f"Avg of {len(recent_prices)} monthly prices",
            )

        logger.info(f"Processed {len(df)} rows, yielded {items_yielded} unique items")

    except Exception as e:
        logger.error(f"Error parsing USDA Meat data: {e}")
        raise


def parse_kaggle_grocery_data(
    csv_path: Path,
) -> Iterator[IngredientPricing]:
    """Parse Kaggle grocery dataset as fallback for missing ingredients.

    Args:
        csv_path: Path to Kaggle grocery CSV

    Yields:
        IngredientPricing objects for grocery items
    """
    logger.info(f"Parsing Kaggle grocery data from {csv_path}")

    try:
        df = pd.read_csv(csv_path)
        logger.info(f"Loaded {len(df)} rows")
        logger.info(f"Columns: {list(df.columns)}")

        rows_processed = 0
        items_yielded = 0

        for _, row in df.iterrows():
            rows_processed += 1

            # Extract item name
            name = None
            for col in [
                "Product",
                "Name",
                "Item",
                "product",
                "name",
                "item",
                "product_name",
            ]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        name = str(val).strip()
                        break

            if not name:
                continue

            # Extract price - dataset structure varies
            price = None
            for col in ["Price", "price", "cost", "Cost", "unit_price", "UnitPrice"]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        try:
                            price = Decimal(
                                str(val).replace("$", "").replace(",", "").strip()
                            )
                            break
                        except (ValueError, InvalidOperation):
                            continue

            if not price or price <= 0:
                continue

            # Extract weight/quantity for conversion to per-100g
            weight_g = None
            for col in ["Weight", "weight", "Size", "size", "Quantity", "quantity"]:
                if col in df.columns:
                    val = row.get(col)
                    if val is not None and pd.notna(val):
                        try:
                            weight_str = str(val).lower()
                            # Try to extract grams
                            match = re.search(
                                r"(\d+(?:\.\d+)?)\s*g(?:rams?)?", weight_str
                            )
                            if match:
                                weight_g = Decimal(match.group(1))
                            # Try kg
                            match = re.search(r"(\d+(?:\.\d+)?)\s*kg", weight_str)
                            if match:
                                weight_g = Decimal(match.group(1)) * 1000
                            # Try oz
                            match = re.search(r"(\d+(?:\.\d+)?)\s*oz", weight_str)
                            if match:
                                weight_g = Decimal(match.group(1)) * Decimal("28.3495")
                            # Try lb
                            match = re.search(r"(\d+(?:\.\d+)?)\s*lb", weight_str)
                            if match:
                                weight_g = Decimal(match.group(1)) * GRAMS_PER_POUND
                            if weight_g:
                                break
                        except (ValueError, InvalidOperation):
                            continue

            # If no weight found, assume per-item pricing and skip
            # (or use average item weight - 200g fallback)
            if not weight_g:
                weight_g = Decimal("200")  # Rough average item weight

            # Convert to per-100g
            price_per_100g = (price / weight_g * GRAMS_PER_100G).quantize(
                Decimal("0.0001")
            )

            items_yielded += 1
            yield IngredientPricing(
                name=name,
                price_per_100g=price_per_100g,
                data_source="KAGGLE",
                source_year=None,
                notes="Fallback pricing",
            )

        logger.info(f"Processed {rows_processed} rows, yielded {items_yielded} items")

    except Exception as e:
        logger.error(f"Error parsing Kaggle data: {e}")
        raise


def fuzzy_match_ingredient(
    cursor,
    name: str,
    similarity_threshold: float = 0.3,
) -> int | None:
    """Find ingredient_id by fuzzy matching name using pg_trgm.

    Args:
        cursor: Database cursor
        name: Item name to match
        similarity_threshold: Minimum similarity score (0-1)

    Returns:
        ingredient_id if match found, None otherwise
    """
    cursor.execute(
        """
        SELECT ingredient_id, name, similarity(name, %s) AS sim
        FROM recipe_manager.ingredients
        WHERE similarity(name, %s) > %s
        ORDER BY sim DESC
        LIMIT 1
        """,
        (name, name, similarity_threshold),
    )
    result = cursor.fetchone()
    if result:
        logger.debug(f"Matched '{name}' to '{result[1]}' (sim={result[2]:.2f})")
        return result[0]
    return None
