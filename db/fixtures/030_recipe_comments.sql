-- db/fixtures/030_recipe_comments.sql
INSERT INTO recipe_manager.recipe_comments (
  recipe_id,
  user_id,
  comment_text,
  is_public,
  created_at,
  updated_at
)
VALUES
-- Public comments on recipe 1 (Classic Pancakes)
(
  1,
  '22222222-2222-2222-2222-222222222222',
  'This recipe is amazing! My kids loved it. I added some chocolate chips for extra fun.',
  TRUE,
  NOW(),
  NOW()
),
(
  1,
  '11111111-1111-1111-1111-111111111111',
  'Great for weekend breakfast. I use buttermilk instead of regular milk for fluffier pancakes.',
  TRUE,
  NOW() - INTERVAL '1 day',
  NOW() - INTERVAL '1 day'
),
(
  1,
  '22222222-2222-2222-2222-222222222222',
  'Made this 5 times already. Family favorite!',
  TRUE,
  NOW() - INTERVAL '3 days',
  NOW() - INTERVAL '3 days'
),
-- Public comments on recipe 2 (Spaghetti Carbonara)
(
  2,
  '11111111-1111-1111-1111-111111111111',
  'Authentic Italian recipe! The key is to remove from heat before adding eggs.',
  TRUE,
  NOW(),
  NOW()
),
(
  2,
  '11111111-1111-1111-1111-111111111111',
  'Pro tip: reserve some pasta water to adjust sauce consistency.',
  TRUE,
  NOW() - INTERVAL '5 hours',
  NOW() - INTERVAL '5 hours'
),
-- Private comment (note to self)
(
  2,
  '22222222-2222-2222-2222-222222222222',
  'Remember to buy pecorino romano next time - much better than parmesan!',
  FALSE,
  NOW() - INTERVAL '2 hours',
  NOW() - INTERVAL '2 hours'
);
