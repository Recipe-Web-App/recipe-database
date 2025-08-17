-- db/fixtures/014_meal_plan_recipes.sql
INSERT INTO recipe_manager.meal_plan_recipes (
  meal_plan_id,
  recipe_id,
  meal_date,
  meal_type
)
VALUES (
  (SELECT meal_plan_id FROM recipe_manager.meal_plans
WHERE name = 'Weekend Brunch'),
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  '2025-06-01', 'BREAKFAST'
),
(
  (SELECT meal_plan_id FROM recipe_manager.meal_plans
WHERE name = 'Weekend Brunch'),
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Spaghetti Carbonara'),
  '2025-06-01', 'LUNCH'
) ON CONFLICT (meal_plan_id, recipe_id, meal_date) DO NOTHING;
