-- db/fixtures/003_user_notifications.sql
INSERT INTO recipe_manager.user_notifications (
  notification_id,
  user_id,
  message,
  is_read,
  created_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
  'New recipe from foodlover!',
  FALSE,
  NOW()
),
(
  DEFAULT,
  '22222222-2222-2222-2222-222222222222',
  'Anna Baker liked your review.',
  FALSE,
  NOW()
);
