-- db/init/views/vw_user_favorite_recipe.sql
CREATE OR REPLACE VIEW recipe_manager.vw_user_recipe_favorites AS
SELECT u.user_id,
  u.username,
  r.recipe_id,
  r.title,
  f.favorited_at
FROM recipe_manager.users u
  JOIN recipe_manager.recipe_favorites f ON u.user_id = f.user_id
  JOIN recipe_manager.recipes r ON f.recipe_id = r.recipe_id;
