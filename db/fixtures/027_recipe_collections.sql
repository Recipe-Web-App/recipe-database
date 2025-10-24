-- db/fixtures/027_recipe_collections.sql
INSERT INTO recipe_manager.recipe_collections (
  user_id,
  name,
  description,
  visibility,
  collaboration_mode,
  created_at,
  updated_at
)
VALUES
-- Anna's private collection (owner only)
(
  '11111111-1111-1111-1111-111111111111',
  'My Secret Recipes',
  'Personal collection of family recipes',
  'PRIVATE',
  'OWNER_ONLY',
  NOW(),
  NOW()
),
-- Anna's public collaborative collection
(
  '11111111-1111-1111-1111-111111111111',
  'Community Favorites',
  'A collection anyone can contribute to',
  'PUBLIC',
  'ALL_USERS',
  NOW(),
  NOW()
),
-- Anna's friends-only collection with specific collaborators
(
  '11111111-1111-1111-1111-111111111111',
  'Holiday Specials',
  'Special recipes for holidays - shared with close friends',
  'FRIENDS_ONLY',
  'SPECIFIC_USERS',
  NOW(),
  NOW()
),
-- Bob's public collection (owner only)
(
  '22222222-2222-2222-2222-222222222222',
  'Quick Weeknight Meals',
  'Fast and easy recipes for busy nights',
  'PUBLIC',
  'OWNER_ONLY',
  NOW(),
  NOW()
),
-- Bob's private collection with specific collaborators
(
  '22222222-2222-2222-2222-222222222222',
  'Meal Prep Ideas',
  'Planning meals for the week',
  'PRIVATE',
  'SPECIFIC_USERS',
  NOW(),
  NOW()
)
ON CONFLICT DO NOTHING;
