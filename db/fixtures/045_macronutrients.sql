-- db/fixtures/045_macronutrients.sql
-- Macronutrient data for test ingredients (per 100g, from USDA)

-- Flour (Wheat flour, white, all-purpose, unenriched)
INSERT INTO recipe_manager.macronutrients (
  nutrition_profile_id, calories_kcal, protein_g, carbs_g, fat_g,
  saturated_fat_g, fiber_g, sugar_g, sodium_mg
)
SELECT
    np.nutrition_profile_id,
    364.0 AS calories_kcal,
    10.33 AS protein_g,
    76.31 AS carbs_g,
    0.98 AS fat_g,
    0.155 AS saturated_fat_g,
    2.7 AS fiber_g,
    0.27 AS sugar_g,
    2.0 AS sodium_mg
FROM recipe_manager.nutrition_profiles AS np
INNER JOIN recipe_manager.ingredients AS i ON np.ingredient_id = i.ingredient_id
WHERE i.name = 'Flour'
ON CONFLICT DO NOTHING;

-- Sugar (Sugars, granulated)
INSERT INTO recipe_manager.macronutrients (
  nutrition_profile_id, calories_kcal, protein_g, carbs_g, fat_g,
  sugar_g, sodium_mg
)
SELECT
    np.nutrition_profile_id,
    387.0 AS calories_kcal,
    0.0 AS protein_g,
    99.98 AS carbs_g,
    0.0 AS fat_g,
    99.8 AS sugar_g,
    1.0 AS sodium_mg
FROM recipe_manager.nutrition_profiles AS np
INNER JOIN recipe_manager.ingredients AS i ON np.ingredient_id = i.ingredient_id
WHERE i.name = 'Sugar'
ON CONFLICT DO NOTHING;

-- Salt (Salt, table)
INSERT INTO recipe_manager.macronutrients (
  nutrition_profile_id, calories_kcal, protein_g, carbs_g, fat_g, sodium_mg
)
SELECT
    np.nutrition_profile_id,
    0.0 AS calories_kcal,
    0.0 AS protein_g,
    0.0 AS carbs_g,
    0.0 AS fat_g,
    38758.0 AS sodium_mg
FROM recipe_manager.nutrition_profiles AS np
INNER JOIN recipe_manager.ingredients AS i ON np.ingredient_id = i.ingredient_id
WHERE i.name = 'Salt'
ON CONFLICT DO NOTHING;
