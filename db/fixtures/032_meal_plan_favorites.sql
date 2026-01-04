-- db/fixtures/032_meal_plan_favorites.sql
INSERT INTO recipe_manager.meal_plan_favorites (user_id, meal_plan_id, favorited_at)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  (SELECT meal_plan_id FROM recipe_manager.meal_plans
WHERE name = 'Weekend Brunch'),
  NOW()
),
(
  '22222222-2222-2222-2222-222222222222',
  (SELECT meal_plan_id FROM recipe_manager.meal_plans
WHERE name = 'Weekend Brunch'),
  NOW()
) ON CONFLICT (user_id, meal_plan_id) DO NOTHING;
