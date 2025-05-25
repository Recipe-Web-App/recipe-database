-- db/init/views/vw_recipe_summary.sql
CREATE OR REPLACE VIEW recipe_manager.recipe_summary AS
SELECT r.recipe_id,
  r.title,
  r.description,
  r.created_at,
  r.updated_at,
  u.user_id,
  u.username,
  COALESCE(AVG(rv.rating), 0) AS average_rating,
  COUNT(f.user_id) AS favorites_count
FROM recipe_manager.recipes r
  JOIN recipe_manager.users u ON u.user_id = r.user_id
  LEFT JOIN recipe_manager.reviews rv ON rv.recipe_id = r.recipe_id
  LEFT JOIN recipe_manager.recipe_favorites f ON f.recipe_id = r.recipe_id
GROUP BY r.recipe_id,
  u.user_id;
