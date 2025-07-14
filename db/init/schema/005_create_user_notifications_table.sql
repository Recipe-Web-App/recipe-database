-- db/init/schema/005_create_user_notifications_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.notifications (
  notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  notification_type VARCHAR(50) NOT NULL,
  is_read BOOLEAN DEFAULT FALSE NOT NULL,
  is_deleted BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id
ON recipe_manager.notifications (
  user_id
);
CREATE INDEX IF NOT EXISTS idx_notifications_notification_type
ON recipe_manager.notifications (
  notification_type
);
