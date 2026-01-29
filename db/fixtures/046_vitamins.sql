-- db/fixtures/046_vitamins.sql
-- Vitamin data for test ingredients (per 100g, from USDA)
-- All values in micrograms (mcg)

-- Flour (Wheat flour, white, all-purpose, unenriched)
-- Note: Unenriched flour has minimal vitamins
INSERT INTO recipe_manager.vitamins (
  nutrition_profile_id, vitamin_b6_mcg, vitamin_e_mcg, vitamin_k_mcg
)
SELECT
    np.nutrition_profile_id,
    44.0 AS vitamin_b6_mcg,
    60.0 AS vitamin_e_mcg,
    0.3 AS vitamin_k_mcg
FROM recipe_manager.nutrition_profiles AS np
INNER JOIN recipe_manager.ingredients AS i ON np.ingredient_id = i.ingredient_id
WHERE i.name = 'Flour'
ON CONFLICT DO NOTHING;

-- Sugar (Sugars, granulated) - negligible vitamins
INSERT INTO recipe_manager.vitamins (nutrition_profile_id)
SELECT np.nutrition_profile_id
FROM recipe_manager.nutrition_profiles AS np
INNER JOIN recipe_manager.ingredients AS i ON np.ingredient_id = i.ingredient_id
WHERE i.name = 'Sugar'
ON CONFLICT DO NOTHING;

-- Salt (Salt, table) - no vitamins
INSERT INTO recipe_manager.vitamins (nutrition_profile_id)
SELECT np.nutrition_profile_id
FROM recipe_manager.nutrition_profiles AS np
INNER JOIN recipe_manager.ingredients AS i ON np.ingredient_id = i.ingredient_id
WHERE i.name = 'Salt'
ON CONFLICT DO NOTHING;
