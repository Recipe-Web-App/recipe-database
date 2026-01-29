#!/bin/bash
# scripts/dbManagement/db-connect.sh
# Interactive psql session via direct NodePort connection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_db-common.sh
source "$SCRIPT_DIR/_db-common.sh"

print_separator "="
log_info "Loading environment variables..."
print_separator "-"

load_env

# Verify required tools
require_commands psql || exit 1

print_separator "="
log_info "Connecting to PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT..."
print_separator "-"
log_info "Database: $POSTGRES_DB"
log_info "Schema: $POSTGRES_SCHEMA"
log_info "User: $DB_MAINT_USER"
print_separator "-"

# Interactive psql session with search_path set to schema
PGOPTIONS="-c search_path=$POSTGRES_SCHEMA" \
  PGPASSWORD="$DB_MAINT_PASSWORD" psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$DB_MAINT_USER" \
  -d "$POSTGRES_DB"

print_separator "="
log_success "psql session ended."
print_separator "="
