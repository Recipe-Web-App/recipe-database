-- db/fixtures/051_ingredient_allergens.sql
-- Individual allergen entries for test ingredients

-- Flour: GLUTEN, WHEAT
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    allergen.type::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
CROSS JOIN (VALUES ('GLUTEN'), ('WHEAT')) AS allergen (type)
WHERE i.name = 'Flour'
ON CONFLICT DO NOTHING;

-- Sugar: NONE
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    'NONE'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Sugar'
ON CONFLICT DO NOTHING;

-- Salt: NONE
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    'NONE'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Salt'
ON CONFLICT DO NOTHING;

-- Whole Milk: MILK
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    'MILK'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Whole Milk'
ON CONFLICT DO NOTHING;

-- Butter: MILK
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    'MILK'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Butter'
ON CONFLICT DO NOTHING;

-- Eggs: EGGS
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    'EGGS'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Eggs'
ON CONFLICT DO NOTHING;

-- Peanut Butter: PEANUTS
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    'PEANUTS'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Peanut Butter'
ON CONFLICT DO NOTHING;

-- Soy Sauce: SOYBEANS, WHEAT, GLUTEN
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    allergen.type::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
CROSS JOIN (VALUES ('SOYBEANS'), ('WHEAT'), ('GLUTEN')) AS allergen (type)
WHERE i.name = 'Soy Sauce'
ON CONFLICT DO NOTHING;

-- Almond Milk: ALMONDS, TREE_NUTS
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    allergen.type::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
CROSS JOIN (VALUES ('ALMONDS'), ('TREE_NUTS')) AS allergen (type)
WHERE i.name = 'Almond Milk'
ON CONFLICT DO NOTHING;

-- Sesame Oil: SESAME
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    'SESAME'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Sesame Oil'
ON CONFLICT DO NOTHING;

-- Shrimp: SHELLFISH
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    'SHELLFISH'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Shrimp'
ON CONFLICT DO NOTHING;

-- Salmon: FISH
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    'FISH'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Salmon'
ON CONFLICT DO NOTHING;

-- Chocolate Chips: MILK (contains), TREE_NUTS (may contain), SOYBEANS (contains)
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score, source_notes
)
SELECT
    ap.allergen_profile_id,
    'MILK'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score,
    'Contains milk solids' AS source_notes
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Chocolate Chips'
ON CONFLICT DO NOTHING;

INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score, source_notes
)
SELECT
    ap.allergen_profile_id,
    'TREE_NUTS'::recipe_manager.allergen_enum AS allergen_type,
    'MAY_CONTAIN'::recipe_manager.presence_type_enum AS presence_type,
    0.7 AS confidence_score,
    'Manufactured on shared equipment' AS source_notes
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Chocolate Chips'
ON CONFLICT DO NOTHING;

INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score, source_notes
)
SELECT
    ap.allergen_profile_id,
    'SOYBEANS'::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score,
    'Contains soy lecithin as emulsifier' AS source_notes
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Chocolate Chips'
ON CONFLICT DO NOTHING;

-- Bread Crumbs: GLUTEN, WHEAT (contains), MILK (may contain)
INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score
)
SELECT
    ap.allergen_profile_id,
    allergen.type::recipe_manager.allergen_enum AS allergen_type,
    'CONTAINS'::recipe_manager.presence_type_enum AS presence_type,
    1.0 AS confidence_score
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
CROSS JOIN (VALUES ('GLUTEN'), ('WHEAT')) AS allergen (type)
WHERE i.name = 'Bread Crumbs'
ON CONFLICT DO NOTHING;

INSERT INTO recipe_manager.ingredient_allergens (
    allergen_profile_id, allergen_type, presence_type, confidence_score, source_notes
)
SELECT
    ap.allergen_profile_id,
    'MILK'::recipe_manager.allergen_enum AS allergen_type,
    'MAY_CONTAIN'::recipe_manager.presence_type_enum AS presence_type,
    0.6 AS confidence_score,
    'Some bread crumb formulations contain milk' AS source_notes
FROM recipe_manager.allergen_profiles AS ap
INNER JOIN recipe_manager.ingredients AS i ON ap.ingredient_id = i.ingredient_id
WHERE i.name = 'Bread Crumbs'
ON CONFLICT DO NOTHING;
