-- db/fixtures/031_collection_favorites.sql
INSERT INTO recipe_manager.collection_favorites (user_id, collection_id, favorited_at)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Quick Weeknight Meals'),
  NOW()
),
(
  '22222222-2222-2222-2222-222222222222',
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Community Favorites'),
  NOW()
) ON CONFLICT (user_id, collection_id) DO NOTHING;
