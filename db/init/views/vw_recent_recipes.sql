-- db/init/views/vw_recent_recipes.sql
CREATE OR REPLACE VIEW recipe_manager.vw_recent_recipes AS
SELECT
  r.recipe_id,
  r.title,
  r.description,
  r.created_at,
  u.username
FROM recipe_manager.recipes AS r
INNER JOIN recipe_manager.users AS u ON r.user_id = u.user_id
ORDER BY r.created_at DESC
LIMIT 50;
