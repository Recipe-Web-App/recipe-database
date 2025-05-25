-- db/init/views/vw_top_rated_recipes.sql
CREATE OR REPLACE VIEW recipe_manager.vw_top_rated_recipes AS
SELECT r.recipe_id,
  r.title,
  ROUND(AVG(rv.rating)::NUMERIC, 1) AS avg_rating,
  COUNT(rv.rating) AS review_count
FROM recipe_manager.recipes r
  JOIN recipe_manager.reviews rv ON r.recipe_id = rv.recipe_id
GROUP BY r.recipe_id,
  r.title
HAVING COUNT(rv.rating) >= 3
ORDER BY avg_rating DESC,
  review_count DESC
LIMIT 50;
