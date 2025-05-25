#!/bin/bash

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env
fi

FIXTURES_DIR="$(dirname "$0")/../db/fixtures"

echo "🚀 Finding PostgreSQL pod in namespace recipe-db..."
POD_NAME=$(kubectl get pods -n recipe-db -l app=postgres -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo "❌ No PostgreSQL pod found in namespace recipe-db with label app=postgres"
  exit 1
fi

echo "📦 Seeding fixtures from '$FIXTURES_DIR'..."

for f in "$FIXTURES_DIR"/*.sql; do
  echo "⏳ Seeding $(basename "$f")..."
  kubectl exec -i -n recipe-db "$POD_NAME" -- \
    bash -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U '$POSTGRES_USER' -d '$POSTGRES_DB'" < "$f"
done

echo "✅ Fixture seeding complete."
