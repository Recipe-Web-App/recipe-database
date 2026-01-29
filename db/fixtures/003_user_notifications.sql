-- db/fixtures/003_user_notifications.sql
INSERT INTO recipe_manager.notifications (
  user_id,
  notification_category,
  is_read,
  notification_data,
  created_at
)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'RECIPE_PUBLISHED'::recipe_manager.notification_category_enum,
  FALSE,
  '{"template_version": "1.0", "recipe_title": "Classic Pancakes", "actor_name": "foodlover"}'::jsonb,
  NOW()
),
(
  '22222222-2222-2222-2222-222222222222',
  'RECIPE_LIKED'::recipe_manager.notification_category_enum,
  FALSE,
  '{"template_version": "1.0", "actor_name": "Anna Baker", "recipe_title": "Spaghetti Carbonara"}'::jsonb,
  NOW()
);
