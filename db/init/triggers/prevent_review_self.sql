-- db/init/triggers/prevent_review_self.sql
CREATE OR REPLACE FUNCTION recipe_manager.prevent_reviewing_own_recipe() RETURNS TRIGGER AS $$ BEGIN IF EXISTS (
    SELECT 1
    FROM recipe_manager.recipes
    WHERE recipe_id = NEW.recipe_id
      AND user_id = NEW.user_id
  ) THEN RAISE EXCEPTION 'You cannot review your own recipe.';
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER prevent_self_review BEFORE
INSERT ON recipe_manager.recipe_reviews FOR EACH ROW EXECUTE FUNCTION recipe_manager.prevent_reviewing_own_recipe();
