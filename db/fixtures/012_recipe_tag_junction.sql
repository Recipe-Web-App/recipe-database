-- db/fixtures/012_recipe_tag_junction.sql
INSERT INTO recipe_manager.recipe_tag_junction (recipe_id, tag_id)
VALUES (
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  (SELECT tag_id FROM recipe_manager.recipe_tags
WHERE name = 'Breakfast')
),
-- Pancakes tagged as Breakfast
(
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Spaghetti Carbonara'),
  (SELECT tag_id FROM recipe_manager.recipe_tags
WHERE name = 'Italian')
),
-- Carbonara tagged as Italian
(
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  (SELECT tag_id FROM recipe_manager.recipe_tags
WHERE name = 'Quick')
) ON CONFLICT (recipe_id, tag_id) DO NOTHING;
-- Pancakes tagged as Quick
