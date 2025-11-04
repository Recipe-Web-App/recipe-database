-- db/init/functions/get_recipe_comments.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_recipe_comments(
  p_recipe_id BIGINT,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_public_only BOOLEAN DEFAULT TRUE
) RETURNS TABLE (
  comment_id BIGINT,
  user_id UUID,
  username VARCHAR,
  comment_text TEXT,
  is_public BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.comment_id,
    c.user_id,
    u.username,
    c.comment_text,
    c.is_public,
    c.created_at,
    c.updated_at
  FROM recipe_manager.recipe_comments AS c
  INNER JOIN recipe_manager.users AS u ON c.user_id = u.user_id
  WHERE c.recipe_id = p_recipe_id
    AND (NOT p_public_only OR c.is_public = TRUE)
  ORDER BY c.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;
