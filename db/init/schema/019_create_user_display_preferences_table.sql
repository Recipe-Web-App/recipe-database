-- db/init/schema/019_create_user_display_preferences_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.user_display_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  font_size recipe_manager.FONT_SIZE_ENUM NOT NULL DEFAULT 'MEDIUM',
  color_scheme recipe_manager.COLOR_SCHEME_ENUM NOT NULL DEFAULT 'LIGHT',
  layout_density recipe_manager.LAYOUT_DENSITY_ENUM NOT NULL
  DEFAULT 'COMFORTABLE',
  show_images BOOLEAN NOT NULL DEFAULT true,
  compact_mode BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_display_preferences_user_id_unique UNIQUE (user_id)
);
