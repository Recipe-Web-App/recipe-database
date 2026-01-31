-- db/init/schema/050_create_allergen_profiles_table.sql
-- Allergen profile metadata linking ingredients to allergen data
-- One-to-one relationship with ingredients table

CREATE TABLE IF NOT EXISTS recipe_manager.allergen_profiles (
  allergen_profile_id BIGSERIAL PRIMARY KEY,
  ingredient_id BIGINT NOT NULL UNIQUE
    REFERENCES recipe_manager.ingredients (ingredient_id) ON DELETE CASCADE,
  data_source VARCHAR(50) NOT NULL DEFAULT 'MANUAL'
    CHECK (data_source IN ('USDA', 'OPEN_FOOD_FACTS', 'LLM_INFERRED', 'MANUAL')),
  confidence_score DECIMAL(3, 2)
    CHECK (confidence_score >= 0 AND confidence_score <= 1),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for ingredient lookups
CREATE INDEX IF NOT EXISTS idx_allergen_profiles_ingredient_id
ON recipe_manager.allergen_profiles (ingredient_id);

-- Documentation
COMMENT ON TABLE recipe_manager.allergen_profiles
IS 'Allergen profile metadata for ingredients, sourced from various data providers';

COMMENT ON COLUMN recipe_manager.allergen_profiles.ingredient_id
IS 'Foreign key to ingredients table (one-to-one relationship)';
COMMENT ON COLUMN recipe_manager.allergen_profiles.data_source
IS 'Source of allergen data (USDA, OPEN_FOOD_FACTS, LLM_INFERRED, MANUAL)';
COMMENT ON COLUMN recipe_manager.allergen_profiles.confidence_score
IS 'Overall confidence in allergen profile accuracy (0.0-1.0)';
