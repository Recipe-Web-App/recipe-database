"""
Data cleaning utilities for OpenFoodFacts data import.
"""

import logging
import pandas as pd

logger = logging.getLogger(__name__)


def clean_numeric_value(value, column_name=None):
    """Clean and convert a value to a numeric type, handling various formats and database precision limits."""
    if pd.isna(value) or value == '' or value is None:
        return None
    
    try:
        # Convert to string and strip whitespace
        str_val = str(value).strip()
        
        # Handle empty strings
        if not str_val or str_val.lower() == 'nan':
            return None
            
        # Try to convert to float
        numeric_val = float(str_val)
        
        # Handle infinite or NaN values
        if not (numeric_val == numeric_val and abs(numeric_val) != float('inf')):
            return None
        
        # Apply database precision limits based on column type
        if column_name:
            # Vitamins and minerals: DECIMAL(10,6) - max value 9999.999999
            vitamin_mineral_columns = [
                'vitamin-a_100g', 'vitamin-b6_100g', 'vitamin-b12_100g', 
                'vitamin-c_100g', 'vitamin-d_100g', 'vitamin-e_100g', 'vitamin-k_100g',
                'calcium_100g', 'iron_100g', 'magnesium_100g', 'potassium_100g', 
                'sodium_100g', 'zinc_100g'
            ]
            
            if column_name in vitamin_mineral_columns:
                if abs(numeric_val) >= 10000:  # Precision limit for DECIMAL(10,6)
                    logger.debug(f"Value {numeric_val} for {column_name} exceeds DECIMAL(10,6) limit, setting to NULL")
                    return None
                    
            # Macro-nutrients: DECIMAL(8,3) - max value 99999.999  
            elif column_name.endswith('_100g') or column_name == 'nutriscore_score':
                if abs(numeric_val) >= 100000:  # Precision limit for DECIMAL(8,3)
                    logger.debug(f"Value {numeric_val} for {column_name} exceeds DECIMAL(8,3) limit, setting to NULL")
                    return None
        
        # General sanity check for extremely large values
        if abs(numeric_val) >= 1e6:  # 1 million - likely data error
            return None
            
        return numeric_val
        
    except (ValueError, TypeError):
        return None


def clean_nutriscore_grade(value):
    """Clean and validate nutriscore_grade values."""
    if pd.isna(value) or value == '' or value is None:
        return None
    
    try:
        # Convert to string and clean
        str_val = str(value).strip().lower()
        
        # Handle empty strings
        if not str_val or str_val.lower() == 'nan':
            return None
        
        # Valid nutriscore grades are a, b, c, d, e
        if str_val in ['a', 'b', 'c', 'd', 'e']:
            return str_val
        
        # Handle some common variations/errors
        if str_val.startswith('a'):
            return 'a'
        elif str_val.startswith('b'):
            return 'b'
        elif str_val.startswith('c'):
            return 'c'
        elif str_val.startswith('d'):
            return 'd'
        elif str_val.startswith('e'):
            return 'e'
        
        # If we can't parse it, log and return None
        logger.debug(f"Invalid nutriscore_grade value: '{value}', setting to NULL")
        return None
        
    except (ValueError, TypeError):
        return None
