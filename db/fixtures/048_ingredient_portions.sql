-- db/fixtures/048_ingredient_portions.sql
-- Sample ingredient portion weights for test ingredients
-- Values based on USDA FoodData Central portion data

-- Sugar portions (fdc_id: 169655)
INSERT INTO recipe_manager.ingredient_portions (
    ingredient_id, portion_description, unit, modifier, gram_weight,
    sequence_number, data_source
)
SELECT
    i.ingredient_id,
    v.portion_description,
    v.unit,
    v.modifier,
    v.gram_weight,
    v.sequence_number,
    v.data_source
FROM recipe_manager.ingredients AS i
CROSS JOIN (
    VALUES
        ('1 cup', 'CUP', NULL::VARCHAR, 200.0, 1, 'MANUAL'),
        ('1 tbsp', 'TBSP', NULL::VARCHAR, 12.5, 2, 'MANUAL'),
        ('1 tsp', 'TSP', NULL::VARCHAR, 4.2, 3, 'MANUAL')
) AS v (portion_description, unit, modifier, gram_weight, sequence_number, data_source)
WHERE i.name = 'Sugar'
ON CONFLICT (ingredient_id, portion_description) DO NOTHING;

-- Salt portions (fdc_id: 173468)
INSERT INTO recipe_manager.ingredient_portions (
    ingredient_id, portion_description, unit, modifier, gram_weight,
    sequence_number, data_source
)
SELECT
    i.ingredient_id,
    v.portion_description,
    v.unit,
    v.modifier,
    v.gram_weight,
    v.sequence_number,
    v.data_source
FROM recipe_manager.ingredients AS i
CROSS JOIN (
    VALUES
        ('1 tbsp', 'TBSP', NULL::VARCHAR, 18.0, 1, 'MANUAL'),
        ('1 tsp', 'TSP', NULL::VARCHAR, 6.0, 2, 'MANUAL'),
        ('1 dash', 'PIECE', 'dash', 0.4, 3, 'MANUAL')
) AS v (portion_description, unit, modifier, gram_weight, sequence_number, data_source)
WHERE i.name = 'Salt'
ON CONFLICT (ingredient_id, portion_description) DO NOTHING;

-- Flour portions (fdc_id: 169761)
INSERT INTO recipe_manager.ingredient_portions (
    ingredient_id, portion_description, unit, modifier, gram_weight,
    sequence_number, data_source
)
SELECT
    i.ingredient_id,
    v.portion_description,
    v.unit,
    v.modifier,
    v.gram_weight,
    v.sequence_number,
    v.data_source
FROM recipe_manager.ingredients AS i
CROSS JOIN (
    VALUES
        ('1 cup', 'CUP', NULL::VARCHAR, 125.0, 1, 'MANUAL'),
        ('1 cup, sifted', 'CUP', 'sifted', 115.0, 2, 'MANUAL'),
        ('1 tbsp', 'TBSP', NULL::VARCHAR, 7.8, 3, 'MANUAL')
) AS v (portion_description, unit, modifier, gram_weight, sequence_number, data_source)
WHERE i.name = 'Flour'
ON CONFLICT (ingredient_id, portion_description) DO NOTHING;
