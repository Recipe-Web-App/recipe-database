-- db/init/functions/get_meal_plan_summary.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_meal_plan_summary(p_meal_plan_id BIGINT) RETURNS TABLE(
    recipe_count INT,
    first_meal DATE,
    last_meal DATE
  ) AS $$ BEGIN RETURN QUERY
SELECT COUNT(*),
  MIN(meal_date),
  MAX(meal_date)
FROM recipe_manager.meal_plan_recipes
WHERE meal_plan_id = p_meal_plan_id;
END;
$$ LANGUAGE plpgsql;
