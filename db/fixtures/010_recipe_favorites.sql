-- db/fixtures/010_recipe_favorites.sql
INSERT INTO recipe_manager.recipe_favorites (user_id, recipe_id, favorited_at)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Spaghetti Carbonara'),
  NOW()
),
(
  '22222222-2222-2222-2222-222222222222',
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  NOW()
) ON CONFLICT (user_id, recipe_id) DO NOTHING;
