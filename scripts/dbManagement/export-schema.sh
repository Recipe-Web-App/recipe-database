#!/bin/bash
# scripts/dbManagement/export-schema.sh
# Export database schema via direct NodePort connection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_db-common.sh
source "$SCRIPT_DIR/_db-common.sh"

print_separator "="
log_info "Loading environment variables..."
print_separator "-"

load_env

# Verify required tools
require_commands pg_dump || exit 1

EXPORT_PATH="$LOCAL_PATH/db/data/exports/schema.sql"
mkdir -p "$(dirname "$EXPORT_PATH")"

print_separator "="
log_info "Exporting schema from PostgreSQL..."
print_separator "-"
log_info "Host: $POSTGRES_HOST:$POSTGRES_PORT"
log_info "Database: $POSTGRES_DB"
log_info "Output: $EXPORT_PATH"
print_separator "-"

# Check connection first
check_db_connection || exit 1

if PGPASSWORD="$DB_MAINT_PASSWORD" pg_dump \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$DB_MAINT_USER" \
  -d "$POSTGRES_DB" \
  --schema-only \
  --no-owner \
  --no-acl >"$EXPORT_PATH"; then
  log_success "Schema exported successfully to: $EXPORT_PATH"
  log_info "File size: $(du -h "$EXPORT_PATH" | cut -f1)"
else
  log_error "Failed to export schema."
  exit 1
fi

print_separator "="
