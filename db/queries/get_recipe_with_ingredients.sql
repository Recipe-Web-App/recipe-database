-- queries/get_recipe_with_ingredients.sql
SELECT
  r.recipe_id,
  r.title,
  ri.quantity,
  ri.unit,
  i.name,
  ARRAY_AGG(ic.comment_text ORDER BY ic.created_at) FILTER (WHERE ic.comment_text IS NOT NULL AND ic.is_public = TRUE) AS ingredient_comments
FROM recipe_manager.recipes AS r
INNER JOIN recipe_manager.recipe_ingredients AS ri ON r.recipe_id = ri.recipe_id
INNER JOIN recipe_manager.ingredients AS i ON ri.ingredient_id = i.ingredient_id
LEFT JOIN recipe_manager.ingredient_comments AS ic ON i.ingredient_id = ic.ingredient_id AND r.recipe_id = ic.recipe_id
WHERE r.recipe_id = $1
GROUP BY r.recipe_id, r.title, ri.quantity, ri.unit, i.name;
