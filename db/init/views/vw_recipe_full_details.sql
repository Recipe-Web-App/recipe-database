-- db/init/views/vw_recipe_full_summary.sql
CREATE OR REPLACE VIEW recipe_manager.vw_full_recipe_details AS
SELECT
  r.recipe_id,
  r.title,
  r.description,
  r.servings,
  r.preparation_time,
  r.cooking_time,
  r.difficulty,
  i.ingredient_id,
  i.name AS ingredient_name,
  ri.quantity,
  ri.unit,
  ri.is_optional,
  s.step_number,
  s.instruction,
  ARRAY_AGG(
    ic.comment_text
    ORDER BY ic.created_at
  ) FILTER (
    WHERE ic.comment_text IS NOT NULL AND ic.is_public = TRUE
  ) AS ingredient_comments,
  ARRAY_AGG(
    sc.comment_text
    ORDER BY sc.created_at
  ) FILTER (
    WHERE sc.comment_text IS NOT NULL AND sc.is_public = TRUE
  ) AS step_comments,
  ROUND(AVG(rv.rating)::NUMERIC, 1) AS avg_rating,
  COUNT(rv.rating) AS review_count
FROM recipe_manager.recipes AS r
LEFT JOIN recipe_manager.recipe_ingredients AS ri ON r.recipe_id = ri.recipe_id
LEFT JOIN recipe_manager.ingredients AS i ON ri.ingredient_id = i.ingredient_id
LEFT JOIN recipe_manager.ingredient_comments AS ic
  ON i.ingredient_id = ic.ingredient_id AND r.recipe_id = ic.recipe_id
LEFT JOIN recipe_manager.recipe_steps AS s ON r.recipe_id = s.recipe_id
LEFT JOIN recipe_manager.step_comments AS sc
  ON s.step_id = sc.step_id AND r.recipe_id = sc.recipe_id
LEFT JOIN recipe_manager.reviews AS rv ON r.recipe_id = rv.recipe_id
GROUP BY
  r.recipe_id,
  i.ingredient_id,
  ri.quantity,
  ri.unit,
  ri.is_optional,
  s.step_number,
  s.instruction;
