-- db/init/triggers/enforce_rating_bounds_trigger.sql
-- Function
CREATE OR REPLACE FUNCTION recipe_manager.enforce_rating_bounds()
RETURNS TRIGGER AS $$ BEGIN IF NEW.rating < 0.5
  OR NEW.rating > 5
  OR NEW.rating % 0.5 <> 0 THEN RAISE EXCEPTION 'Rating must be one of: 0.5, 1.0, ..., 5.0';
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Trigger
CREATE TRIGGER validate_rating_range BEFORE
INSERT
OR
UPDATE ON recipe_manager.reviews FOR EACH ROW
EXECUTE FUNCTION recipe_manager.enforce_rating_bounds();
