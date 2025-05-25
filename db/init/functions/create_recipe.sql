-- db/init/functions/create_recipe.sql
CREATE OR REPLACE FUNCTION recipe_manager.create_recipe(
    p_user_id BIGINT,
    p_title VARCHAR,
    p_description TEXT,
    p_servings NUMERIC,
    p_prep_time INT,
    p_cook_time INT,
    p_difficulty VARCHAR,
    p_origin_url TEXT,
    p_ingredients JSONB -- format: [{ingredient_id: int, quantity: numeric, unit: text, is_optional: bool}, ...]
  ) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_recipe_id BIGINT;
v_ingredient RECORD;
BEGIN -- Insert into recipes table
INSERT INTO recipe_manager.recipes (
    user_id,
    title,
    description,
    servings,
    preparation_time,
    cooking_time,
    difficulty,
    origin_url,
    created_at,
    updated_at
  )
VALUES (
    p_user_id,
    p_title,
    p_description,
    p_servings,
    p_prep_time,
    p_cook_time,
    p_difficulty,
    p_origin_url,
    now(),
    now()
  )
RETURNING recipe_id INTO v_recipe_id;
-- Insert ingredients into recipe_ingredients
FOR v_ingredient IN
SELECT *
FROM jsonb_to_recordset(p_ingredients) AS (
    ingredient_id BIGINT,
    quantity NUMERIC,
    unit VARCHAR,
    is_optional BOOLEAN
  ) LOOP
INSERT INTO recipe_manager.recipe_ingredients (
    recipe_id,
    ingredient_id,
    quantity,
    unit,
    is_optional
  )
VALUES (
    v_recipe_id,
    v_ingredient.ingredient_id,
    v_ingredient.quantity,
    v_ingredient.unit,
    COALESCE(v_ingredient.is_optional, FALSE)
  );
END LOOP;
RETURN v_recipe_id;
END;
$$;
