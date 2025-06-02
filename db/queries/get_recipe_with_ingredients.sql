-- queries/get_recipe_with_ingredients.sql
SELECT
  r.recipe_id,
  r.title,
  ri.quantity,
  ri.unit,
  i.name
FROM recipe_manager.recipes AS r
INNER JOIN recipe_manager.recipe_ingredients AS ri ON r.recipe_id = ri.recipe_id
INNER JOIN recipe_manager.ingredients AS i ON ri.ingredient_id = i.ingredient_id
WHERE r.recipe_id = $1;
