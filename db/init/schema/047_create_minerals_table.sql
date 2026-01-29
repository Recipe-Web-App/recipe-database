-- db/init/schema/047_create_minerals_table.sql
-- Mineral data linked to nutrition profiles
-- One-to-one relationship with nutrition_profiles table
-- All values stored in milligrams (mg)

CREATE TABLE IF NOT EXISTS recipe_manager.minerals (
  mineral_id BIGSERIAL PRIMARY KEY,
  nutrition_profile_id BIGINT NOT NULL UNIQUE
    REFERENCES recipe_manager.nutrition_profiles (nutrition_profile_id) ON DELETE CASCADE,
  calcium_mg DECIMAL(10, 3),
  iron_mg DECIMAL(10, 3),
  magnesium_mg DECIMAL(10, 3),
  potassium_mg DECIMAL(10, 3),
  zinc_mg DECIMAL(10, 3)
);

-- Index for profile lookups
CREATE INDEX IF NOT EXISTS idx_minerals_profile_id
ON recipe_manager.minerals (nutrition_profile_id);

-- Documentation
COMMENT ON TABLE recipe_manager.minerals
IS 'Mineral values per reference serving size, all stored in milligrams (mg)';

COMMENT ON COLUMN recipe_manager.minerals.calcium_mg
IS 'Calcium in milligrams (USDA nutrient ID 1087)';
COMMENT ON COLUMN recipe_manager.minerals.iron_mg
IS 'Iron in milligrams (USDA nutrient ID 1089)';
COMMENT ON COLUMN recipe_manager.minerals.magnesium_mg
IS 'Magnesium in milligrams (USDA nutrient ID 1090)';
COMMENT ON COLUMN recipe_manager.minerals.potassium_mg
IS 'Potassium in milligrams (USDA nutrient ID 1092)';
COMMENT ON COLUMN recipe_manager.minerals.zinc_mg
IS 'Zinc in milligrams (USDA nutrient ID 1095)';
