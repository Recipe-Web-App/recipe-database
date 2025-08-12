-- db/fixtures/001_users.sql
INSERT INTO recipe_manager.users (
  user_id,
  role,
  username,
  email,
  password_hash,
  full_name,
  bio,
  is_active,
  created_at,
  updated_at
)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'ADMIN',
  'chefanna',
  'anna@example.com',
  'hashed_pw_anna',
  'Anna Baker',
  'Love baking sourdough.',
  TRUE,
  NOW(),
  NOW()
),
(
  '22222222-2222-2222-2222-222222222222',
  'USER',
  'foodlover',
  'bob@example.com',
  'hashed_pw_bob',
  'Bob Cook',
  'Trying new cuisines.',
  TRUE,
  NOW(),
  NOW()
);
