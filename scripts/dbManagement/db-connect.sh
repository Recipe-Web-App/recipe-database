#!/bin/bash
# scripts/dbManagement/db_connect.sh

set -euo pipefail

# Utility function for printing section separators
print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

NAMESPACE="recipe-db"
POD_LABEL="app=postgres"

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

DB_MAINT_USER=${DB_MAINT_USER:-}
POSTGRES_DB=${POSTGRES_DB:-}
DB_MAINT_PASSWORD=${DB_MAINT_PASSWORD:-}
POSTGRES_SCHEMA=${POSTGRES_SCHEMA:-public}

print_separator
if [ -z "$DB_MAINT_USER" ]; then
  read -rp "Enter DB user: " DB_MAINT_USER
fi

if [ -z "$POSTGRES_DB" ]; then
  read -rp "Enter DB name: " POSTGRES_DB
fi

if [ -z "$DB_MAINT_PASSWORD" ]; then
  read -s -rp "Enter DB password: " DB_MAINT_PASSWORD
  echo
fi

print_separator
echo "🚀 Finding PostgreSQL pod in namespace $NAMESPACE..."
print_separator

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo "❌ No PostgreSQL pod found in namespace $NAMESPACE with label $POD_LABEL"
  exit 1
fi

echo "✅ Found pod: $POD_NAME"

print_separator
echo "📂 Defaulting to schema: $POSTGRES_SCHEMA"
echo "🔐 Starting psql client inside pod..."
print_separator

kubectl exec -it -n "$NAMESPACE" "$POD_NAME" -- \
  env PGOPTIONS="--search_path=$POSTGRES_SCHEMA" \
  PGPASSWORD="$DB_MAINT_PASSWORD" \
  psql -U "$DB_MAINT_USER" -d "$POSTGRES_DB"

print_separator
echo "✅ psql session ended."
print_separator
