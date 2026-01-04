-- db/init/views/vw_user_favorite_meal_plans.sql
CREATE OR REPLACE VIEW recipe_manager.vw_user_meal_plan_favorites AS
SELECT
  u.user_id,
  u.username,
  m.meal_plan_id,
  m.name,
  m.start_date,
  m.end_date,
  f.favorited_at
FROM recipe_manager.users AS u
INNER JOIN recipe_manager.meal_plan_favorites AS f ON u.user_id = f.user_id
INNER JOIN recipe_manager.meal_plans AS m ON f.meal_plan_id = m.meal_plan_id;
