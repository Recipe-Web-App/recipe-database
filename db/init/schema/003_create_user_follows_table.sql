-- db/init/schema/003_create_user_follows_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_follows (
  follower_id BIGINT NOT NULL REFERENCES recipe_manager.users(user_id) ON DELETE CASCADE,
  followee_id BIGINT NOT NULL REFERENCES recipe_manager.users(user_id) ON DELETE CASCADE,
  followed_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id)
);
