-- db/init/views/vw_collection_summary.sql
CREATE OR REPLACE VIEW recipe_manager.vw_collection_summary AS
SELECT
  c.collection_id,
  c.name,
  c.description,
  c.visibility,
  c.collaboration_mode,
  c.created_at,
  c.updated_at,
  u.user_id AS owner_id,
  u.username AS owner_username,
  COUNT(DISTINCT ci.recipe_id) AS recipe_count,
  COUNT(DISTINCT cc.user_id) AS collaborator_count,
  COUNT(DISTINCT cf.user_id) AS favorites_count
FROM recipe_manager.recipe_collections AS c
INNER JOIN recipe_manager.users AS u ON c.user_id = u.user_id
LEFT JOIN recipe_manager.recipe_collection_items AS ci ON c.collection_id = ci.collection_id
LEFT JOIN recipe_manager.collection_collaborators AS cc ON c.collection_id = cc.collection_id
LEFT JOIN recipe_manager.collection_favorites AS cf ON c.collection_id = cf.collection_id
GROUP BY
  c.collection_id,
  u.user_id;
