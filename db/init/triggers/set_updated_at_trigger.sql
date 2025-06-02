-- db/init/triggers/set_updated_at_trigger.sql
-- Function
CREATE OR REPLACE FUNCTION recipe_manager.set_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = now();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Trigger
CREATE TRIGGER set_recipes_updated_at BEFORE
UPDATE ON recipe_manager.recipes FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_updated_at();
