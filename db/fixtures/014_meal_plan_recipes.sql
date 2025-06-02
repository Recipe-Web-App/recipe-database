-- db/fixtures/014_meal_plan_recipes.sql
INSERT INTO recipe_manager.meal_plan_recipes (
  meal_plan_id,
  recipe_id,
  meal_date,
  meal_type
)
VALUES (1, 1, '2025-06-01', 'breakfast'),
(1, 2, '2025-06-01', 'lunch');
