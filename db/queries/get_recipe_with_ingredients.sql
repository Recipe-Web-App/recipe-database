-- queries/get_recipe_with_ingredients.sql
SELECT r.recipe_id,
  r.title,
  ri.quantity,
  ri.unit,
  i.name
FROM recipe_manager.recipes r
  JOIN recipe_manager.recipe_ingredients ri ON r.recipe_id = ri.recipe_id
  JOIN recipe_manager.ingredients i ON i.ingredient_id = ri.ingredient_id
WHERE r.recipe_id = $1;
