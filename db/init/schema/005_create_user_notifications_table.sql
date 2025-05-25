-- db/init/schema/005_create_user_notifications_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_notifications (
  notification_id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES recipe_manager.users(user_id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);
