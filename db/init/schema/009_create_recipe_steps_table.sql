-- db/init/schema/009_create_recipe_steps_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_steps (
  step_id BIGSERIAL PRIMARY KEY,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes(recipe_id) ON DELETE CASCADE,
  step_number INT NOT NULL,
  instruction TEXT NOT NULL,
  optional BOOLEAN DEFAULT FALSE,
  timer_seconds INT,
  created_at TIMESTAMPTZ DEFAULT now()
);
