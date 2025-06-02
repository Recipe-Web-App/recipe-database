#!/bin/bash
# scripts/dbManagement/export-schema.sh

set -euo pipefail

# Utility function for printing section separators
print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

NAMESPACE="recipe-db"
EXPORT_PATH="./data/schema.sql"

print_separator
echo "📥 Loading environment variables..."
print_separator

if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source .env
  set +o allexport
  echo "✅ Environment variables loaded."
else
  echo "ℹ️ No .env file found. Proceeding without loading environment variables."
fi

print_separator
echo "📦 Exporting schema from PostgreSQL pod in namespace '$NAMESPACE'..."
print_separator

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo "❌ No PostgreSQL pod found in namespace '$NAMESPACE' with label app=postgres"
  exit 1
fi

mkdir -p "$(dirname "$EXPORT_PATH")"

if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash -c \
  "PGPASSWORD='$DB_MAINT_PASSWORD' pg_dump -U $DB_MAINT_USER -d $POSTGRES_DB --schema-only" > "$EXPORT_PATH"; then
  echo "✅ Schema exported successfully to: $EXPORT_PATH"
else
  echo "❌ Failed to export schema."
  exit 1
fi

print_separator
