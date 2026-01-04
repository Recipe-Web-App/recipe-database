-- db/fixtures/033_collection_tag_junction.sql
INSERT INTO recipe_manager.collection_tag_junction (collection_id, tag_id)
VALUES (
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Community Favorites'),
  (SELECT tag_id FROM recipe_manager.collection_tags
WHERE name = 'Favorites')
),
-- Community Favorites tagged as Favorites
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Holiday Specials'),
  (SELECT tag_id FROM recipe_manager.collection_tags
WHERE name = 'Holiday')
),
-- Holiday Specials tagged as Holiday
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Holiday Specials'),
  (SELECT tag_id FROM recipe_manager.collection_tags
WHERE name = 'Seasonal')
),
-- Holiday Specials tagged as Seasonal
(
  (SELECT collection_id FROM recipe_manager.recipe_collections
WHERE name = 'Quick Weeknight Meals'),
  (SELECT tag_id FROM recipe_manager.collection_tags
WHERE name = 'Weeknight')
) ON CONFLICT (collection_id, tag_id) DO NOTHING;
-- Quick Weeknight Meals tagged as Weeknight
