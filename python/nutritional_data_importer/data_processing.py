"""
Data processing utilities for OpenFoodFacts data import.
"""

import logging
import pandas as pd
from data_cleaning import clean_numeric_value, clean_nutriscore_grade, parse_serving_size
from allergen_mapping import map_allergens_to_enum
from food_groups_mapping import map_food_groups_to_enum

logger = logging.getLogger(__name__)

def prepare_row_data(row, csv_columns, target_columns):
    """Prepare a single row of data for database insertion."""
    row_data = []
    
    # Pre-parse serving info since it creates multiple target columns from one source
    parsed_quantity, parsed_unit = parse_serving_size(row.get('serving_size'))
    
    # Define which columns are numeric and need cleaning
    numeric_columns = [
        'nutriscore_score',
        'energy-kcal_100g', 'carbohydrates_100g', 'cholesterol_100g', 'proteins_100g',
        'sugars_100g', 'added-sugars_100g', 'fat_100g', 'saturated-fat_100g',
        'monounsaturated-fat_100g', 'polyunsaturated-fat_100g', 'omega-3-fat_100g',
        'omega-6-fat_100g', 'omega-9-fat_100g', 'trans-fat_100g', 'fiber_100g', 'soluble-fiber_100g',
        'insoluble-fiber_100g', 'vitamin-a_100g', 'vitamin-b6_100g', 'vitamin-b12_100g',
        'vitamin-c_100g', 'vitamin-d_100g', 'vitamin-e_100g', 'vitamin-k_100g',
        'calcium_100g', 'iron_100g', 'magnesium_100g', 'potassium_100g', 'sodium_100g', 'zinc_100g',
        'serving_quantity'
    ]
    
    for col in target_columns:
        # Handle derived columns from serving_size parsing
        if col == 'serving_quantity':
            value = clean_numeric_value(parsed_quantity, col)
        elif col == 'serving_measurement':
            value = parsed_unit
        elif col in csv_columns:
            value = row[col]
            
            # Handle allergens column specially - convert to enum array
            if col == 'allergens':
                allergen_enums = map_allergens_to_enum(value)
                # Convert to PostgreSQL array format
                if allergen_enums:
                    value = allergen_enums
                else:
                    value = None
            # Handle food_groups column specially - convert to enum
            elif col == 'food_groups':
                value = map_food_groups_to_enum(value)
            # Handle numeric columns with precision limits
            elif col in numeric_columns:
                value = clean_numeric_value(value, col)
            # Handle nutriscore_grade specifically
            elif col == 'nutriscore_grade':
                value = clean_nutriscore_grade(value)
            # Handle text columns
            elif value is not None and not pd.isna(value):
                value = str(value).strip()
                if not value:  # Empty string
                    value = None
            else:
                value = None
        else:
            # Column not in CSV, set to None
            value = None
                
        row_data.append(value)
    
    return row_data


def is_american_product(row):
    """Check if a product is from the United States."""
    try:
        # Check the countries field
        countries = row.get('countries', '')
        countries_tags = row.get('countries_tags', '')
        countries_en = row.get('countries_en', '')
        
        # List of potential American identifiers
        american_identifiers = [
            'united states', 'usa', 'us', 'united-states',
            'en:united-states', 'en:usa', 'en:us'
        ]
        
        # Check all country fields
        for field in [countries, countries_tags, countries_en]:
            if pd.isna(field):
                continue
            
            field_str = str(field).lower()
            
            # Check if any American identifier is in the field
            for identifier in american_identifiers:
                if identifier in field_str:
                    return True
        
        # If no American identifiers found, not an American product
        return False
        
    except Exception as e:
        # If there's an error, default to not American to be safe
        logger.debug(f"Error checking if product is American: {e}")
        return False

def should_update_field(existing_value, new_value, column_name):
    """Determine if a field should be updated based on merge logic."""
    # Don't update if new value is null/empty
    if new_value is None or new_value == '':
        return False
    
    # Always update if existing is null/empty
    if existing_value is None or existing_value == '':
        return True
    
    # For numeric nutrition fields, prefer non-zero values
    if column_name.endswith('_100g') or column_name == 'nutriscore_score':
        try:
            existing_num = float(existing_value) if existing_value is not None else 0
            new_num = float(new_value) if new_value is not None else 0
            
            # Update if existing is 0 and new is non-zero
            if existing_num == 0 and new_num > 0:
                return True
            
            # Don't update if we already have a good value
            return False
            
        except (ValueError, TypeError):
            return False
    
    # For text fields, prefer longer/more detailed content
    if column_name in ['brands', 'categories', 'allergens']:
        return len(str(new_value)) > len(str(existing_value))
    
    # Default: don't update (preserve first occurrence)
    return False
