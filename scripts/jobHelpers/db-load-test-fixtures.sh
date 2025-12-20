#!/bin/bash
# scripts/jobHelpers/db-load-test-fixtures.sh

set -euo pipefail

export PGPASSWORD="$DB_MAINT_PASSWORD"

FIXTURES_DIR="/app/sql/fixtures"

function print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

print_separator "="
echo "POSTGRES_HOST: $POSTGRES_HOST"
echo "POSTGRES_DB:   $POSTGRES_DB"
echo "DB_MAINT_USER: $DB_MAINT_USER"

print_separator "="
echo "📦 Seeding test fixtures from $FIXTURES_DIR"
print_separator "-"

shopt -s nullglob
fixtures=("$FIXTURES_DIR"/*.sql)
shopt -u nullglob

if [ ${#fixtures[@]} -eq 0 ]; then
  echo "ℹ️ No fixture files found in $FIXTURES_DIR. Nothing to seed."
  print_separator "-"
  exit 0
fi

for f in "${fixtures[@]}"; do
  print_separator "="
  echo "⏳ Seeding $(basename "$f")..."
  print_separator "-"
  envsubst <"$f" | psql -h "$POSTGRES_HOST" -U "$DB_MAINT_USER" -d "$POSTGRES_DB"
done

print_separator "="
echo "✅ Test fixture seeding complete."
print_separator "="
