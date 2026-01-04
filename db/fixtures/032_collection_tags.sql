-- db/fixtures/032_collection_tags.sql
INSERT INTO recipe_manager.collection_tags (name)
VALUES ('Favorites'),
('Seasonal'),
('Holiday'),
('Weeknight') ON CONFLICT (name) DO NOTHING;
