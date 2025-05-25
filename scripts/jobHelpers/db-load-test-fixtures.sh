#!/bin/bash
# scripts/jobHelpers/db-load-test-fixtures.sh

set -euo pipefail

export PGPASSWORD="$POSTGRES_PASSWORD"

FIXTURES_DIR="sql/fixtures"

print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

echo "POSTGRES_HOST: $POSTGRES_HOST"
echo "POSTGRES_DB:   $POSTGRES_DB"
echo "POSTGRES_USER: $POSTGRES_USER"

print_separator
echo "📦 Seeding test fixtures from $FIXTURES_DIR"
print_separator

shopt -s nullglob
fixtures=("$FIXTURES_DIR"/*.sql)
shopt -u nullglob

if [ ${#fixtures[@]} -eq 0 ]; then
  echo "ℹ️ No fixture files found in $FIXTURES_DIR. Nothing to seed."
  print_separator
  exit 0
fi

for f in "${fixtures[@]}"; do
  echo "⏳ Seeding $(basename "$f")..."
  psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

print_separator
echo "✅ Test fixture seeding complete."
print_separator
