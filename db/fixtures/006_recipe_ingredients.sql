-- db/fixtures/006_recipe_ingredients.sql
INSERT INTO recipe_manager.recipe_ingredients (
  recipe_id,
  ingredient_id,
  quantity,
  unit,
  is_optional
)
VALUES (1, 1, 50, 'g', FALSE),
-- Sugar in pancakes
(1, 3, 200, 'g', FALSE),
-- Flour in pancakes
(2, 2, 5, 'g', FALSE);
-- Salt in carbonara
