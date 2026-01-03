-- db/init/schema/038_create_collection_favorites_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.collection_favorites (
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  collection_id BIGINT NOT NULL REFERENCES recipe_manager.recipe_collections (
    collection_id
  ) ON DELETE CASCADE,
  favorited_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, collection_id)
);
