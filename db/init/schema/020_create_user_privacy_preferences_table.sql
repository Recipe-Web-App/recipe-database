-- db/init/schema/020_create_user_privacy_preferences_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_privacy_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES recipe_manager.users (user_id)
  ON DELETE CASCADE,
  profile_visibility recipe_manager.PROFILE_VISIBILITY_ENUM NOT NULL
  DEFAULT 'PUBLIC',
  recipe_visibility recipe_manager.PROFILE_VISIBILITY_ENUM NOT NULL
  DEFAULT 'PUBLIC',
  activity_visibility recipe_manager.PROFILE_VISIBILITY_ENUM NOT NULL
  DEFAULT 'PUBLIC',
  contact_info_visibility recipe_manager.PROFILE_VISIBILITY_ENUM NOT NULL
  DEFAULT 'PRIVATE',
  data_sharing BOOLEAN NOT NULL DEFAULT false,
  analytics_tracking BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_privacy_preferences_user_id_unique UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_privacy_preferences_user_id
ON recipe_manager.user_privacy_preferences (user_id);
CREATE INDEX IF NOT EXISTS idx_user_privacy_preferences_key
ON recipe_manager.user_privacy_preferences (privacy_key);
