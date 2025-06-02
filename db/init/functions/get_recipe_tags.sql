-- db/init/functions/get_recipe_tags.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_recipe_tags(
  rid BIGINT
) RETURNS TEXT AS $$
DECLARE tags TEXT;
BEGIN
SELECT string_agg(t.name, ', ') INTO tags
FROM recipe_manager.recipe_tags t
  JOIN recipe_manager.recipe_tag_junction j ON t.tag_id = j.tag_id
WHERE j.recipe_id = rid;
RETURN COALESCE(tags, '');
END;
$$ LANGUAGE plpgsql;
