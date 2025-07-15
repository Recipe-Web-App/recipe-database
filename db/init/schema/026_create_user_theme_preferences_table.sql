-- db/init/schema/026_create_user_theme_preferences_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_theme_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  dark_mode BOOLEAN NOT NULL DEFAULT false,
  light_mode BOOLEAN NOT NULL DEFAULT true,
  auto_theme BOOLEAN NOT NULL DEFAULT false,
  custom_theme recipe_manager.THEME_ENUM,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_theme_preferences_user_id_unique UNIQUE (user_id)
);
