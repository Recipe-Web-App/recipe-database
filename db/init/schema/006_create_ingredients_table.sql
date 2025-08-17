-- db/init/schema/006_create_ingredients_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.ingredients (
  ingredient_id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  is_optional BOOLEAN DEFAULT FALSE,
  comments TEXT [],
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add comments column if it doesn't exist (for existing tables)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'recipe_manager'
    AND table_name = 'ingredients'
    AND column_name = 'comments'
  ) THEN
    ALTER TABLE recipe_manager.ingredients ADD COLUMN comments TEXT[];
  END IF;
END $$;
