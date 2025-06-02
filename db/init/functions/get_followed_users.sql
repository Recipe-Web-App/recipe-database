-- db/init/functions/get_followed_users.sql
CREATE OR REPLACE FUNCTION recipe_manager.get_followed_users(
  p_user_id BIGINT
) RETURNS TABLE (followed_user_id BIGINT) AS $$ BEGIN RETURN QUERY
SELECT followed_user_id
FROM recipe_manager.user_follows
WHERE follower_id = p_user_id;
END;
$$ LANGUAGE plpgsql;
