-- db/fixtures/recipes.sql
INSERT INTO recipe_manager.recipes (
    recipe_id,
    user_id,
    title,
    description,
    servings,
    preparation_time,
    cooking_time,
    difficulty,
    origin_url,
    created_at,
    updated_at
  )
VALUES (
    DEFAULT,
    '11111111-1111-1111-1111-111111111111',
    'Classic Pancakes',
    'Fluffy homemade pancakes.',
    4,
    10,
    20,
    'Easy',
    'https://example.com/classic-pancakes',
    NOW(),
    NOW()
  ),
  (
    DEFAULT,
    '22222222-2222-2222-2222-222222222222',
    'Spaghetti Carbonara',
    'Rich Italian pasta dish.',
    2,
    15,
    15,
    'Medium',
    'https://example.com/spaghetti-carbonara',
    NOW(),
    NOW()
  );
