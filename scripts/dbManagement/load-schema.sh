#!/bin/bash
# scripts/dbManagement/load-schema.sh
# Load database schema via direct NodePort connection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_db-common.sh
source "$SCRIPT_DIR/_db-common.sh"

print_separator "="
log_info "Database Schema Initialization"
print_separator "-"

log_info "Loading environment variables..."
load_env

# Verify required tools
require_commands psql envsubst || exit 1

print_separator "="
log_info "Connection Details:"
print_separator "-"
log_info "Host: $POSTGRES_HOST:$POSTGRES_PORT"
log_info "Database: $POSTGRES_DB"
log_info "User: $POSTGRES_USER (admin)"
print_separator "-"

# Check connection first
check_db_connection "$POSTGRES_USER" "POSTGRES_PASSWORD" || exit 1

# SQL directories to process
SQL_BASE="$LOCAL_PATH/db/init"
SCHEMA_DIR="$SQL_BASE/schema"
FUNCTIONS_DIR="$SQL_BASE/functions"
TRIGGERS_DIR="$SQL_BASE/triggers"
VIEWS_DIR="$SQL_BASE/views"
USERS_DIR="$SQL_BASE/users"

# Function to execute all SQL files in a directory
function execute_sql_dir() {
  local dir="$1"
  local label="$2"
  local status=0

  print_separator "="
  log_info "$label..."

  shopt -s nullglob
  local files=("$dir"/*.sql)
  shopt -u nullglob

  if [[ ${#files[@]} -eq 0 ]]; then
    log_info "No SQL files found in $dir"
    return 0
  fi

  for f in "${files[@]}"; do
    log_info "Executing $(basename "$f")..."
    if envsubst <"$f" | PGPASSWORD="$POSTGRES_PASSWORD" psql \
      -h "$POSTGRES_HOST" \
      -p "$POSTGRES_PORT" \
      -U "$POSTGRES_USER" \
      -d "$POSTGRES_DB" \
      -v ON_ERROR_STOP=1 >/dev/null 2>&1; then
      log_success "  $(basename "$f") completed"
    else
      log_error "  $(basename "$f") failed"
      # Show error details
      envsubst <"$f" | PGPASSWORD="$POSTGRES_PASSWORD" psql \
        -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" 2>&1 | tail -20
      status=1
    fi
  done

  return "$status"
}

# Execute SQL files in order
OVERALL_STATUS=0

execute_sql_dir "$SCHEMA_DIR" "Initializing schema" || OVERALL_STATUS=1
execute_sql_dir "$FUNCTIONS_DIR" "Loading functions" || OVERALL_STATUS=1
execute_sql_dir "$TRIGGERS_DIR" "Creating triggers" || OVERALL_STATUS=1
execute_sql_dir "$VIEWS_DIR" "Creating views" || OVERALL_STATUS=1
execute_sql_dir "$USERS_DIR" "Creating users" || OVERALL_STATUS=1

print_separator "="

if [[ $OVERALL_STATUS -eq 0 ]]; then
  log_success "Database initialization complete."
else
  log_error "Database initialization completed with errors."
fi

print_separator "="
exit $OVERALL_STATUS
