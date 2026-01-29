-- db/fixtures/047_minerals.sql
-- Mineral data for test ingredients (per 100g, from USDA)
-- All values in milligrams (mg)

-- Flour (Wheat flour, white, all-purpose, unenriched)
INSERT INTO recipe_manager.minerals (
  nutrition_profile_id, calcium_mg, iron_mg, magnesium_mg, potassium_mg, zinc_mg
)
SELECT
    np.nutrition_profile_id,
    15.0 AS calcium_mg,
    1.17 AS iron_mg,
    22.0 AS magnesium_mg,
    107.0 AS potassium_mg,
    0.7 AS zinc_mg
FROM recipe_manager.nutrition_profiles AS np
INNER JOIN recipe_manager.ingredients AS i ON np.ingredient_id = i.ingredient_id
WHERE i.name = 'Flour'
ON CONFLICT DO NOTHING;

-- Sugar (Sugars, granulated) - minimal minerals
INSERT INTO recipe_manager.minerals (
  nutrition_profile_id, calcium_mg, iron_mg, potassium_mg
)
SELECT
    np.nutrition_profile_id,
    1.0 AS calcium_mg,
    0.01 AS iron_mg,
    2.0 AS potassium_mg
FROM recipe_manager.nutrition_profiles AS np
INNER JOIN recipe_manager.ingredients AS i ON np.ingredient_id = i.ingredient_id
WHERE i.name = 'Sugar'
ON CONFLICT DO NOTHING;

-- Salt (Salt, table) - notable calcium, magnesium, potassium
INSERT INTO recipe_manager.minerals (
  nutrition_profile_id, calcium_mg, magnesium_mg, potassium_mg
)
SELECT
    np.nutrition_profile_id,
    24.0 AS calcium_mg,
    1.0 AS magnesium_mg,
    8.0 AS potassium_mg
FROM recipe_manager.nutrition_profiles AS np
INNER JOIN recipe_manager.ingredients AS i ON np.ingredient_id = i.ingredient_id
WHERE i.name = 'Salt'
ON CONFLICT DO NOTHING;
