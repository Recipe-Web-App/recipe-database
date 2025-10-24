-- db/init/schema/035_create_collection_collaborators_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.collection_collaborators (
  collection_id BIGINT NOT NULL REFERENCES recipe_manager.recipe_collections (
    collection_id
  ) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE RESTRICT,
  granted_by UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE RESTRICT,
  granted_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (collection_id, user_id)
);

-- Index for finding collections a user can collaborate on
CREATE INDEX IF NOT EXISTS idx_collection_collaborators_user_id
  ON recipe_manager.collection_collaborators (user_id);
