-- db/fixtures/017_user_privacy_preferences.sql
INSERT INTO recipe_manager.user_privacy_preferences (
  id,
  user_id,
  profile_visibility,
  recipe_visibility,
  activity_visibility,
  contact_info_visibility,
  data_sharing,
  analytics_tracking,
  created_at,
  updated_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
  'PUBLIC',
  'PUBLIC',
  'FRIENDS_ONLY',
  'PRIVATE',
  FALSE,
  TRUE,
  NOW(),
  NOW()
),
(
  DEFAULT,
  '22222222-2222-2222-2222-222222222222',
  'FRIENDS_ONLY',
  'FRIENDS_ONLY',
  'PRIVATE',
  'PRIVATE',
  FALSE,
  FALSE,
  NOW(),
  NOW()
) ON CONFLICT (user_id) DO NOTHING;
