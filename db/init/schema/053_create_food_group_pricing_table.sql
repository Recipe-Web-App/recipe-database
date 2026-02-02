-- db/init/schema/053_create_food_group_pricing_table.sql
-- Fallback pricing by food group when ingredient-specific price unavailable
-- Reference table with one row per food group from FOOD_GROUP_ENUM

CREATE TABLE IF NOT EXISTS recipe_manager.food_group_pricing (
  food_group recipe_manager.FOOD_GROUP_ENUM PRIMARY KEY,
  avg_price_per_100g DECIMAL(10, 4) NOT NULL
    CHECK (avg_price_per_100g >= 0),
  currency VARCHAR(3) NOT NULL DEFAULT 'USD',
  data_source VARCHAR(50) NOT NULL DEFAULT 'USDA_FMAP'
    CHECK (data_source IN ('USDA_FVP', 'USDA_MEAT', 'USDA_FMAP', 'KAGGLE', 'MANUAL')),
  notes TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Documentation
COMMENT ON TABLE recipe_manager.food_group_pricing
IS 'Fallback pricing by food group when ingredient-specific price unavailable';

COMMENT ON COLUMN recipe_manager.food_group_pricing.food_group
IS 'Food group category from FOOD_GROUP_ENUM (VEGETABLES, FRUITS, MEAT, etc.)';

COMMENT ON COLUMN recipe_manager.food_group_pricing.avg_price_per_100g
IS 'Average retail price per 100 grams for this food group';

COMMENT ON COLUMN recipe_manager.food_group_pricing.currency
IS 'ISO 4217 currency code (default USD)';

COMMENT ON COLUMN recipe_manager.food_group_pricing.data_source
IS 'Source of average price data (typically USDA_FMAP for food group averages)';

COMMENT ON COLUMN recipe_manager.food_group_pricing.notes
IS 'Description of what products are included in this food group average';
