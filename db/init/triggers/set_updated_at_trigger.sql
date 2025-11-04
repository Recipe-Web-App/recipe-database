-- db/init/triggers/set_updated_at_trigger.sql
-- Function
CREATE OR REPLACE FUNCTION recipe_manager.set_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = now();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Triggers
CREATE TRIGGER set_recipes_updated_at BEFORE
UPDATE ON recipe_manager.recipes FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_updated_at();

CREATE TRIGGER set_ingredient_comments_updated_at BEFORE
UPDATE ON recipe_manager.ingredient_comments FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_updated_at();

CREATE TRIGGER set_step_comments_updated_at BEFORE
UPDATE ON recipe_manager.step_comments FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_updated_at();

CREATE TRIGGER set_recipe_collections_updated_at BEFORE
UPDATE ON recipe_manager.recipe_collections FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_updated_at();

CREATE TRIGGER set_recipe_comments_updated_at BEFORE
UPDATE ON recipe_manager.recipe_comments FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_updated_at();
