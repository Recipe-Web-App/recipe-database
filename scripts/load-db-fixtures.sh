#!/bin/bash

set -euo pipefail

export PGPASSWORD="$POSTGRES_PASSWORD"

echo "📦 Seeding fixtures"

for f in sql/fixtures/*.sql; do
  echo "⏳ Seeding $(basename "$f")..."
  psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

echo "✅ Fixture seeding complete."
