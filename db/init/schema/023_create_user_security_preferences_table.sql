-- db/init/schema/023_create_user_security_preferences_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_security_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  two_factor_auth BOOLEAN NOT NULL DEFAULT false,
  login_notifications BOOLEAN NOT NULL DEFAULT true,
  session_timeout BOOLEAN NOT NULL DEFAULT false,
  password_requirements BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_security_preferences_user_id_unique UNIQUE (user_id)
);
