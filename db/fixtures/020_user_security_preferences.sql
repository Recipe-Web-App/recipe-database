-- db/fixtures/020_user_security_preferences.sql
INSERT INTO recipe_manager.user_security_preferences (
  id,
  user_id,
  two_factor_auth,
  login_notifications,
  session_timeout,
  password_requirements,
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
  TRUE,
  FALSE,
  TRUE,
  NOW(),
  NOW()
) ON CONFLICT (user_id) DO NOTHING;
