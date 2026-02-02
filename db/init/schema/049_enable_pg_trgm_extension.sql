-- db/init/schema/049_enable_pg_trgm_extension.sql
-- Enable pg_trgm extension for fuzzy text matching
-- Required for allergen service ingredient name lookups

CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA public;

-- Trigram GIN index for fast similarity searches on ingredient names
-- Supports queries like: similarity(LOWER(name), LOWER($1)) > 0.3
CREATE INDEX IF NOT EXISTS idx_ingredients_name_trgm
ON recipe_manager.ingredients USING gin (name public.gin_trgm_ops);

COMMENT ON INDEX recipe_manager.idx_ingredients_name_trgm
IS 'Trigram index for fuzzy ingredient name matching in allergen lookups';
