-- db/fixtures/007_recipe_steps.sql
INSERT INTO recipe_manager.recipe_steps (
  recipe_id, step_number, instruction
)
VALUES (
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  1, 'Mix flour and sugar together.'
),
(
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Classic Pancakes'),
  2,
  'Add milk and eggs, then stir until smooth.'
),
(
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Spaghetti Carbonara'),
  1, 'Boil pasta until al dente.'
),
(
  (SELECT recipe_id FROM recipe_manager.recipes
WHERE title = 'Spaghetti Carbonara'),
  2,
  'Cook pancetta with salt and pepper.'
);
