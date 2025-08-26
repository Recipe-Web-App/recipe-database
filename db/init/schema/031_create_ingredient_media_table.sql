-- db/init/schema/031_create_ingredient_media_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.ingredient_media (
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes (
    recipe_id
  ) ON DELETE CASCADE,
  ingredient_id BIGINT NOT NULL REFERENCES recipe_manager.ingredients (
    ingredient_id
  ) ON DELETE CASCADE,
  media_id BIGINT NOT NULL REFERENCES recipe_manager.media (
    media_id
  ) ON DELETE CASCADE,
  PRIMARY KEY (recipe_id, ingredient_id, media_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_ingredient_media_recipe_id ON recipe_manager.ingredient_media (
  recipe_id
);
CREATE INDEX idx_ingredient_media_ingredient_id
ON recipe_manager.ingredient_media (
  ingredient_id
);
CREATE INDEX idx_ingredient_media_media_id ON recipe_manager.ingredient_media (
  media_id
);
