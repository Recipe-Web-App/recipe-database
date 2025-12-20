#!/bin/bash
# scripts/dbManagement/backup-db.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "📥 Loading environment variables..."
print_separator "-"

# Load environment variables if .env exists
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source .env
  set +o allexport
  echo "✅ Environment variables loaded."
else
  echo "ℹ️ No .env file found. Proceeding without loading environment variables."
fi

print_separator "="
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$(dirname "$0")/../../db/data/backups"
BACKUP_FILE="$BACKUP_DIR/recipe_backup_$DATE.sql"

mkdir -p "$BACKUP_DIR"
echo "📁 Backup directory ensured at: $BACKUP_DIR"

print_separator "="
echo "🚀 Finding PostgreSQL pod in namespace recipe-database..."
print_separator "-"

POD_NAME=$(kubectl get pods -n recipe-database -l app=recipe-database -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo "❌ No PostgreSQL pod found in namespace recipe-database with label app=recipe-database"
  exit 1
fi

echo "✅ Found pod: $POD_NAME"

print_separator "="
echo "📦 Creating backup from pod '$POD_NAME' into local file '$BACKUP_FILE'..."
print_separator "-"

if kubectl exec -n recipe-database "$POD_NAME" -- \
  bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' pg_dump -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -n $POSTGRES_SCHEMA" >"$BACKUP_FILE"; then
  echo "✅ Backup completed successfully."
else
  echo "❌ Backup failed."
  exit 1
fi

print_separator "="
