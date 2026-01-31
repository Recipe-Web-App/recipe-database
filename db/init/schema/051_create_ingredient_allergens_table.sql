-- db/init/schema/051_create_ingredient_allergens_table.sql
-- Individual allergen entries linked to allergen profiles
-- Many-to-one relationship with allergen_profiles table

CREATE TABLE IF NOT EXISTS recipe_manager.ingredient_allergens (
  ingredient_allergen_id BIGSERIAL PRIMARY KEY,
  allergen_profile_id BIGINT NOT NULL
    REFERENCES recipe_manager.allergen_profiles (allergen_profile_id) ON DELETE CASCADE,
  allergen_type recipe_manager.ALLERGEN_ENUM NOT NULL,
  presence_type recipe_manager.PRESENCE_TYPE_ENUM NOT NULL DEFAULT 'CONTAINS',
  confidence_score DECIMAL(3, 2)
    CHECK (confidence_score >= 0 AND confidence_score <= 1),
  source_notes TEXT,

  -- Prevent duplicate allergen entries per profile
  UNIQUE (allergen_profile_id, allergen_type)
);

-- Index for profile lookups
CREATE INDEX IF NOT EXISTS idx_ingredient_allergens_profile_id
ON recipe_manager.ingredient_allergens (allergen_profile_id);

-- Index for allergen type queries (useful for "find all ingredients with PEANUTS")
CREATE INDEX IF NOT EXISTS idx_ingredient_allergens_type
ON recipe_manager.ingredient_allergens (allergen_type);

-- Documentation
COMMENT ON TABLE recipe_manager.ingredient_allergens
IS 'Individual allergen entries for each ingredient allergen profile';

COMMENT ON COLUMN recipe_manager.ingredient_allergens.allergen_type
IS 'Specific allergen from allergen_enum (e.g., MILK, EGGS, PEANUTS)';
COMMENT ON COLUMN recipe_manager.ingredient_allergens.presence_type
IS 'How the allergen is present: CONTAINS (definite), MAY_CONTAIN (possible), TRACES (minimal)';
COMMENT ON COLUMN recipe_manager.ingredient_allergens.confidence_score
IS 'Per-allergen confidence score (0.0-1.0), may differ from profile confidence';
COMMENT ON COLUMN recipe_manager.ingredient_allergens.source_notes
IS 'Additional context about allergen source or detection method';
