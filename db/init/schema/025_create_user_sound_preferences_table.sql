-- db/init/schema/025_create_user_sound_preferences_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_sound_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  notification_sounds BOOLEAN NOT NULL DEFAULT true,
  system_sounds BOOLEAN NOT NULL DEFAULT true,
  volume_level BOOLEAN NOT NULL DEFAULT true,
  mute_notifications BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_sound_preferences_user_id_unique UNIQUE (user_id)
);
