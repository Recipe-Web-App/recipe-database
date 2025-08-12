-- db/fixtures/016_user_display_preferences.sql
INSERT INTO recipe_manager.user_display_preferences (
  id,
  user_id,
  font_size,
  color_scheme,
  layout_density,
  show_images,
  compact_mode,
  created_at,
  updated_at
)
VALUES (
  DEFAULT,
  '11111111-1111-1111-1111-111111111111',
  'MEDIUM',
  'LIGHT',
  'COMFORTABLE',
  TRUE,
  FALSE,
  NOW(),
  NOW()
),
(
  DEFAULT,
  '22222222-2222-2222-2222-222222222222',
  'LARGE',
  'DARK',
  'COMPACT',
  TRUE,
  TRUE,
  NOW(),
  NOW()
) ON CONFLICT (user_id) DO NOTHING;
