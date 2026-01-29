-- db/fixtures/044_nutrition_profiles.sql
-- Nutrition profiles for test ingredients (linked to USDA FoodData Central)
INSERT INTO recipe_manager.nutrition_profiles (
  ingredient_id, serving_size_g, data_source, fdc_data_type
)
SELECT
    i.ingredient_id,
    100.00 AS serving_size_g,
    'USDA' AS data_source,
    'foundation_food' AS fdc_data_type
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Flour'
ON CONFLICT DO NOTHING;

INSERT INTO recipe_manager.nutrition_profiles (
  ingredient_id, serving_size_g, data_source, fdc_data_type
)
SELECT
    i.ingredient_id,
    100.00 AS serving_size_g,
    'USDA' AS data_source,
    'sr_legacy_food' AS fdc_data_type
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Sugar'
ON CONFLICT DO NOTHING;

INSERT INTO recipe_manager.nutrition_profiles (
  ingredient_id, serving_size_g, data_source, fdc_data_type
)
SELECT
    i.ingredient_id,
    100.00 AS serving_size_g,
    'USDA' AS data_source,
    'sr_legacy_food' AS fdc_data_type
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Salt'
ON CONFLICT DO NOTHING;
