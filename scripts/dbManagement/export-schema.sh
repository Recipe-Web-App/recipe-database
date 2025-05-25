#!/bin/bash
set -euo pipefail

NAMESPACE="recipe-db"
EXPORT_PATH="./data/schema.sql"

# Load env vars from .env
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source .env
  set +o allexport
fi

echo "📦 Exporting schema from PostgreSQL pod..."

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath="{.items[0].metadata.name}")

kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash -c \
  "PGPASSWORD='$POSTGRES_PASSWORD' pg_dump -U $POSTGRES_USER -d $POSTGRES_DB --schema-only" > "$EXPORT_PATH"

echo "✅ Schema exported to: $EXPORT_PATH"
