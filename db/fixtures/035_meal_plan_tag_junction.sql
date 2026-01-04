-- db/fixtures/035_meal_plan_tag_junction.sql
INSERT INTO recipe_manager.meal_plan_tag_junction (meal_plan_id, tag_id)
VALUES (
  (SELECT meal_plan_id FROM recipe_manager.meal_plans
WHERE name = 'Weekend Brunch'),
  (SELECT tag_id FROM recipe_manager.meal_plan_tags
WHERE name = 'Weekly')
) ON CONFLICT (meal_plan_id, tag_id) DO NOTHING;
-- Weekend Brunch tagged as Weekly
