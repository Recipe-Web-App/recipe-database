-- db/init/schema/014_create_recipe_tags_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_tags (
  tag_id BIGSERIAL PRIMARY KEY,
  "name" VARCHAR(50) UNIQUE NOT NULL
);
