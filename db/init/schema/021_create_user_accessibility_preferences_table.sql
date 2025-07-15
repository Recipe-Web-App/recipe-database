-- db/init/schema/021_create_user_accessibility_preferences_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_accessibility_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  screen_reader BOOLEAN NOT NULL DEFAULT false,
  high_contrast BOOLEAN NOT NULL DEFAULT false,
  reduced_motion BOOLEAN NOT NULL DEFAULT false,
  large_text BOOLEAN NOT NULL DEFAULT false,
  keyboard_navigation BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_accessibility_preferences_user_id_unique UNIQUE (user_id)
);
