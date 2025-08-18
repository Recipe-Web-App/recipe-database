-- db/init/schema/028_create_step_comments_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.step_comments (
  comment_id BIGSERIAL PRIMARY KEY,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes (recipe_id) ON DELETE CASCADE,
  step_id BIGINT NOT NULL REFERENCES recipe_manager.recipe_steps (step_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES recipe_manager.users (user_id) ON DELETE CASCADE,
  comment_text TEXT NOT NULL,
  is_public BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_step_comments_recipe_id
ON recipe_manager.step_comments (recipe_id);

CREATE INDEX IF NOT EXISTS idx_step_comments_step_id
ON recipe_manager.step_comments (step_id);

CREATE INDEX IF NOT EXISTS idx_step_comments_user_id
ON recipe_manager.step_comments (user_id);

CREATE INDEX IF NOT EXISTS idx_step_comments_recipe_step
ON recipe_manager.step_comments (recipe_id, step_id);

CREATE INDEX IF NOT EXISTS idx_step_comments_created_at
ON recipe_manager.step_comments (created_at DESC);
