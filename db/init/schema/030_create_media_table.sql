-- db/init/schema/030_create_media_table.sql
CREATE TABLE IF NOT EXISTS recipe_manager.media (
  media_id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES recipe_manager.users (
    user_id
  ) ON DELETE CASCADE,
  media_type recipe_manager.MEDIA_TYPE_ENUM NOT NULL,
  media_path TEXT NOT NULL,
  file_size BIGINT,
  content_hash VARCHAR(64),
  original_filename TEXT,
  processing_status recipe_manager.PROCESSING_STATUS_ENUM NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_media_user_id
ON recipe_manager.media (user_id);

CREATE INDEX IF NOT EXISTS idx_media_media_type
ON recipe_manager.media (media_type);
