-- db/init/schema/043_create_meal_plan_favorites_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.meal_plan_favorites (
  user_id UUID NOT NULL REFERENCES recipe_manager.users (user_id) ON DELETE CASCADE,
  meal_plan_id BIGINT NOT NULL REFERENCES recipe_manager.meal_plans (meal_plan_id) ON DELETE CASCADE,
  favorited_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, meal_plan_id)
);
