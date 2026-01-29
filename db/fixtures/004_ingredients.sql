-- db/fixtures/004_ingredients.sql
-- Sample ingredients with USDA FoodData Central IDs
INSERT INTO recipe_manager.ingredients (
  name, description, is_optional, fdc_id, usda_food_description, created_at, updated_at
)
VALUES (
  'Sugar',
  'Sweet granulated sugar',
  FALSE,
  169655,
  'Sugars, granulated',
  NOW(),
  NOW()
),
(
  'Salt',
  'Fine sea salt',
  FALSE,
  173468,
  'Salt, table',
  NOW(),
  NOW()
),
(
  'Flour',
  'All-purpose wheat flour',
  FALSE,
  169761,
  'Wheat flour, white, all-purpose, unenriched',
  NOW(),
  NOW()
) ON CONFLICT (name) DO NOTHING;
