-- db/init/functions/media_timestamps.sql
CREATE OR REPLACE FUNCTION recipe_manager.set_media_timestamps()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.created_at IS NULL THEN
      NEW.created_at := now();
    END IF;
    -- Ensure updated_at is present on insert
    IF NEW.updated_at IS NULL THEN
      NEW.updated_at := now();
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.updated_at := now();
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
