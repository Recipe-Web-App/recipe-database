-- db/init/functions/set_created_at.sql
-- Ensure created_at is set on INSERT; also set updated_at if missing.
CREATE OR REPLACE FUNCTION recipe_manager.set_created_at()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.created_at IS NULL THEN
      NEW.created_at := now();
    END IF;
    IF NEW.updated_at IS NULL THEN
      NEW.updated_at := now();
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
