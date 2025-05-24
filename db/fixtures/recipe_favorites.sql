-- db/fixtures/recipe_favorites.sql
INSERT INTO recipe_manager.recipe_favorites (user_id, recipe_id, favorited_at)
VALUES ('11111111-1111-1111-1111-111111111111', 2, NOW()),
  ('22222222-2222-2222-2222-222222222222', 1, NOW());
