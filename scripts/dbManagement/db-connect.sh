#!/bin/bash
# scripts/dbManagement/db_connect.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

NAMESPACE="recipe-database"
POD_LABEL="app=recipe-database"

print_separator "="
echo "📥 Loading environment variables..."
print_separator "-"

if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source .env
  set +o allexport
  echo "✅ Environment variables loaded."
else
  echo "ℹ️ No .env file found. Proceeding without loading environment variables."
fi

DB_MAINT_USER=${DB_MAINT_USER:-}
POSTGRES_DB=${POSTGRES_DB:-}
DB_MAINT_PASSWORD=${DB_MAINT_PASSWORD:-}
POSTGRES_SCHEMA=${POSTGRES_SCHEMA:-public}

print_separator "="
echo "🚀 Finding a running PostgreSQL pod in namespace $NAMESPACE..."
print_separator "-"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" \
    --field-selector=status.phase=Running \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)

if [ -z "$POD_NAME" ]; then
  echo "❌ No running PostgreSQL pod found in namespace $NAMESPACE with label $POD_LABEL"
  echo "   (Tip: Check 'kubectl get pods -n $NAMESPACE' to see pod status.)"
  exit 1
fi

echo "✅ Found pod: $POD_NAME"

print_separator "="
echo "📂 Defaulting to schema: $POSTGRES_SCHEMA"
echo "🔐 Starting psql client inside pod..."
print_separator "-"

kubectl exec -it -n "$NAMESPACE" "$POD_NAME" -- \
  env PGOPTIONS="--search_path=$POSTGRES_SCHEMA" \
  PGPASSWORD="$DB_MAINT_PASSWORD" \
  psql -U "$DB_MAINT_USER" -d "$POSTGRES_DB"

print_separator "="
echo "✅ psql session ended."
print_separator "="
