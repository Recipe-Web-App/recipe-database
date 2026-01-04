-- db/init/functions/get_collection_tags.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_collection_tags(
  cid BIGINT
) RETURNS TEXT AS $$
DECLARE tags TEXT;
BEGIN
SELECT string_agg(t.name, ', ') INTO tags
FROM recipe_manager.collection_tags t
  JOIN recipe_manager.collection_tag_junction j ON t.tag_id = j.tag_id
WHERE j.collection_id = cid;
RETURN COALESCE(tags, '');
END;
$$ LANGUAGE plpgsql;
