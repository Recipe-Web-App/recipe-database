-- db/fixtures/004_ingredients.sql
INSERT INTO recipe_manager.ingredients (ingredient_id, name, description, is_optional, created_at, updated_at)
VALUES (
  1,
  'Sugar',
  'Sweet granulated sugar',
  FALSE,
  NOW(),
  NOW()
),
(
  2,
  'Salt',
  'Fine sea salt',
  FALSE,
  NOW(),
  NOW()
),
(
  3,
  'Flour',
  'All-purpose wheat flour',
  FALSE,
  NOW(),
  NOW()
);
