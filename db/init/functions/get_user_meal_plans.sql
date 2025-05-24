-- db/init/functions/get_user_meal_plans.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_user_meal_plan(uid BIGINT, week_start DATE) RETURNS TABLE (
    meal_date DATE,
    meal_type recipe_manager.meal_type,
    recipe_id BIGINT,
    recipe_title TEXT
  ) AS $$ BEGIN RETURN QUERY
SELECT mpr.meal_date,
  mpr.meal_type,
  r.recipe_id,
  r.title
FROM recipe_manager.meal_plan_recipes mpr
  JOIN recipe_manager.meal_plans mp ON mpr.meal_plan_id = mp.meal_plan_id
  JOIN recipe_manager.recipes r ON r.recipe_id = mpr.recipe_id
WHERE mp.user_id = uid
  AND mpr.meal_date BETWEEN week_start AND week_start + 6;
END;
$$ LANGUAGE plpgsql;
