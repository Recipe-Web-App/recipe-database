-- db/fixtures/004_ingredients.sql
INSERT INTO recipe_manager.ingredients (ingredient_id, name, description)
VALUES (
    DEFAULT,
    'Sugar',
    'Sweet granulated sugar'
  ),
  (DEFAULT, 'Salt', 'Fine sea salt'),
  (
    DEFAULT,
    'Flour',
    'All-purpose wheat flour'
  );
