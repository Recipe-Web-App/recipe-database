-- db/init/schema/006_create_ingredients_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.ingredients (
  ingredient_id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  is_optional BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
