-- db/init/schema/031_create_step_media_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.step_media (
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes (
    recipe_id
  ) ON DELETE CASCADE,
  step_id BIGINT NOT NULL REFERENCES recipe_manager.recipe_steps (
    step_id
  ) ON DELETE CASCADE,
  media_id BIGINT NOT NULL REFERENCES recipe_manager.media (
    media_id
  ) ON DELETE CASCADE,
  PRIMARY KEY (step_id, media_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_step_media_recipe_id ON recipe_manager.step_media (
  recipe_id
);
CREATE INDEX idx_step_media_step_id ON recipe_manager.step_media (
  step_id
);
CREATE INDEX idx_step_media_media_id ON recipe_manager.step_media (
  media_id
);
