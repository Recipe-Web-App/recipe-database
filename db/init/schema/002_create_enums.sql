-- db/init/schema/002_create_enums.sql
-- Enum for ingredient units
DO $$ BEGIN CREATE TYPE recipe_manager.unit_enum AS ENUM (
  'g',
  'kg',
  'oz',
  'lb',
  'ml',
  'l',
  'cup',
  'tbsp',
  'tsp',
  'piece',
  'clove',
  'slice',
  'pinch',
  'can',
  'bottle',
  'packet'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for meal types
DO $$ BEGIN CREATE TYPE recipe_manager.meal_type_enum AS ENUM ('breakfast', 'lunch', 'dinner', 'snack');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for recipe revision categories
DO $$ BEGIN CREATE TYPE recipe_manager.revision_category_enum as ENUM ('ingredient', 'step');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for recipe revision types
DO $$ BEGIN CREATE TYPE recipe_manager.revision_type_enum AS ENUM ('added', 'modified', 'removed');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
