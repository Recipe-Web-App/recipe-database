-- db/init/schema/041_create_meal_plan_tags_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.meal_plan_tags (
  tag_id BIGSERIAL PRIMARY KEY,
  "name" VARCHAR(50) UNIQUE NOT NULL
);
