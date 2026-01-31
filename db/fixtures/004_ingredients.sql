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

-- Additional ingredients for allergen testing
INSERT INTO recipe_manager.ingredients (
  name, description, is_optional, fdc_id, usda_food_description, created_at, updated_at
)
VALUES
  ('Whole Milk', 'Fresh whole milk', FALSE, 173441, 'Milk, whole, 3.25% milkfat', NOW(), NOW()),
  ('Butter', 'Unsalted butter', FALSE, 173410, 'Butter, without salt', NOW(), NOW()),
  ('Eggs', 'Large chicken eggs', FALSE, 173424, 'Egg, whole, raw, fresh', NOW(), NOW()),
  ('Peanut Butter', 'Creamy peanut butter', FALSE, 172470, 'Peanut butter, smooth style', NOW(), NOW()),
  ('Soy Sauce', 'Traditional soy sauce', FALSE, 173886, 'Soy sauce made from soy', NOW(), NOW()),
  ('Almond Milk', 'Unsweetened almond milk', FALSE, NULL, NULL, NOW(), NOW()),
  ('Sesame Oil', 'Toasted sesame oil', FALSE, 172350, 'Oil, sesame, salad or cooking', NOW(), NOW()),
  ('Shrimp', 'Raw shrimp, peeled', FALSE, 175180, 'Crustaceans, shrimp, raw', NOW(), NOW()),
  ('Salmon', 'Fresh Atlantic salmon fillet', FALSE, 175168, 'Fish, salmon, Atlantic, wild, raw', NOW(), NOW()),
  ('Chocolate Chips', 'Semi-sweet chocolate chips', FALSE, NULL, NULL, NOW(), NOW()),
  ('Bread Crumbs', 'Seasoned bread crumbs', FALSE, 172024, 'Bread crumbs, dry, grated', NOW(), NOW())
ON CONFLICT (name) DO NOTHING;
