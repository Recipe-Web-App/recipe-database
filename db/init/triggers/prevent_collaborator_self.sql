-- db/init/triggers/prevent_collaborator_self.sql
CREATE OR REPLACE FUNCTION recipe_manager.prevent_owner_as_collaborator()
RETURNS TRIGGER AS $$ BEGIN IF EXISTS (
    SELECT 1
    FROM recipe_manager.recipe_collections
    WHERE collection_id = NEW.collection_id
      AND user_id = NEW.user_id
  ) THEN RAISE EXCEPTION 'Collection owner cannot be added as a collaborator.';
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS prevent_owner_collaboration ON recipe_manager.collection_collaborators;
CREATE TRIGGER prevent_owner_collaboration BEFORE
INSERT ON recipe_manager.collection_collaborators FOR EACH ROW
EXECUTE FUNCTION recipe_manager.prevent_owner_as_collaborator();
