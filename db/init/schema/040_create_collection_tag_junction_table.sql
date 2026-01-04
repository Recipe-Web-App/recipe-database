-- db/init/schema/040_create_collection_tag_junction_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.collection_tag_junction (
  collection_id BIGINT NOT NULL REFERENCES recipe_manager.recipe_collections (
    collection_id
  ) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES recipe_manager.collection_tags (tag_id),
  PRIMARY KEY (collection_id, tag_id)
);
