-- db/init/schema/042_create_meal_plan_tag_junction_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.meal_plan_tag_junction (
  meal_plan_id BIGINT NOT NULL REFERENCES recipe_manager.meal_plans (
    meal_plan_id
  ) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES recipe_manager.meal_plan_tags (tag_id),
  PRIMARY KEY (meal_plan_id, tag_id)
);
