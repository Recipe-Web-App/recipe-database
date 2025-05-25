#!/bin/bash

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source .env
  set +o allexport
fi

# Set timestamp and filename
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$(dirname "$0")/../db/backups"
BACKUP_FILE="$BACKUP_DIR/recipe_backup_$DATE.sql"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

echo "🚀 Finding PostgreSQL pod in namespace recipe-db..."
POD_NAME=$(kubectl get pods -n recipe-db -l app=postgres -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo "❌ No PostgreSQL pod found in namespace recipe-db with label app=postgres"
  exit 1
fi

echo "📦 Creating backup from pod '$POD_NAME' into local file '$BACKUP_FILE'..."

if kubectl exec -n recipe-db "$POD_NAME" -- \
  bash -c "PGPASSWORD='$POSTGRES_PASSWORD' pg_dump -U '$POSTGRES_USER' -d '$POSTGRES_DB' -n recipe_manager" > "$BACKUP_FILE"; then
  echo "✅ Backup completed successfully."
else
  echo "❌ Backup failed."
  exit 1
fi
