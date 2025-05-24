-- db/init/schema/001_create_schema.sql
-- Create the main schema
CREATE SCHEMA IF NOT EXISTS recipe_manager;
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
