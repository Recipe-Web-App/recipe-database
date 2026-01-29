-- db/init/schema/046_create_vitamins_table.sql
-- Vitamin data linked to nutrition profiles
-- One-to-one relationship with nutrition_profiles table
-- All values stored in micrograms (mcg) for precision

CREATE TABLE IF NOT EXISTS recipe_manager.vitamins (
  vitamin_id BIGSERIAL PRIMARY KEY,
  nutrition_profile_id BIGINT NOT NULL UNIQUE
    REFERENCES recipe_manager.nutrition_profiles (nutrition_profile_id) ON DELETE CASCADE,
  vitamin_a_mcg DECIMAL(10, 3),
  vitamin_b6_mcg DECIMAL(10, 3),
  vitamin_b12_mcg DECIMAL(10, 3),
  vitamin_c_mcg DECIMAL(10, 3),
  vitamin_d_mcg DECIMAL(10, 3),
  vitamin_e_mcg DECIMAL(10, 3),
  vitamin_k_mcg DECIMAL(10, 3)
);

-- Index for profile lookups
CREATE INDEX IF NOT EXISTS idx_vitamins_profile_id
ON recipe_manager.vitamins (nutrition_profile_id);

-- Documentation
COMMENT ON TABLE recipe_manager.vitamins
IS 'Vitamin values per reference serving size, all stored in micrograms (mcg)';

COMMENT ON COLUMN recipe_manager.vitamins.vitamin_a_mcg
IS 'Vitamin A (RAE) in micrograms (USDA nutrient ID 1106)';
COMMENT ON COLUMN recipe_manager.vitamins.vitamin_b6_mcg
IS 'Vitamin B-6 in micrograms (USDA nutrient ID 1175, converted from mg)';
COMMENT ON COLUMN recipe_manager.vitamins.vitamin_b12_mcg
IS 'Vitamin B-12 in micrograms (USDA nutrient ID 1178)';
COMMENT ON COLUMN recipe_manager.vitamins.vitamin_c_mcg
IS 'Vitamin C in micrograms (USDA nutrient ID 1162, converted from mg)';
COMMENT ON COLUMN recipe_manager.vitamins.vitamin_d_mcg
IS 'Vitamin D (D2 + D3) in micrograms (USDA nutrient ID 1114)';
COMMENT ON COLUMN recipe_manager.vitamins.vitamin_e_mcg
IS 'Vitamin E (alpha-tocopherol) in micrograms (USDA nutrient ID 1109, converted from mg)';
COMMENT ON COLUMN recipe_manager.vitamins.vitamin_k_mcg
IS 'Vitamin K (phylloquinone) in micrograms (USDA nutrient ID 1185)';
