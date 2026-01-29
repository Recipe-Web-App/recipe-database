#!/bin/bash
# scripts/dbManagement/backup-db.sh
# Full database backup via direct NodePort connection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_db-common.sh
source "$SCRIPT_DIR/_db-common.sh"

print_separator "="
log_info "Loading environment variables..."
print_separator "-"

load_env

# Verify required tools
require_commands psql pg_dump || exit 1

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$LOCAL_PATH/db/data/backups"
BACKUP_FILE="$BACKUP_DIR/recipe_backup_$DATE.sql.gz"

mkdir -p "$BACKUP_DIR"
log_info "Backup directory: $BACKUP_DIR"

print_separator "="
log_info "Creating database backup..."
print_separator "-"
log_info "Host: $POSTGRES_HOST:$POSTGRES_PORT"
log_info "Database: $POSTGRES_DB"
log_info "Schema: $POSTGRES_SCHEMA"
log_info "Output: $BACKUP_FILE"
print_separator "-"

# Check connection first
check_db_connection || exit 1

# Run pg_dump directly via NodePort
if PGPASSWORD="$DB_MAINT_PASSWORD" pg_dump \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$DB_MAINT_USER" \
  -d "$POSTGRES_DB" \
  -n "$POSTGRES_SCHEMA" \
  --no-owner \
  --no-acl | gzip >"$BACKUP_FILE"; then
  log_success "Backup completed successfully."
  log_info "File size: $(du -h "$BACKUP_FILE" | cut -f1)"
else
  log_error "Backup failed."
  rm -f "$BACKUP_FILE"
  exit 1
fi

print_separator "="
