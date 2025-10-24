-- db/fixtures/028_recipe_collection_items.sql
INSERT INTO recipe_manager.recipe_collection_items (
  collection_id,
  recipe_id,
  display_order,
  added_by,
  added_at
)
VALUES
-- Anna's "My Secret Recipes" collection
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'My Secret Recipes'),
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  10,
  '11111111-1111-1111-1111-111111111111',
  NOW()
),
-- Anna's "Community Favorites" collection
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Community Favorites'),
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Spaghetti Carbonara'),
  10,
  '11111111-1111-1111-1111-111111111111',
  NOW()
),
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Community Favorites'),
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  20,
  '22222222-2222-2222-2222-222222222222',  -- Bob added this one
  NOW()
),
-- Anna's "Holiday Specials" collection
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Holiday Specials'),
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  10,
  '11111111-1111-1111-1111-111111111111',
  NOW()
),
-- Bob's "Quick Weeknight Meals" collection
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Quick Weeknight Meals'),
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Spaghetti Carbonara'),
  10,
  '22222222-2222-2222-2222-222222222222',
  NOW()
),
-- Bob's "Meal Prep Ideas" collection
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Meal Prep Ideas'),
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Spaghetti Carbonara'),
  10,
  '22222222-2222-2222-2222-222222222222',
  NOW()
)
ON CONFLICT (collection_id, recipe_id) DO NOTHING;
