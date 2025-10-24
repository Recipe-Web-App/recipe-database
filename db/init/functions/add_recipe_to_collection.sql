-- db/init/functions/add_recipe_to_collection.sql
CREATE OR REPLACE FUNCTION recipe_manager.add_recipe_to_collection(
  p_collection_id BIGINT,
  p_recipe_id BIGINT,
  p_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_next_order INTEGER;
  v_has_permission BOOLEAN;
BEGIN
  -- Check if user has permission to edit this collection
  SELECT recipe_manager.check_collection_edit_permission(
    p_collection_id,
    p_user_id
  ) INTO v_has_permission;

  IF NOT v_has_permission THEN
    RAISE EXCEPTION 'User does not have permission to edit this collection';
  END IF;

  -- Calculate next display_order (use increments of 10 for easy reordering)
  SELECT COALESCE(MAX(display_order), 0) + 10
  INTO v_next_order
  FROM recipe_manager.recipe_collection_items
  WHERE collection_id = p_collection_id;

  -- Insert the recipe into the collection
  INSERT INTO recipe_manager.recipe_collection_items (
    collection_id,
    recipe_id,
    display_order,
    added_by,
    added_at
  )
  VALUES (
    p_collection_id,
    p_recipe_id,
    v_next_order,
    p_user_id,
    now()
  )
  ON CONFLICT (collection_id, recipe_id) DO NOTHING;

  RETURN TRUE;
EXCEPTION
  WHEN foreign_key_violation THEN
    RAISE EXCEPTION 'Collection or recipe does not exist';
  WHEN OTHERS THEN
    RAISE;
END;
$$ LANGUAGE plpgsql;
