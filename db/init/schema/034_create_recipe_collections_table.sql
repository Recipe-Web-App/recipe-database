-- db/init/schema/034_create_recipe_collections_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_collections (
  collection_id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  "name" VARCHAR(255) NOT NULL,
  description TEXT,
  visibility recipe_manager.COLLECTION_VISIBILITY_ENUM NOT NULL DEFAULT 'PRIVATE',
  collaboration_mode recipe_manager.COLLABORATION_MODE_ENUM NOT NULL DEFAULT 'OWNER_ONLY',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for finding collections by owner
CREATE INDEX IF NOT EXISTS idx_recipe_collections_user_id
  ON recipe_manager.recipe_collections (user_id);

-- Index for querying public collections
CREATE INDEX IF NOT EXISTS idx_recipe_collections_visibility
  ON recipe_manager.recipe_collections (visibility);
