-- db/fixtures/004_ingredients.sql
INSERT INTO recipe_manager.ingredients (ingredient_id, name, description, is_optional, comments, created_at, updated_at)
VALUES (
  1,
  'Sugar',
  'Sweet granulated sugar',
  FALSE,
  ARRAY['Use sparingly for health', 'Can substitute with honey'],
  NOW(),
  NOW()
),
(
  2,
  'Salt',
  'Fine sea salt',
  FALSE,
  ARRAY['Essential for flavor', 'Use kosher salt if available'],
  NOW(),
  NOW()
),
(
  3,
  'Flour',
  'All-purpose wheat flour',
  FALSE,
  ARRAY['Sift for better texture', 'Can use gluten-free alternative'],
  NOW(),
  NOW()
);
