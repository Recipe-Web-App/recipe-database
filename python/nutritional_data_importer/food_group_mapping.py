# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""USDA food category to food_group_enum mapping.

Maps USDA FoodData Central food_category_id values to our food_group_enum.
"""

# USDA food_category_id -> food_group_enum mapping
USDA_TO_FOOD_GROUP: dict[int, str] = {
    1: "DAIRY",  # Dairy and Egg Products
    2: "SPICES_HERBS",  # Spices and Herbs
    3: "PROCESSED_FOODS",  # Baby Foods
    4: "PROCESSED_FOODS",  # Fats and Oils
    5: "POULTRY",  # Poultry Products
    6: "PROCESSED_FOODS",  # Soups, Sauces, and Gravies
    7: "PROCESSED_FOODS",  # Sausages and Luncheon Meats
    8: "GRAINS",  # Breakfast Cereals
    9: "FRUITS",  # Fruits and Fruit Juices
    10: "MEAT",  # Pork Products
    11: "VEGETABLES",  # Vegetables and Vegetable Products
    12: "NUTS_SEEDS",  # Nut and Seed Products
    13: "MEAT",  # Beef Products
    14: "BEVERAGES",  # Beverages
    15: "SEAFOOD",  # Finfish and Shellfish Products
    16: "LEGUMES",  # Legumes and Legume Products
    17: "MEAT",  # Lamb, Veal, and Game Products
    18: "PROCESSED_FOODS",  # Baked Products
    19: "PROCESSED_FOODS",  # Sweets
    20: "GRAINS",  # Cereal Grains and Pasta
    21: "PROCESSED_FOODS",  # Fast Foods
    22: "PROCESSED_FOODS",  # Meals, Entrees, and Side Dishes
    23: "PROCESSED_FOODS",  # Snacks
    24: "PROCESSED_FOODS",  # American Indian/Alaska Native Foods
    25: "PROCESSED_FOODS",  # Restaurant Foods
    26: "PROCESSED_FOODS",  # Branded Food Products Database
    27: "UNKNOWN",  # Quality Control Materials
    28: "BEVERAGES",  # Alcoholic Beverages
}


def get_food_group(category_id: int | None) -> str:
    """Map USDA food_category_id to our food_group_enum.

    Args:
        category_id: USDA food_category_id value

    Returns:
        food_group_enum value, defaults to 'UNKNOWN' if category_id
        is None or not in mapping.
    """
    if category_id is None:
        return "UNKNOWN"
    return USDA_TO_FOOD_GROUP.get(category_id, "UNKNOWN")
