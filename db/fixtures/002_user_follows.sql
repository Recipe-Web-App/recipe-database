-- db/fixtures/002_user_follows.sql
INSERT INTO recipe_manager.user_follows (follower_id, followee_id, followed_at)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  NOW()
),
(
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  NOW()
);
