-- db/init/functions/get_meal_plan_tags.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_meal_plan_tags(
  mpid BIGINT
) RETURNS TEXT AS $$
DECLARE tags TEXT;
BEGIN
SELECT string_agg(t.name, ', ') INTO tags
FROM recipe_manager.meal_plan_tags t
  JOIN recipe_manager.meal_plan_tag_junction j ON t.tag_id = j.tag_id
WHERE j.meal_plan_id = mpid;
RETURN COALESCE(tags, '');
END;
$$ LANGUAGE plpgsql;
