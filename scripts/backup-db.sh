#!/bin/bash

# Load environment variables
set -o allexport
# Load .env vars into shell variables safely
if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env
fi
set +o allexport

# Set timestamp and filename
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$(dirname "$0")"
BACKUP_FILE="$BACKUP_DIR/recipe_backup_$DATE.sql"

# Dump only the recipe_manager schema
echo "Creating backup at $BACKUP_FILE..."

# Check if successful
if PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
  -h "$POSTGRES_HOST" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -n recipe_manager \
  -F p \
  -f "$BACKUP_FILE"; then
  echo "✅ Backup completed successfully."
else
  echo "❌ Backup failed."
  exit 1
fi
