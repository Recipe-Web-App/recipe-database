-- db/fixtures/022_user_sound_preferences.sql
INSERT INTO recipe_manager.user_sound_preferences (
  id,
  user_id,
  notification_sounds,
  system_sounds,
  volume_level,
  mute_notifications,
  created_at,
  updated_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
  TRUE,
  TRUE,
  TRUE,
  FALSE,
  NOW(),
  NOW()
),
(
  DEFAULT,
  '22222222-2222-2222-2222-222222222222',
  FALSE,
  FALSE,
  FALSE,
  TRUE,
  NOW(),
  NOW()
) ON CONFLICT (user_id) DO NOTHING;
