#!/bin/bash
# scripts/jobHelpers/db-load-schemas.sh

set -euo pipefail

export PGPASSWORD="$POSTGRES_PASSWORD"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "POSTGRES_HOST: $POSTGRES_HOST"
echo "POSTGRES_DB:   $POSTGRES_DB"
echo "POSTGRES_USER: $POSTGRES_USER"

function execute_sql_files() {
  local dir=$1
  local label=$2
  local status=0

  print_separator "="
  echo "🔧 $label..."
  shopt -s nullglob
  local files=("$dir"/*.sql)
  shopt -u nullglob

  if [ ${#files[@]} -eq 0 ]; then
    echo "ℹ️ No SQL files found in $dir"
    return 0
  fi

  for f in "${files[@]}"; do
    echo "⏳ Executing $f"
    # Run the pipeline and capture the exit status of psql
    envsubst <"$f" | psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB"
    rc=${PIPESTATUS[1]:-${PIPESTATUS[0]}}
    if [ "$rc" -ne 0 ]; then
      echo "❌ Error executing $f"
      status=$rc
    fi
    print_separator "-"
  done

  return "$status"
}

execute_sql_files "/app/sql/init/schema" "Initializing schema"
execute_sql_files "/app/sql/init/functions" "Loading functions"
execute_sql_files "/app/sql/init/triggers" "Creating triggers"
execute_sql_files "/app/sql/init/views" "Creating views"
execute_sql_files "/app/sql/init/users" "Creating users"

print_separator "="
echo "✅ Database initialization complete."
print_separator "="
