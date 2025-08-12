-- db/fixtures/013_meal_plans.sql
INSERT INTO recipe_manager.meal_plans (
  meal_plan_id,
  user_id,
  name,
  start_date,
  end_date,
  created_at,
  updated_at
)
VALUES (
  1,
  '11111111-1111-1111-1111-111111111111',
  'Weekend Brunch',
  '2025-06-01',
  '2025-06-02',
  NOW(),
  NOW()
);
