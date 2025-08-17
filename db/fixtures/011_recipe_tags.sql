-- db/fixtures/011_recipe_tags.sql
INSERT INTO recipe_manager.recipe_tags (name)
VALUES ('Breakfast'),
('Italian'),
('Quick') ON CONFLICT (name) DO NOTHING;
