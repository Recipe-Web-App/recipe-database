-- db/init/schema/045_create_macronutrients_table.sql
-- Macronutrient data linked to nutrition profiles
-- One-to-one relationship with nutrition_profiles table

CREATE TABLE IF NOT EXISTS recipe_manager.macronutrients (
  macronutrient_id BIGSERIAL PRIMARY KEY,
  nutrition_profile_id BIGINT NOT NULL UNIQUE
    REFERENCES recipe_manager.nutrition_profiles (nutrition_profile_id) ON DELETE CASCADE,
  calories_kcal DECIMAL(10, 3),
  protein_g DECIMAL(10, 3),
  carbs_g DECIMAL(10, 3),
  fat_g DECIMAL(10, 3),
  saturated_fat_g DECIMAL(10, 3),
  trans_fat_g DECIMAL(10, 3),
  monounsaturated_fat_g DECIMAL(10, 3),
  polyunsaturated_fat_g DECIMAL(10, 3),
  cholesterol_mg DECIMAL(10, 3),
  sodium_mg DECIMAL(10, 3),
  fiber_g DECIMAL(10, 3),
  sugar_g DECIMAL(10, 3),
  added_sugar_g DECIMAL(10, 3)
);

-- Index for profile lookups
CREATE INDEX IF NOT EXISTS idx_macronutrients_profile_id
ON recipe_manager.macronutrients (nutrition_profile_id);

-- Documentation
COMMENT ON TABLE recipe_manager.macronutrients
IS 'Macronutrient values per reference serving size from nutrition profile';

COMMENT ON COLUMN recipe_manager.macronutrients.calories_kcal
IS 'Energy in kilocalories (USDA nutrient ID 1008)';
COMMENT ON COLUMN recipe_manager.macronutrients.protein_g
IS 'Protein in grams (USDA nutrient ID 1003)';
COMMENT ON COLUMN recipe_manager.macronutrients.carbs_g
IS 'Carbohydrates by difference in grams (USDA nutrient ID 1005)';
COMMENT ON COLUMN recipe_manager.macronutrients.fat_g
IS 'Total lipid (fat) in grams (USDA nutrient ID 1004)';
COMMENT ON COLUMN recipe_manager.macronutrients.saturated_fat_g
IS 'Saturated fatty acids in grams (USDA nutrient ID 1258)';
COMMENT ON COLUMN recipe_manager.macronutrients.trans_fat_g
IS 'Trans fatty acids in grams (USDA nutrient ID 1257)';
COMMENT ON COLUMN recipe_manager.macronutrients.monounsaturated_fat_g
IS 'Monounsaturated fatty acids in grams (USDA nutrient ID 1292)';
COMMENT ON COLUMN recipe_manager.macronutrients.polyunsaturated_fat_g
IS 'Polyunsaturated fatty acids in grams (USDA nutrient ID 1293)';
COMMENT ON COLUMN recipe_manager.macronutrients.cholesterol_mg
IS 'Cholesterol in milligrams (USDA nutrient ID 1253)';
COMMENT ON COLUMN recipe_manager.macronutrients.sodium_mg
IS 'Sodium in milligrams (USDA nutrient ID 1093)';
COMMENT ON COLUMN recipe_manager.macronutrients.fiber_g
IS 'Total dietary fiber in grams (USDA nutrient ID 1079)';
COMMENT ON COLUMN recipe_manager.macronutrients.sugar_g
IS 'Total sugars including NLEA in grams (USDA nutrient ID 2000)';
COMMENT ON COLUMN recipe_manager.macronutrients.added_sugar_g
IS 'Added sugars in grams (USDA nutrient ID 1235)';
