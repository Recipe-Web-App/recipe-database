-- prevent_duplicate_follow_trigger.sql
-- Optional if not already enforced by a constraint
CREATE OR REPLACE FUNCTION recipe_manager.prevent_duplicate_follow() RETURNS TRIGGER AS $$ BEGIN IF EXISTS (
    SELECT 1
    FROM recipe_manager.user_follows
    WHERE follower_id = NEW.follower_id
      AND followee_id = NEW.followee_id
  ) THEN RAISE EXCEPTION 'You are already following this user';
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER check_duplicate_follow BEFORE
INSERT ON recipe_manager.user_follows FOR EACH ROW EXECUTE FUNCTION recipe_manager.prevent_duplicate_follow();
