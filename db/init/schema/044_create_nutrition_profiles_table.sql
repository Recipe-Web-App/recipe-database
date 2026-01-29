-- db/init/schema/044_create_nutrition_profiles_table.sql
-- Nutrition profile metadata linking ingredients to nutritional data
-- One-to-one relationship with ingredients table

CREATE TABLE IF NOT EXISTS recipe_manager.nutrition_profiles (
  nutrition_profile_id BIGSERIAL PRIMARY KEY,
  ingredient_id BIGINT NOT NULL UNIQUE
    REFERENCES recipe_manager.ingredients (ingredient_id) ON DELETE CASCADE,
  serving_size_g DECIMAL(10, 2) NOT NULL DEFAULT 100,
  data_source VARCHAR(50) NOT NULL DEFAULT 'USDA',
  fdc_data_type VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for ingredient lookups
CREATE INDEX IF NOT EXISTS idx_nutrition_profiles_ingredient_id
ON recipe_manager.nutrition_profiles (ingredient_id);

-- Documentation
COMMENT ON TABLE recipe_manager.nutrition_profiles
IS 'Nutrition profile metadata for ingredients, sourced from USDA FoodData Central';

COMMENT ON COLUMN recipe_manager.nutrition_profiles.ingredient_id
IS 'Foreign key to ingredients table (one-to-one relationship)';
COMMENT ON COLUMN recipe_manager.nutrition_profiles.serving_size_g
IS 'Reference serving size in grams (default 100g per USDA standard)';
COMMENT ON COLUMN recipe_manager.nutrition_profiles.data_source
IS 'Source of nutritional data (e.g., USDA, manual entry)';
COMMENT ON COLUMN recipe_manager.nutrition_profiles.fdc_data_type
IS 'USDA FDC data type (e.g., foundation_food, sr_legacy_food)';
