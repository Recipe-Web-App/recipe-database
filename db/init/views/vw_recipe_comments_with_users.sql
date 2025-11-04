-- db/init/views/vw_recipe_comments_with_users.sql
CREATE OR REPLACE VIEW recipe_manager.vw_recipe_comments_with_users AS
SELECT
  c.comment_id,
  c.recipe_id,
  r.title AS recipe_title,
  c.user_id,
  u.username,
  u.full_name,
  c.comment_text,
  c.is_public,
  c.created_at,
  c.updated_at
FROM recipe_manager.recipe_comments AS c
INNER JOIN recipe_manager.users AS u ON c.user_id = u.user_id
INNER JOIN recipe_manager.recipes AS r ON c.recipe_id = r.recipe_id
WHERE c.is_public = TRUE
ORDER BY c.created_at DESC;
