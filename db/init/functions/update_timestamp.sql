-- db/init/functions/update_timestamp.sql
CREATE OR REPLACE FUNCTION recipe_manager.update_timestamp() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = now();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
