-- db/init/schema/048_create_ingredient_portions_table.sql
-- Ingredient portion weights for volume/count to gram conversions
-- Data sourced from USDA FoodData Central food_portion.csv

CREATE TABLE IF NOT EXISTS recipe_manager.ingredient_portions (
    id BIGSERIAL PRIMARY KEY,
    ingredient_id BIGINT NOT NULL
        REFERENCES recipe_manager.ingredients (ingredient_id) ON DELETE CASCADE,
    portion_description VARCHAR(255) NOT NULL,
    unit recipe_manager.INGREDIENT_UNIT_ENUM NOT NULL,
    modifier VARCHAR(100),
    gram_weight DECIMAL(10, 3) NOT NULL,
    sequence_number INT,
    data_source VARCHAR(50) DEFAULT 'USDA',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (ingredient_id, portion_description)
);

-- Indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_ingredient_portions_ingredient_id
    ON recipe_manager.ingredient_portions (ingredient_id);

CREATE INDEX IF NOT EXISTS idx_ingredient_portions_unit
    ON recipe_manager.ingredient_portions (unit);

CREATE INDEX IF NOT EXISTS idx_ingredient_portions_ingredient_unit
    ON recipe_manager.ingredient_portions (ingredient_id, unit);

COMMENT ON TABLE recipe_manager.ingredient_portions IS
    'Portion weights for ingredients enabling volume/count to gram conversions';

COMMENT ON COLUMN recipe_manager.ingredient_portions.portion_description IS
    'Full USDA portion description (e.g., "1 cup, chopped")';

COMMENT ON COLUMN recipe_manager.ingredient_portions.unit IS
    'Normalized unit type matching IngredientUnit enum (CUP, TBSP, PIECE, etc.)';

COMMENT ON COLUMN recipe_manager.ingredient_portions.modifier IS
    'Optional modifier extracted from description (e.g., "chopped", "medium")';

COMMENT ON COLUMN recipe_manager.ingredient_portions.gram_weight IS
    'Weight in grams for one unit of this portion';

COMMENT ON COLUMN recipe_manager.ingredient_portions.sequence_number IS
    'USDA sequence number for ordering multiple portions of same ingredient';
