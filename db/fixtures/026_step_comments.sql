-- db/fixtures/026_step_comments.sql
INSERT INTO recipe_manager.step_comments (recipe_id, step_id, user_id, comment_text, is_public, created_at, updated_at)
VALUES (
  1,
  1,
  '11111111-1111-1111-1111-111111111111',
  'Make sure to whisk thoroughly to avoid lumps',
  TRUE,
  NOW(),
  NOW()
),
(
  1,
  1,
  '22222222-2222-2222-2222-222222222222',
  'I like to add a pinch of salt at this step',
  TRUE,
  NOW(),
  NOW()
),
(
  1,
  2,
  '11111111-1111-1111-1111-111111111111',
  'Don''t overmix or pancakes will be tough',
  TRUE,
  NOW(),
  NOW()
),
(
  1,
  2,
  '22222222-2222-2222-2222-222222222222',
  'Let batter rest for 5 minutes before cooking',
  TRUE,
  NOW(),
  NOW()
),
(
  2,
  3,
  '22222222-2222-2222-2222-222222222222',
  'Save some pasta water for the sauce',
  TRUE,
  NOW(),
  NOW()
),
(
  2,
  4,
  '11111111-1111-1111-1111-111111111111',
  'Don''t let the pancetta burn - medium heat works best',
  TRUE,
  NOW(),
  NOW()
);
