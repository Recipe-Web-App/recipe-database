-- db/init/schema/015_create_meal_plans_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.meal_plans (
  meal_plan_id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES recipe_manager.users(user_id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  start_date DATE,
  end_date DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
