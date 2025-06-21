"""
Food groups mapping for OpenFoodFacts data import.
"""

import logging
import pandas as pd

logger = logging.getLogger(__name__)

def map_food_groups_to_enum(food_groups_value):
    """
    Map OpenFoodFacts food groups to our standardized food_group_enum.
    
    Args:
        food_groups_value: String containing food groups from OpenFoodFacts
        
    Returns:
        str: Mapped enum value or 'UNKNOWN' if no mapping found
    """
    if not food_groups_value or pd.isna(food_groups_value):
        return 'UNKNOWN'
    
    # Convert to lowercase for easier matching
    food_groups_lower = str(food_groups_value).lower()
    
    # Define mapping rules based on OpenFoodFacts taxonomy
    # Order matters - more specific matches should come first
    
    # Vegetables
    if any(keyword in food_groups_lower for keyword in [
        'en:vegetables', 'en:potatoes', 'en:fruits-and-vegetables'
    ]):
        return 'VEGETABLES'
    
    # Fruits
    if any(keyword in food_groups_lower for keyword in [
        'en:fruits', 'en:dried-fruits', 'en:fruit-juices', 'en:fruit-nectars'
    ]):
        return 'FRUITS'
    
    # Meat
    if any(keyword in food_groups_lower for keyword in [
        'en:meat-other-than-poultry', 'en:processed-meat', 'en:offals'
    ]):
        return 'MEAT'
    
    # Poultry
    if 'en:poultry' in food_groups_lower:
        return 'POULTRY'
    
    # Seafood
    if any(keyword in food_groups_lower for keyword in [
        'en:fish-and-seafood', 'en:fatty-fish', 'en:lean-fish', 'en:fish-meat-eggs'
    ]):
        return 'SEAFOOD'
    
    # Dairy
    if any(keyword in food_groups_lower for keyword in [
        'en:cheese', 'en:milk-and-yogurt', 'en:dairy-desserts', 'en:ice-cream', 'en:eggs'
    ]):
        return 'DAIRY'
    
    # Grains
    if any(keyword in food_groups_lower for keyword in [
        'en:cereals', 'en:bread', 'en:breakfast-cereals', 'en:cereals-and-potatoes', 'en:biscuits-and-cakes', 'en:pastries'
    ]):
        return 'GRAINS'
    
    # Legumes
    if 'en:legumes' in food_groups_lower:
        return 'LEGUMES'
    
    # Nuts and Seeds
    if 'en:nuts' in food_groups_lower:
        return 'NUTS_SEEDS'
    
    # Beverages
    if any(keyword in food_groups_lower for keyword in [
        'en:unsweetened-beverages', 'en:sweetened-beverages', 'en:artificially-sweetened-beverages',
        'en:plant-based-milk-substitutes', 'en:alcoholic-beverages', 'en:teas-and-herbal-teas-and-coffees',
        'en:waters-and-flavored-waters'
    ]):
        return 'BEVERAGES'
    
    # Processed Foods (catch-all for manufactured/processed items)
    if any(keyword in food_groups_lower for keyword in [
        'en:sweets', 'en:dressings-and-sauces', 'en:one-dish-meals', 'en:appetizers',
        'en:sandwiches', 'en:pizza-pies-and-quiches', 'en:fats', 'en:chocolate-products',
        'en:salty-and-fatty-products', 'en:soups'
    ]):
        return 'PROCESSED_FOODS'
    
    # Default fallback
    logger.debug(f"No mapping found for food group: {food_groups_value}")
    return 'UNKNOWN'