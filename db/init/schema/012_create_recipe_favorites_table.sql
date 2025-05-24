-- db/init/schema/012_create_recipe_favorites_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_favorites (
  user_id BIGINT NOT NULL REFERENCES recipe_manager.users(user_id) ON DELETE CASCADE,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes(recipe_id) ON DELETE CASCADE,
  favorited_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, recipe_id)
);
