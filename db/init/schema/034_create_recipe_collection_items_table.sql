-- db/init/schema/034_create_recipe_collection_items_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_collection_items (
  collection_id BIGINT NOT NULL REFERENCES recipe_manager.recipe_collections (
    collection_id
  ) ON DELETE CASCADE,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes (
    recipe_id
  ) ON DELETE CASCADE,
  display_order INTEGER NOT NULL,
  added_by UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE RESTRICT,
  added_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (collection_id, recipe_id)
);

-- Index for ordering recipes within a collection
CREATE INDEX IF NOT EXISTS idx_recipe_collection_items_display_order
  ON recipe_manager.recipe_collection_items (collection_id, display_order);

-- Ensure unique display order within each collection
CREATE UNIQUE INDEX IF NOT EXISTS idx_recipe_collection_items_unique_order
  ON recipe_manager.recipe_collection_items (collection_id, display_order);
