-- db/init/schema/014_create_meal_plan_recipes_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.meal_plan_recipes (
  meal_plan_id BIGINT NOT NULL REFERENCES recipe_manager.meal_plans(meal_plan_id) ON DELETE CASCADE,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes(recipe_id) ON DELETE CASCADE,
  meal_date DATE NOT NULL,
  meal_type recipe_manager.meal_type_enum NOT NULL,
  PRIMARY KEY (meal_plan_id, recipe_id, meal_date)
);
