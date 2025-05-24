-- db/init/functions/get_average_rating.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_average_rating(p_recipe_id BIGINT) RETURNS TABLE(avg_rating NUMERIC(2, 1), rating_count INT) AS $$ BEGIN RETURN QUERY
SELECT ROUND(AVG(rating)::NUMERIC, 1),
  COUNT(*)
FROM recipe_manager.recipe_reviews
WHERE recipe_id = p_recipe_id;
END;
$$ LANGUAGE plpgsql;
