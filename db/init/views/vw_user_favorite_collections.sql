-- db/init/views/vw_user_favorite_collections.sql
CREATE OR REPLACE VIEW recipe_manager.vw_user_collection_favorites AS
SELECT
  u.user_id,
  u.username,
  c.collection_id,
  c.name,
  c.visibility,
  f.favorited_at
FROM recipe_manager.users AS u
INNER JOIN recipe_manager.collection_favorites AS f ON u.user_id = f.user_id
INNER JOIN recipe_manager.recipe_collections AS c ON f.collection_id = c.collection_id;
