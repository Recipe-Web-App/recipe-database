-- db/fixtures/004_ingredients.sql
INSERT INTO recipe_manager.ingredients (name, description, is_optional, created_at, updated_at)
VALUES (
  'Sugar',
  'Sweet granulated sugar',
  FALSE,
  NOW(),
  NOW()
),
(
  'Salt',
  'Fine sea salt',
  FALSE,
  NOW(),
  NOW()
),
(
  'Flour',
  'All-purpose wheat flour',
  FALSE,
  NOW(),
  NOW()
) ON CONFLICT (name) DO NOTHING;
