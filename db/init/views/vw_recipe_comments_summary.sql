-- db/init/views/vw_recipe_comments_summary.sql
CREATE OR REPLACE VIEW recipe_manager.vw_recipe_comments_summary AS
SELECT
  r.recipe_id,
  r.title,
  COUNT(c.comment_id) AS total_comment_count,
  COUNT(c.comment_id) FILTER (WHERE c.is_public = TRUE) AS public_comment_count,
  COUNT(DISTINCT c.user_id) AS unique_commenters,
  MAX(c.created_at) AS latest_comment_at
FROM recipe_manager.recipes AS r
LEFT JOIN recipe_manager.recipe_comments AS c ON r.recipe_id = c.recipe_id
GROUP BY r.recipe_id, r.title;
