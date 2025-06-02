-- db/fixtures/008_recipe_reviews.sql
INSERT INTO recipe_manager.reviews (
  review_id,
  recipe_id,
  user_id,
  rating,
  comment,
  created_at
)
VALUES (
  DEFAULT,
  1,
  '22222222-2222-2222-2222-222222222222',
  4.5,
  'Loved the pancakes, so fluffy!',
  NOW()
),
(
  DEFAULT,
  2,
  '11111111-1111-1111-1111-111111111111',
  5,
  'Perfect carbonara, will make again.',
  NOW()
);
