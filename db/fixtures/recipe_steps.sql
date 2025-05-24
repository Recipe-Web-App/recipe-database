-- db/fixtures/recipe_steps.sql
INSERT INTO recipe_manager.recipe_steps (step_id, recipe_id, step_number, instruction)
VALUES (DEFAULT, 1, 1, 'Mix flour and sugar together.'),
  (
    DEFAULT,
    1,
    2,
    'Add milk and eggs, then stir until smooth.'
  ),
  (DEFAULT, 2, 1, 'Boil pasta until al dente.'),
  (
    DEFAULT,
    2,
    2,
    'Cook pancetta with salt and pepper.'
  );
