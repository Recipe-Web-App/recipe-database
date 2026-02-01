-- db/init/schema/052_create_ingredient_pricing_table.sql
-- Per-ingredient retail pricing for shopping cost estimation
-- One-to-one relationship with ingredients table

CREATE TABLE IF NOT EXISTS recipe_manager.ingredient_pricing (
  pricing_id BIGSERIAL PRIMARY KEY,
  ingredient_id BIGINT NOT NULL UNIQUE
    REFERENCES recipe_manager.ingredients (ingredient_id) ON DELETE CASCADE,
  price_per_100g DECIMAL(10, 4) NOT NULL
    CHECK (price_per_100g >= 0),
  currency VARCHAR(3) NOT NULL DEFAULT 'USD',
  data_source VARCHAR(50) NOT NULL
    CHECK (data_source IN ('USDA_FVP', 'USDA_MEAT', 'USDA_FMAP', 'KAGGLE', 'MANUAL')),
  source_year INTEGER
    CHECK (source_year IS NULL OR (source_year >= 2000 AND source_year <= 2100)),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for ingredient lookups (UNIQUE constraint provides one, but explicit for clarity)
CREATE INDEX IF NOT EXISTS idx_ingredient_pricing_ingredient_id
ON recipe_manager.ingredient_pricing (ingredient_id);

-- Index for data source filtering and analytics
CREATE INDEX IF NOT EXISTS idx_ingredient_pricing_data_source
ON recipe_manager.ingredient_pricing (data_source);

-- Documentation
COMMENT ON TABLE recipe_manager.ingredient_pricing
IS 'Per-ingredient retail pricing for shopping cost estimation';

COMMENT ON COLUMN recipe_manager.ingredient_pricing.ingredient_id
IS 'Foreign key to ingredients table (one-to-one relationship)';

COMMENT ON COLUMN recipe_manager.ingredient_pricing.price_per_100g
IS 'Retail price per 100 grams in specified currency';

COMMENT ON COLUMN recipe_manager.ingredient_pricing.currency
IS 'ISO 4217 currency code (default USD)';

COMMENT ON COLUMN recipe_manager.ingredient_pricing.data_source
IS 'Source of price data: USDA_FVP (fruits/veg), USDA_MEAT (meat), USDA_FMAP (general), KAGGLE, MANUAL';

COMMENT ON COLUMN recipe_manager.ingredient_pricing.source_year
IS 'Year the price data was collected/published';

COMMENT ON COLUMN recipe_manager.ingredient_pricing.notes
IS 'Additional notes about pricing data or methodology';
