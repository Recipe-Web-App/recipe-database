-- db/fixtures/019_user_language_preferences.sql
INSERT INTO recipe_manager.user_language_preferences (
  id,
  user_id,
  primary_language,
  secondary_language,
  translation_enabled,
  created_at,
  updated_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
  'EN',
  'ES',
  TRUE,
  NOW(),
  NOW()
),
(
  DEFAULT,
  '22222222-2222-2222-2222-222222222222',
  'EN',
  NULL,
  FALSE,
  NOW(),
  NOW()
) ON CONFLICT (user_id) DO NOTHING;
