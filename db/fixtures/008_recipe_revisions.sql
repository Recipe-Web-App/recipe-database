-- db/fixtures/008_recipe_revisions.sql
INSERT INTO recipe_manager.recipe_revisions (
  recipe_id,
  user_id,
  revision_category,
  revision_type,
  previous_data,
  new_data,
  change_comment,
  created_at
)
VALUES (
  (
    SELECT recipe_id
    FROM recipe_manager.recipes
    WHERE title = 'Classic Pancakes'
  ),
  '11111111-1111-1111-1111-111111111111',
  'ingredient',
  'UPDATE',
  '{"title": "Classic Pancakes", "ingredients": ["flour", "milk", "eggs"]}',
  '{"title": "Classic Pancakes",
    "ingredients": ["flour", "almond milk", "eggs"]}',
  'Switched milk to almond milk for dairy-free version',
  now() - interval '2 days'
),
(
  (
    SELECT recipe_id
    FROM recipe_manager.recipes
    WHERE title = 'Classic Pancakes'
  ),
  '11111111-1111-1111-1111-111111111111',
  'step',
  'DELETE',
  '{"step": "Add sugar to taste"}',
  '{}',
  'Removed sugar to make it healthier',
  now()
);
