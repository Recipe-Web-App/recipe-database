-- db/init/functions/get_recipe_comment_count.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_recipe_comment_count(
  p_recipe_id BIGINT
) RETURNS TABLE (
  total_comments BIGINT,
  public_comments BIGINT,
  private_comments BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_comments,
    COUNT(*) FILTER (WHERE is_public = TRUE) AS public_comments,
    COUNT(*) FILTER (WHERE is_public = FALSE) AS private_comments
  FROM recipe_manager.recipe_comments
  WHERE recipe_id = p_recipe_id;
END;
$$ LANGUAGE plpgsql;
