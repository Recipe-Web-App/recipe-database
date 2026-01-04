-- db/fixtures/034_meal_plan_tags.sql
INSERT INTO recipe_manager.meal_plan_tags (name)
VALUES ('Weekly'),
('Monthly'),
('Diet'),
('Budget') ON CONFLICT (name) DO NOTHING;
