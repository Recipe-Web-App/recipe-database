-- db/init/functions/get_user_recipe_comments.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_user_recipe_comments(
  p_user_id UUID,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
) RETURNS TABLE (
  comment_id BIGINT,
  recipe_id BIGINT,
  recipe_title VARCHAR,
  comment_text TEXT,
  is_public BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.comment_id,
    c.recipe_id,
    r.title AS recipe_title,
    c.comment_text,
    c.is_public,
    c.created_at,
    c.updated_at
  FROM recipe_manager.recipe_comments AS c
  INNER JOIN recipe_manager.recipes AS r ON c.recipe_id = r.recipe_id
  WHERE c.user_id = p_user_id
  ORDER BY c.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;
