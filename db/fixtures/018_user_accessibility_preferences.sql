-- db/fixtures/018_user_accessibility_preferences.sql
INSERT INTO recipe_manager.user_accessibility_preferences (
  id,
  user_id,
  screen_reader,
  high_contrast,
  reduced_motion,
  large_text,
  keyboard_navigation,
  created_at,
  updated_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  NOW(),
  NOW()
),
(
  DEFAULT,
  '22222222-2222-2222-2222-222222222222',
  TRUE,
  TRUE,
  TRUE,
  TRUE,
  TRUE,
  NOW(),
  NOW()
) ON CONFLICT (user_id) DO NOTHING;
