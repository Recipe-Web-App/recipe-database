# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Allergen mapping for OpenFoodFacts data import."""

import pandas as pd


def map_allergens_to_enum(allergen_string):
    """Map raw allergen string from CSV to standardized enum values."""
    if pd.isna(allergen_string) or not allergen_string or allergen_string.strip() == "":
        return []

    # Define comprehensive mapping from CSV values to enum values
    allergen_mapping = {
        # Milk and dairy (various languages and formats)
        "MILK": [
            "milk",
            "milch",
            "lait",
            "leite",
            "mleko",
            "latte",
            "mléko",
            "mjölk",
            "kuhmilch",
            "cow milk",
            "cow's milk",
            "dairy",
            "dairy products",
            "milk products",
            "milk derivatives",
            "milkfat",
            "butter",
            "butterfat",
            "cream",
            "cheese",
            "whey",
            "casein",
            "lactose",
            "yogurt",
            "yoghurt",
            "cheddar",
            "mozzarella",
            "emmental",
            "milk protein",
            "milk solids",
            "cultured milk",
            "pasteurized milk",
            "nonfat milk",
            "whole milk",
            "milchprodukte",
            "milchbestandteile",
            "milcheiweiß",
            "milcheiweiss",
        ],
        # Eggs (various languages)
        "EGGS": [
            "eggs",
            "egg",
            "eier",
            "ovo",
            "uova",
            "jajka",
            "eieren",
            "œuf",
            "hühnerei",
            "egg white",
            "egg powder",
            "eigelb",
            "albumin",
        ],
        # Wheat and gluten
        "WHEAT": [
            "wheat",
            "weizen",
            "blé",
            "trigo",
            "wheat flour",
            "wheat gluten",
            "weizenmehl",
            "wheat starch",
            "wheat derivatives",
            "durum wheat",
            "wheat protein",
            "weizenprotein",
            "hartweizengrieß",
        ],
        "GLUTEN": [
            "gluten",
            "glutenhaltiges getreide",
            "cereals containing gluten",
            "céréales contenant du gluten",
            "gluten-containing cereals",
        ],
        # Soybeans
        "SOYBEANS": [
            "soy",
            "soja",
            "soya",
            "soybeans",
            "sojabohnen",
            "soybean",
            "soy protein",
            "soy lecithin",
            "sojaprotein",
            "sojaöl",
        ],
        # Tree nuts (general and specific)
        "TREE_NUTS": [
            "tree nuts",
            "nuts",
            "nüsse",
            "noix",
            "fruits à coque",
            "frutta a guscio",
            "tree nut",
            "nut allergy",
        ],
        "ALMONDS": [
            "almonds",
            "almond",
            "mandeln",
            "amandes",
            "mandorle",
            "almendras",
            "almond butter",
            "almond flour",
            "almond milk",
        ],
        "CASHEWS": ["cashews", "cashew", "cashew nuts", "cashew-nüsse", "cashewkeme"],
        "HAZELNUTS": ["hazelnuts", "hazelnut", "haselnüsse", "haselnuss", "hazlenut"],
        "WALNUTS": ["walnuts", "walnut", "walnüsse", "wallnuts", "black walnuts"],
        # Peanuts
        "PEANUTS": [
            "peanuts",
            "peanut",
            "erdnüsse",
            "arachides",
            "pinda",
            "peanut butter",
            "peanut oil",
            "groundnuts",
        ],
        # Fish and seafood
        "FISH": [
            "fish",
            "fisch",
            "poisson",
            "pescado",
            "pesce",
            "vis",
            "anchovy",
            "anchovies",
            "sardines",
            "tuna",
            "salmon",
            "hoki",
            "pollock",
            "bonito",
            "herring",
            "flying fish",
        ],
        "SHELLFISH": [
            "shellfish",
            "crustacean",
            "shrimp",
            "prawns",
            "crab",
            "lobster",
            "crayfish",
            "garnelen",
            "molluscs",
            "mollusks",
            "oyster",
            "mussel",
            "clam",
            "scallop",
        ],
        # Sesame
        "SESAME": [
            "sesame",
            "sesame seeds",
            "sésame",
            "sesamsaat",
            "graines de sésame",
            "white sesame seeds",
        ],
        # Mustard
        "MUSTARD": [
            "mustard",
            "senf",
            "moutarde",
            "mustard seed",
            "mustard seeds",
            "gelbsenfsaat",
            "braunsenfsaat",
        ],
        # Celery
        "CELERY": [
            "celery",
            "sellerie",
            "céleri",
            "celery powder",
            "schnittselerie",
            "schnittsellerie",
        ],
        # Sulphites
        "SULPHITES": [
            "sulphites",
            "sulfites",
            "sulfit",
            "sulfur dioxide",
            "metabisulphite",
            "sodium metabisulphite",
            "kaliummetabisulfit",
            "ammoniumsulfit",
            "natriummetabisulfit",
        ],
        # Coconut
        "COCONUT": ["coconut", "coconuts", "noix de coco", "coconut oil"],
        # Alcohol
        "ALCOHOL": ["alcohol", "alkohol", "ethanol"],
        # Phenylalanine
        "PHENYLALANINE": [
            "phenylalanine",
            "phenylalalnine",
            "phenilananin",
            "phenylalaninquelle",
        ],
        "LUPIN": ["lupin", "lupine", "lupins"],
        "CORN": [
            "corn",
            "maize",
            "mais",
            "corn starch",
            "corn flour",
            "yellow corn",
            "sweet corn",
        ],
        "YEAST": ["yeast", "hefe", "levure", "baker yeast", "nutritional yeast"],
        "GELATIN": ["gelatin", "gelatine", "beef gelatin", "pork gelatin"],
        "KIWI": ["kiwi", "kiwi fruit"],
        # Religious/Dietary
        "PORK": [
            "pork",
            "schwein",
            "porc",
            "pig",
            "ham",
            "bacon",
            "pork gelatin",
            "lard",
        ],
        "BEEF": ["beef", "rind", "bœuf", "cow", "cattle", "beef gelatin"],
        # Additives/Chemicals
        "SULFUR_DIOXIDE": ["sulfur dioxide", "sulphur dioxide", "so2", "e220"],
    }

    # Split allergen string by common delimiters
    allergen_parts = []
    for delimiter in [",", ";", "|", "/", "+", "&", " and ", " et ", " und "]:
        if delimiter in allergen_string:
            allergen_parts = allergen_string.split(delimiter)
            break

    if not allergen_parts:
        allergen_parts = [allergen_string]

    # Clean and normalize each part
    found_allergens = set()

    for part in allergen_parts:
        # Clean the part
        clean_part = part.strip().lower()

        # Remove common prefixes
        for prefix in [
            "en:",
            "de:",
            "fr:",
            "es:",
            "it:",
            "contains:",
            "contains ",
            "enthält",
        ]:
            if clean_part.startswith(prefix):
                clean_part = clean_part[len(prefix) :].strip()

        # Skip empty or very short parts
        if len(clean_part) < 3:
            continue

        # Skip obvious non-allergens
        skip_terms = [
            "none",
            "nil",
            "n/a",
            "no known allergens",
            "keine",
            "warning",
            "may contain",
            "traces",
            "produced in",
            "manufactured on",
            "water",
            "salt",
            "sugar",
        ]
        if any(skip in clean_part for skip in skip_terms):
            continue

        # Find matching allergens
        for enum_value, patterns in allergen_mapping.items():
            for pattern in patterns:
                if pattern.lower() in clean_part or clean_part in pattern.lower():
                    found_allergens.add(enum_value)
                    break

    return list(found_allergens)
