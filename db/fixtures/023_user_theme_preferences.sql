-- db/fixtures/023_user_theme_preferences.sql
INSERT INTO recipe_manager.user_theme_preferences (
  id,
  user_id,
  dark_mode,
  light_mode,
  auto_theme,
  custom_theme,
  created_at,
  updated_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
  FALSE,
  TRUE,
  FALSE,
  'LIGHT',
  NOW(),
  NOW()
),
(
  DEFAULT,
  '22222222-2222-2222-2222-222222222222',
  TRUE,
  FALSE,
  FALSE,
  'DARK',
  NOW(),
  NOW()
) ON CONFLICT (user_id) DO NOTHING;
