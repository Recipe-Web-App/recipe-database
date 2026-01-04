-- db/init/schema/039_create_collection_tags_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.collection_tags (
  tag_id BIGSERIAL PRIMARY KEY,
  "name" VARCHAR(50) UNIQUE NOT NULL
);
