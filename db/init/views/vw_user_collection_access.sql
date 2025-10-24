-- db/init/views/vw_user_collection_access.sql
CREATE OR REPLACE VIEW recipe_manager.vw_user_collection_access AS
SELECT DISTINCT
  c.collection_id,
  c.name,
  c.description,
  c.visibility,
  c.collaboration_mode,
  c.user_id AS owner_id,
  u.username AS owner_username,
  uca.user_id AS accessor_user_id,
  c.created_at,
  c.updated_at,
  CASE
    WHEN c.user_id = uca.user_id THEN 'OWNER'
    WHEN cc.user_id IS NOT NULL THEN 'COLLABORATOR'
    WHEN c.collaboration_mode = 'ALL_USERS' THEN 'ALL_USERS'
    WHEN c.visibility = 'PUBLIC' THEN 'VIEWER'
    ELSE 'UNKNOWN'
  END AS access_type
FROM recipe_manager.recipe_collections AS c
INNER JOIN recipe_manager.users AS u ON c.user_id = u.user_id
CROSS JOIN recipe_manager.users AS uca
LEFT JOIN recipe_manager.collection_collaborators AS cc
  ON c.collection_id = cc.collection_id
  AND uca.user_id = cc.user_id
WHERE
  -- User owns the collection
  c.user_id = uca.user_id
  -- User is a collaborator
  OR cc.user_id IS NOT NULL
  -- Collection allows all users
  OR c.collaboration_mode = 'ALL_USERS'
  -- Collection is public
  OR c.visibility = 'PUBLIC';
