-- db/fixtures/021_user_social_preferences.sql
INSERT INTO recipe_manager.user_social_preferences (
  id,
  user_id,
  friend_requests,
  message_notifications,
  group_invites,
  share_activity,
  created_at,
  updated_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
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
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  NOW(),
  NOW()
) ON CONFLICT (user_id) DO NOTHING;
