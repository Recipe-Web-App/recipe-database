-- db/fixtures/recipe_tag_junction.sql
INSERT INTO recipe_manager.recipe_tag_junction (recipe_id, tag_id)
VALUES (1, 1),
  -- Pancakes tagged as Breakfast
  (2, 2),
  -- Carbonara tagged as Italian
  (1, 3);
-- Pancakes tagged as Quick
