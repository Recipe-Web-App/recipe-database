-- db/init/schema/008_create_recipe_ingredients_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_ingredients (
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes (
    recipe_id
  ) ON DELETE CASCADE,
  ingredient_id BIGINT NOT NULL REFERENCES recipe_manager.ingredients (
    ingredient_id
  ),
  quantity NUMERIC(8, 3),
  unit recipe_manager.INGREDIENT_UNIT_ENUM,
  is_optional BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (recipe_id, ingredient_id)
);
