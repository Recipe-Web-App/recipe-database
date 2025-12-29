-- db/init/schema/005_create_user_notifications_table.sql
-- Core notifications table - stores user-facing notification data
-- Delivery tracking is handled separately in notification_statuses table
-- Title/message are rendered on-the-fly from notification_category + notification_data

CREATE TABLE IF NOT EXISTS recipe_manager.notifications (
  -- Primary key
  notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- User relationship (owner of this notification)
  user_id UUID NOT NULL REFERENCES recipe_manager.users (user_id) ON DELETE CASCADE,

  -- Template identification (determines how to render notification)
  notification_category recipe_manager.NOTIFICATION_CATEGORY_ENUM NOT NULL,

  -- In-app notification state
  is_read BOOLEAN DEFAULT FALSE NOT NULL,
  is_deleted BOOLEAN DEFAULT FALSE NOT NULL,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

  -- Template data: params for rendering + template_version for historical accuracy
  -- Example: {"template_version": "1.0", "recipe_id": 789, "recipe_title": "Pasta", "actor_name": "John"}
  notification_data JSONB NOT NULL
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_notifications_user_id
  ON recipe_manager.notifications (user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_category
  ON recipe_manager.notifications (notification_category);

CREATE INDEX IF NOT EXISTS idx_notifications_is_read
  ON recipe_manager.notifications (user_id, is_read)
  WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON recipe_manager.notifications (created_at DESC);

-- Composite index for paginated user notification queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON recipe_manager.notifications (user_id, created_at DESC)
  WHERE is_deleted = FALSE;
