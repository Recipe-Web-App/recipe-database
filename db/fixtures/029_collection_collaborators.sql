-- db/fixtures/029_collection_collaborators.sql
INSERT INTO recipe_manager.collection_collaborators (
  collection_id,
  user_id,
  granted_by,
  granted_at
)
VALUES
-- Bob is a collaborator on Anna's "Holiday Specials" collection
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Holiday Specials'),
  '22222222-2222-2222-2222-222222222222',  -- Bob
  '11111111-1111-1111-1111-111111111111',  -- Granted by Anna
  NOW()
),
-- Anna is a collaborator on Bob's "Meal Prep Ideas" collection
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Meal Prep Ideas'),
  '11111111-1111-1111-1111-111111111111',  -- Anna
  '22222222-2222-2222-2222-222222222222',  -- Granted by Bob
  NOW()
)
ON CONFLICT (collection_id, user_id) DO NOTHING;
