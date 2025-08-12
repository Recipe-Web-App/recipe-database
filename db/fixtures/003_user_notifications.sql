-- db/fixtures/003_user_notifications.sql
INSERT INTO recipe_manager.notifications (
  notification_id,
  user_id,
  title,
  message,
  notification_type,
  is_read,
  created_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
  'New Recipe Alert',
  'New recipe from foodlover!',
  'recipe_update',
  FALSE,
  NOW()
),
(
  DEFAULT,
  '22222222-2222-2222-2222-222222222222',
  'Review Liked',
  'Anna Baker liked your review.',
  'social_interaction',
  FALSE,
  NOW()
);
