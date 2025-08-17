-- db/fixtures/025_ingredient_comments.sql
INSERT INTO recipe_manager.ingredient_comments (recipe_id, ingredient_id, user_id, comment_text, is_public, created_at, updated_at)
VALUES (
  1,
  1,
  '11111111-1111-1111-1111-111111111111',
  'Use sparingly for health',
  TRUE,
  NOW(),
  NOW()
),
(
  1,
  1,
  '22222222-2222-2222-2222-222222222222',
  'Can substitute with honey',
  TRUE,
  NOW(),
  NOW()
),
(
  1,
  2,
  '11111111-1111-1111-1111-111111111111',
  'Essential for flavor',
  TRUE,
  NOW(),
  NOW()
),
(
  1,
  2,
  '22222222-2222-2222-2222-222222222222',
  'Use kosher salt if available',
  TRUE,
  NOW(),
  NOW()
),
(
  2,
  3,
  '22222222-2222-2222-2222-222222222222',
  'Sift for better texture',
  TRUE,
  NOW(),
  NOW()
),
(
  2,
  3,
  '11111111-1111-1111-1111-111111111111',
  'Can use gluten-free alternative',
  TRUE,
  NOW(),
  NOW()
);
