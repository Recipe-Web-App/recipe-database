-- db/init/schema/024_create_user_social_preferences_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_social_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  friend_requests BOOLEAN NOT NULL DEFAULT true,
  message_notifications BOOLEAN NOT NULL DEFAULT true,
  group_invites BOOLEAN NOT NULL DEFAULT true,
  share_activity BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_social_preferences_user_id_unique UNIQUE (user_id)
);
