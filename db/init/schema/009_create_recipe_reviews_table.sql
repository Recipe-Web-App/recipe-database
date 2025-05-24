-- db/init/schema/009_create_recipe_reviews_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.reviews (
  review_id BIGSERIAL PRIMARY KEY,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes(recipe_id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES recipe_manager.users(user_id) ON DELETE CASCADE,
  rating NUMERIC(2, 1) NOT NULL CHECK (
    rating IN (1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0)
  ),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
