-- db/init/schema/014_create_recipe_tag_junction_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_tag_junction (
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes(recipe_id) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES recipe_manager.recipe_tags(tag_id),
  PRIMARY KEY (recipe_id, tag_id)
);
