-- db/fixtures/006_recipe_ingredients.sql
INSERT INTO recipe_manager.recipe_ingredients (
  recipe_id,
  ingredient_id,
  quantity,
  unit,
  is_optional
)
VALUES (
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  (SELECT ingredient_id FROM recipe_manager.ingredients
WHERE name = 'Sugar'),
  50, 'G', FALSE
),
-- Sugar in pancakes
(
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  (SELECT ingredient_id FROM recipe_manager.ingredients
WHERE name = 'Flour'),
  200, 'G', FALSE
),
-- Flour in pancakes
(
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Spaghetti Carbonara'),
  (SELECT ingredient_id FROM recipe_manager.ingredients
WHERE name = 'Salt'),
  5, 'G', FALSE
) ON CONFLICT (recipe_id, ingredient_id) DO NOTHING;
-- Salt in carbonara
