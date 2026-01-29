-- db/init/schema/007_create_ingredients_table.sql
-- Ingredients catalog with optional USDA FoodData Central linkage
CREATE TABLE IF NOT EXISTS recipe_manager.ingredients (
  ingredient_id BIGSERIAL PRIMARY KEY,
  "name" VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  is_optional BOOLEAN DEFAULT FALSE,
  fdc_id BIGINT,
  usda_food_description VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for USDA FoodData Central lookups
CREATE INDEX IF NOT EXISTS idx_ingredients_fdc_id
ON recipe_manager.ingredients (fdc_id)
WHERE fdc_id IS NOT NULL;

COMMENT ON COLUMN recipe_manager.ingredients.fdc_id
IS 'USDA FoodData Central ID for nutritional data linkage';
COMMENT ON COLUMN recipe_manager.ingredients.usda_food_description
IS 'Original food description from USDA FoodData Central';
