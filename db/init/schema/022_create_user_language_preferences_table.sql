-- db/init/schema/022_create_user_language_preferences_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_language_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  primary_language recipe_manager.LANGUAGE_ENUM NOT NULL DEFAULT 'EN',
  secondary_language recipe_manager.LANGUAGE_ENUM,
  translation_enabled BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_language_preferences_user_id_unique UNIQUE (user_id)
);
