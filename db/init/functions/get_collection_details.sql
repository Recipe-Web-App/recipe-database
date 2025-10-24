-- db/init/functions/get_collection_details.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_collection_details(
  p_collection_id BIGINT
) RETURNS TABLE (
  collection_id BIGINT,
  name VARCHAR,
  description TEXT,
  visibility recipe_manager.COLLECTION_VISIBILITY_ENUM,
  collaboration_mode recipe_manager.COLLABORATION_MODE_ENUM,
  owner_id UUID,
  owner_username VARCHAR,
  recipe_count BIGINT,
  collaborator_count BIGINT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.collection_id,
    c.name,
    c.description,
    c.visibility,
    c.collaboration_mode,
    u.user_id AS owner_id,
    u.username AS owner_username,
    COUNT(DISTINCT ci.recipe_id) AS recipe_count,
    COUNT(DISTINCT cc.user_id) AS collaborator_count,
    c.created_at,
    c.updated_at
  FROM recipe_manager.recipe_collections AS c
  INNER JOIN recipe_manager.users AS u ON c.user_id = u.user_id
  LEFT JOIN recipe_manager.recipe_collection_items AS ci ON c.collection_id = ci.collection_id
  LEFT JOIN recipe_manager.collection_collaborators AS cc ON c.collection_id = cc.collection_id
  WHERE c.collection_id = p_collection_id
  GROUP BY
    c.collection_id,
    u.user_id;
END;
$$ LANGUAGE plpgsql;
