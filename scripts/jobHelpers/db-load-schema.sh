#!/bin/bash
# scripts/jobHelpers/db-load-schemas.sh

set -euo pipefail

export PGPASSWORD="$DB_MAINT_PASSWORD"

print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

echo "POSTGRES_HOST: $POSTGRES_HOST"
echo "POSTGRES_DB:   $POSTGRES_DB"
echo "DB_MAINT_USER: $DB_MAINT_USER"

execute_sql_files() {
  local dir=$1
  local label=$2

  print_separator
  echo "🔧 $label..."
  shopt -s nullglob
  local files=("$dir"/*.sql)
  shopt -u nullglob

  if [ ${#files[@]} -eq 0 ]; then
    echo "ℹ️ No SQL files found in $dir"
    return
  fi

  for f in "${files[@]}"; do
    echo "⏳ Executing $f"
    envsubst < "$f" | psql -h "$POSTGRES_HOST" -U "$DB_MAINT_USER" -d "$POSTGRES_DB"
  done
}

execute_sql_files "/sql/init/schema" "Initializing schema"
execute_sql_files "/sql/init/functions" "Loading functions"
execute_sql_files "/sql/init/triggers" "Creating triggers"
execute_sql_files "/sql/init/views" "Creating views"
execute_sql_files "/sql/init/users" "Creating users"

print_separator
echo "✅ Database initialization complete."
print_separator
