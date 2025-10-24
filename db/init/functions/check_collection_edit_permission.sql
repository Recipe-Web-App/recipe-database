-- db/init/functions/check_collection_edit_permission.sql
CREATE OR REPLACE FUNCTION recipe_manager.check_collection_edit_permission(
  p_collection_id BIGINT,
  p_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_owner_id UUID;
  v_collaboration_mode recipe_manager.collaboration_mode_enum;
  v_is_collaborator BOOLEAN;
BEGIN
  -- Get collection owner and collaboration mode
  SELECT user_id, collaboration_mode
  INTO v_owner_id, v_collaboration_mode
  FROM recipe_manager.recipe_collections
  WHERE collection_id = p_collection_id;

  -- Collection not found
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Check if user is the owner
  IF v_owner_id = p_user_id THEN
    RETURN TRUE;
  END IF;

  -- Check collaboration mode
  CASE v_collaboration_mode
    WHEN 'OWNER_ONLY' THEN
      RETURN FALSE;
    WHEN 'ALL_USERS' THEN
      RETURN TRUE;
    WHEN 'SPECIFIC_USERS' THEN
      -- Check if user is in collaborators table
      SELECT EXISTS (
        SELECT 1
        FROM recipe_manager.collection_collaborators
        WHERE collection_id = p_collection_id
          AND user_id = p_user_id
      ) INTO v_is_collaborator;
      RETURN v_is_collaborator;
    ELSE
      RETURN FALSE;
  END CASE;
END;
$$ LANGUAGE plpgsql;
