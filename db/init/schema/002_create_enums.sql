-- db/init/schema/002_create_enums.sql
-- Enum for ingredient units
DO $$ BEGIN CREATE TYPE recipe_manager.ingredient_unit_enum AS ENUM (
  'G', 'KG', 'OZ', 'LB', 'ML', 'L', 'CUP', 'TBSP', 'TSP', 'PIECE',
  'CLOVE', 'SLICE', 'PINCH', 'CAN', 'BOTTLE', 'PACKET', 'UNIT'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for meal types
DO $$ BEGIN CREATE TYPE recipe_manager.meal_type_enum
  AS ENUM ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'DESSERT');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for recipe revision categories
DO $$ BEGIN CREATE TYPE recipe_manager.revision_category_enum
  as ENUM ('INGREDIENT', 'STEP');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for recipe revision types
DO $$ BEGIN CREATE TYPE recipe_manager.revision_type_enum
  AS ENUM ('ADD', 'UPDATE', 'DELETE');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for recipe difficulty levels
DO $$ BEGIN CREATE TYPE recipe_manager.difficulty_level_enum
  AS ENUM ('BEGINNER', 'EASY', 'MEDIUM', 'HARD', 'EXPERT');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for allergens
DO $$ BEGIN CREATE TYPE recipe_manager.allergen_enum AS ENUM (
  -- FDA Major Allergens (Top 9)
  'MILK', 'EGGS', 'FISH', 'SHELLFISH', 'TREE_NUTS', 'PEANUTS',
  'WHEAT', 'SOYBEANS', 'SESAME',
  -- Additional EU Major Allergens
  'CELERY', 'MUSTARD', 'LUPIN', 'SULPHITES',
  -- Tree Nut Specifics
  'ALMONDS', 'CASHEWS', 'HAZELNUTS', 'WALNUTS',
  -- Common Additional Allergens
  'GLUTEN', 'COCONUT', 'CORN', 'YEAST', 'GELATIN', 'KIWI',
  -- Reiligious/Dietary
  'PORK', 'BEEF', 'ALCOHOL',
  -- Additives/Chemicals
  'SULFUR_DIOXIDE', 'PHENYLALANINE',
  -- Other
  'NONE', 'UNKNOWN'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
