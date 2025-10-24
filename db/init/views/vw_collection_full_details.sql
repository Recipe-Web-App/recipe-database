-- db/init/views/vw_collection_full_details.sql
CREATE OR REPLACE VIEW recipe_manager.vw_collection_full_details AS
SELECT
  c.collection_id,
  c.name AS collection_name,
  c.description AS collection_description,
  c.visibility,
  c.collaboration_mode,
  c.created_at AS collection_created_at,
  c.updated_at AS collection_updated_at,
  u.user_id AS owner_id,
  u.username AS owner_username,
  ci.recipe_id,
  r.title AS recipe_title,
  r.description AS recipe_description,
  ci.display_order,
  ci.added_at AS recipe_added_at,
  adder.user_id AS added_by_user_id,
  adder.username AS added_by_username
FROM recipe_manager.recipe_collections AS c
INNER JOIN recipe_manager.users AS u ON c.user_id = u.user_id
LEFT JOIN recipe_manager.recipe_collection_items AS ci ON c.collection_id = ci.collection_id
LEFT JOIN recipe_manager.recipes AS r ON ci.recipe_id = r.recipe_id
LEFT JOIN recipe_manager.users AS adder ON ci.added_by = adder.user_id
ORDER BY
  c.collection_id,
  ci.display_order;
