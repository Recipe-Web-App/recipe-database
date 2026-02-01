-- db/init/views/vw_ingredient_pricing_lookup.sql
-- Two-tier ingredient pricing lookup: ingredient-specific first, food group fallback
-- Use this view for shopping cost estimation in recipes

CREATE OR REPLACE VIEW recipe_manager.vw_ingredient_pricing_lookup AS
SELECT
    i.ingredient_id,
    i.name AS ingredient_name,
    np.food_group,
    ip.source_year,
    ip.notes AS ingredient_notes,
    fgp.notes AS food_group_notes,
    COALESCE(ip.price_per_100g, fgp.avg_price_per_100g) AS price_per_100g,
    COALESCE(ip.currency, fgp.currency, 'USD') AS currency,
    CASE
        WHEN ip.pricing_id IS NOT NULL THEN ip.data_source
        ELSE fgp.data_source
    END AS data_source,
    CASE
        WHEN ip.pricing_id IS NOT NULL THEN 'ingredient'
        ELSE 'food_group'
    END AS price_tier,
    COALESCE(ip.updated_at, fgp.updated_at) AS last_updated
FROM recipe_manager.ingredients AS i
LEFT JOIN recipe_manager.nutrition_profiles AS np
    ON i.ingredient_id = np.ingredient_id
LEFT JOIN recipe_manager.ingredient_pricing AS ip
    ON i.ingredient_id = ip.ingredient_id
LEFT JOIN recipe_manager.food_group_pricing AS fgp
    ON np.food_group = fgp.food_group;

COMMENT ON VIEW recipe_manager.vw_ingredient_pricing_lookup
IS 'Two-tier pricing lookup: ingredient-specific prices with food group fallback for cost estimation';
