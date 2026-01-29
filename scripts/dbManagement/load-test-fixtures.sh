#!/bin/bash
# scripts/dbManagement/load-test-fixtures.sh
# Load test fixtures via direct NodePort connection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_db-common.sh
source "$SCRIPT_DIR/_db-common.sh"

print_separator "="
log_info "Loading Test Fixtures"
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
log_info "User: $DB_MAINT_USER"
print_separator "-"

# Check connection first
check_db_connection || exit 1

FIXTURES_DIR="$LOCAL_PATH/db/fixtures"

print_separator "="
log_info "Seeding test fixtures from $FIXTURES_DIR"
print_separator "-"

shopt -s nullglob
fixtures=("$FIXTURES_DIR"/*.sql)
shopt -u nullglob

if [[ ${#fixtures[@]} -eq 0 ]]; then
  log_info "No fixture files found in $FIXTURES_DIR. Nothing to seed."
  print_separator "="
  exit 0
fi

FAILED=0

for f in "${fixtures[@]}"; do
  log_info "Seeding $(basename "$f")..."
  if envsubst <"$f" | PGPASSWORD="$DB_MAINT_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$DB_MAINT_USER" \
    -d "$POSTGRES_DB" \
    -v ON_ERROR_STOP=1 >/dev/null 2>&1; then
    log_success "  $(basename "$f") completed"
  else
    log_error "  $(basename "$f") failed"
    # Show error details
    envsubst <"$f" | PGPASSWORD="$DB_MAINT_PASSWORD" psql \
      -h "$POSTGRES_HOST" \
      -p "$POSTGRES_PORT" \
      -U "$DB_MAINT_USER" \
      -d "$POSTGRES_DB" 2>&1 | tail -10
    FAILED=1
  fi
done

print_separator "="

if [[ $FAILED -eq 0 ]]; then
  log_success "Test fixture seeding complete."
else
  log_error "Test fixture seeding completed with errors."
fi

print_separator "="
exit $FAILED
