-- db/fixtures/015_user_notification_preferences.sql
INSERT INTO recipe_manager.user_notification_preferences (
  id,
  user_id,
  email_notifications,
  push_notifications,
  sms_notifications,
  marketing_emails,
  security_alerts,
  activity_summaries,
  recipe_recommendations,
  social_interactions,
  created_at,
  updated_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
  TRUE,
  TRUE,
  FALSE,
  FALSE,
  TRUE,
  TRUE,
  TRUE,
  TRUE,
  NOW(),
  NOW()
),
(
  DEFAULT,
  '22222222-2222-2222-2222-222222222222',
  TRUE,
  FALSE,
  FALSE,
  TRUE,
  TRUE,
  FALSE,
  TRUE,
  FALSE,
  NOW(),
  NOW()
) ON CONFLICT (user_id) DO NOTHING;
