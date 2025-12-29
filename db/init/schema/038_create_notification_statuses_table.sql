-- db/init/schema/038_create_notification_statuses_table.sql
-- Tracks delivery status per notification channel
-- Composite primary key: (notification_id, notification_type)
-- Allows one notification to be delivered via multiple channels independently

CREATE TABLE IF NOT EXISTS recipe_manager.notification_statuses (
  -- Composite primary key components
  notification_id UUID NOT NULL REFERENCES recipe_manager.notifications (notification_id) ON DELETE CASCADE,
  notification_type recipe_manager.NOTIFICATION_TYPE_ENUM NOT NULL,

  -- Delivery status
  status recipe_manager.NOTIFICATION_STATUS_ENUM NOT NULL DEFAULT 'PENDING',

  -- Retry tracking (nullable - NULL means no retries attempted yet)
  retry_count INTEGER,

  -- Error details (nullable - only populated on failure)
  error_message TEXT,

  -- Delivery target (for EMAIL type; nullable for other types)
  recipient_email VARCHAR(255),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  queued_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,

  -- Composite primary key
  PRIMARY KEY (notification_id, notification_type)
);

-- Index for querying by status (find pending/failed notifications for retry)
CREATE INDEX IF NOT EXISTS idx_notification_statuses_status
  ON recipe_manager.notification_statuses (status);

-- Index for looking up all statuses for a notification
CREATE INDEX IF NOT EXISTS idx_notification_statuses_notification_id
  ON recipe_manager.notification_statuses (notification_id);

-- Partial index for pending/queued notifications (worker queue queries)
CREATE INDEX IF NOT EXISTS idx_notification_statuses_pending
  ON recipe_manager.notification_statuses (status, created_at)
  WHERE status IN ('PENDING', 'QUEUED');

-- Partial index for failed notifications (retry queue queries)
CREATE INDEX IF NOT EXISTS idx_notification_statuses_failed
  ON recipe_manager.notification_statuses (status, failed_at)
  WHERE status = 'FAILED';

-- Index for email delivery lookups
CREATE INDEX IF NOT EXISTS idx_notification_statuses_recipient_email
  ON recipe_manager.notification_statuses (recipient_email)
  WHERE recipient_email IS NOT NULL;

-- Index for notification type filtering
CREATE INDEX IF NOT EXISTS idx_notification_statuses_type
  ON recipe_manager.notification_statuses (notification_type);
