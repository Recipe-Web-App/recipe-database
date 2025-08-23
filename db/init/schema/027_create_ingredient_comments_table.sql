-- db/init/schema/027_create_ingredient_comments_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.ingredient_comments (
  comment_id BIGSERIAL PRIMARY KEY,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes (
    recipe_id
  ) ON DELETE CASCADE,
  ingredient_id BIGINT NOT NULL REFERENCES recipe_manager.ingredients (
    ingredient_id
  ) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  comment_text TEXT NOT NULL,
  is_public BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_ingredient_comments_recipe_id
ON recipe_manager.ingredient_comments (recipe_id);

CREATE INDEX IF NOT EXISTS idx_ingredient_comments_ingredient_id
ON recipe_manager.ingredient_comments (ingredient_id);

CREATE INDEX IF NOT EXISTS idx_ingredient_comments_user_id
ON recipe_manager.ingredient_comments (user_id);

CREATE INDEX IF NOT EXISTS idx_ingredient_comments_recipe_ingredient
ON recipe_manager.ingredient_comments (recipe_id, ingredient_id);

CREATE INDEX IF NOT EXISTS idx_ingredient_comments_created_at
ON recipe_manager.ingredient_comments (created_at DESC);
