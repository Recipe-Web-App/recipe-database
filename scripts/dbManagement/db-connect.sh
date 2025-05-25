#!/bin/bash
# scripts/dbManagement/db_connect.sh

set -euo pipefail

# Utility function for printing section separators
print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

NAMESPACE="recipe-db"
POD_LABEL="app=postgres"
LOCAL_PORT=15432

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

POSTGRES_USER=${POSTGRES_USER:-}
POSTGRES_DB=${POSTGRES_DB:-}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-}
POSTGRES_SCHEMA=${POSTGRES_SCHEMA:-public}

print_separator
if [ -z "$POSTGRES_USER" ]; then
  read -rp "Enter DB user: " POSTGRES_USER
fi

if [ -z "$POSTGRES_DB" ]; then
  read -rp "Enter DB name: " POSTGRES_DB
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
  read -s -rp "Enter DB password: " POSTGRES_PASSWORD
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
echo "🔌 Port-forwarding pod $POD_NAME to localhost:$LOCAL_PORT ..."
kubectl port-forward -n "$NAMESPACE" pod/"$POD_NAME" $LOCAL_PORT:5432 &
PF_PID=$!

sleep 3 # give port-forward time to start

print_separator
echo "📂 Defaulting to schema: $POSTGRES_SCHEMA"
echo "🔐 Starting psql client..."
print_separator

PGOPTIONS="--search_path=$POSTGRES_SCHEMA" \
  PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -h localhost -p "$LOCAL_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB"

print_separator
echo "🛑 Closing port-forward (PID $PF_PID)..."
kill "$PF_PID"
print_separator
