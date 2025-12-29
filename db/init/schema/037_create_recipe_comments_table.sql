-- db/init/schema/037_create_recipe_comments_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_comments (
  comment_id BIGSERIAL PRIMARY KEY,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes (
    recipe_id
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
CREATE INDEX IF NOT EXISTS idx_recipe_comments_recipe_id
ON recipe_manager.recipe_comments (recipe_id);

CREATE INDEX IF NOT EXISTS idx_recipe_comments_user_id
ON recipe_manager.recipe_comments (user_id);

CREATE INDEX IF NOT EXISTS idx_recipe_comments_created_at
ON recipe_manager.recipe_comments (created_at DESC);
