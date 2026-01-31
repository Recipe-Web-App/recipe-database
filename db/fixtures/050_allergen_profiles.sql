-- db/fixtures/050_allergen_profiles.sql
-- Allergen profiles for test ingredients

-- Flour: contains GLUTEN, WHEAT
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Flour'
ON CONFLICT DO NOTHING;

-- Sugar: no allergens (will have NONE entry)
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Sugar'
ON CONFLICT DO NOTHING;

-- Salt: no allergens (will have NONE entry)
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Salt'
ON CONFLICT DO NOTHING;

-- Whole Milk: contains MILK
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Whole Milk'
ON CONFLICT DO NOTHING;

-- Butter: contains MILK
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Butter'
ON CONFLICT DO NOTHING;

-- Eggs: contains EGGS
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Eggs'
ON CONFLICT DO NOTHING;

-- Peanut Butter: contains PEANUTS
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Peanut Butter'
ON CONFLICT DO NOTHING;

-- Soy Sauce: contains SOYBEANS, WHEAT, GLUTEN
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Soy Sauce'
ON CONFLICT DO NOTHING;

-- Almond Milk: contains ALMONDS, TREE_NUTS
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'MANUAL' AS data_source,
    0.95 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Almond Milk'
ON CONFLICT DO NOTHING;

-- Sesame Oil: contains SESAME
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Sesame Oil'
ON CONFLICT DO NOTHING;

-- Shrimp: contains SHELLFISH
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Shrimp'
ON CONFLICT DO NOTHING;

-- Salmon: contains FISH
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'USDA' AS data_source,
    1.0 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Salmon'
ON CONFLICT DO NOTHING;

-- Chocolate Chips: contains MILK, may contain TREE_NUTS, contains SOYBEANS
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'MANUAL' AS data_source,
    0.90 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Chocolate Chips'
ON CONFLICT DO NOTHING;

-- Bread Crumbs: contains GLUTEN, WHEAT, may contain MILK
INSERT INTO recipe_manager.allergen_profiles (ingredient_id, data_source, confidence_score)
SELECT
    i.ingredient_id,
    'MANUAL' AS data_source,
    0.85 AS confidence_score
FROM recipe_manager.ingredients AS i
WHERE i.name = 'Bread Crumbs'
ON CONFLICT DO NOTHING;
