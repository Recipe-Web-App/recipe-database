-- db/init/schema/010_create_recipe_revisions_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.recipe_revisions (
  revision_id BIGSERIAL PRIMARY KEY,
  recipe_id BIGINT NOT NULL REFERENCES recipe_manager.recipes (
    recipe_id
  ) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES recipe_manager.users (user_id),
  revision_category recipe_manager.REVISION_CATEGORY_ENUM NOT NULL,
  revision_type recipe_manager.REVISION_TYPE_ENUM NOT NULL,
  previous_data JSONB NOT NULL,
  new_data JSONB NOT NULL,
  change_comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
