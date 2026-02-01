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
        ('1 cup', 'CUP'::recipe_manager.ingredient_unit_enum, NULL::varchar, 200.0, 1, 'MANUAL'),
        ('1 tbsp', 'TBSP'::recipe_manager.ingredient_unit_enum, NULL::varchar, 12.5, 2, 'MANUAL'),
        ('1 tsp', 'TSP'::recipe_manager.ingredient_unit_enum, NULL::varchar, 4.2, 3, 'MANUAL')
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
        ('1 tbsp', 'TBSP'::recipe_manager.ingredient_unit_enum, NULL::varchar, 18.0, 1, 'MANUAL'),
        ('1 tsp', 'TSP'::recipe_manager.ingredient_unit_enum, NULL::varchar, 6.0, 2, 'MANUAL'),
        ('1 dash', 'PIECE'::recipe_manager.ingredient_unit_enum, 'dash', 0.4, 3, 'MANUAL')
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
        ('1 cup', 'CUP'::recipe_manager.ingredient_unit_enum, NULL::varchar, 125.0, 1, 'MANUAL'),
        ('1 cup, sifted', 'CUP'::recipe_manager.ingredient_unit_enum, 'sifted', 115.0, 2, 'MANUAL'),
        ('1 tbsp', 'TBSP'::recipe_manager.ingredient_unit_enum, NULL::varchar, 7.8, 3, 'MANUAL')
) AS v (portion_description, unit, modifier, gram_weight, sequence_number, data_source)
WHERE i.name = 'Flour'
ON CONFLICT (ingredient_id, portion_description) DO NOTHING;
