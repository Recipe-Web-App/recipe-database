-- db/init/schema/006_create_recipes_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipes (
  recipe_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES recipe_manager.users(user_id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  origin_url TEXT,
  servings NUMERIC(5, 2),
  preparation_time INT,
  cooking_time INT,
  difficulty VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
