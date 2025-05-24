-- db/fixtures/ingredients.sql
INSERT INTO recipe_manager.ingredients (
    ingredient_id,
    name,
    description,
    nutritional_info
  )
VALUES (
    DEFAULT,
    'Sugar',
    'Sweet granulated sugar',
    '{"calories": 387, "carbs_g": 100}'
  ),
  (
    DEFAULT,
    'Salt',
    'Fine sea salt',
    '{"sodium_mg": 387}'
  ),
  (
    DEFAULT,
    'Flour',
    'All-purpose wheat flour',
    '{"calories": 364, "protein_g": 10}'
  );
