-- db/init/schema/029_create_recipe_media_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_media (
  media_id BIGINT NOT NULL REFERENCES recipe_manager.media (
    media_id
  ) ON DELETE CASCADE,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes (
    recipe_id
  ) ON DELETE CASCADE,
  PRIMARY KEY (media_id, recipe_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_recipe_media_recipe_id ON recipe_manager.recipe_media (
  recipe_id
);
CREATE INDEX idx_recipe_media_media_id ON recipe_manager.recipe_media (
  media_id
);
