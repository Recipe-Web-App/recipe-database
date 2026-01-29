#!/bin/bash
# scripts/dbManagement/backup-nutritional-data.sh
# Backup USDA nutrition data via direct NodePort connection

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
EXPORT_DIR="$LOCAL_PATH/db/data/exports"

# Tables to backup (USDA-based nutrition schema)
NUTRITION_TABLES=("nutrition_profiles" "macronutrients" "vitamins" "minerals")

mkdir -p "$BACKUP_DIR"
mkdir -p "$EXPORT_DIR"
log_info "Backup directory: $BACKUP_DIR"
log_info "Export directory: $EXPORT_DIR"

print_separator "="
log_info "Testing database connection..."
print_separator "-"

check_db_connection || exit 1

print_separator "="
log_info "Getting table statistics..."
print_separator "-"

for table in "${NUTRITION_TABLES[@]}"; do
  log_info "Table: $table"
  row_count=$(PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -t -c \
    "SELECT COUNT(*) FROM $POSTGRES_SCHEMA.$table;" 2>/dev/null | tr -d ' ' || echo "N/A")
  log_info "  Rows: $row_count"
done

# Count ingredients with nutrition data
log_info "Ingredients with nutrition data:"
count=$(PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
  -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -t -c \
  "SELECT COUNT(*) FROM $POSTGRES_SCHEMA.ingredients WHERE fdc_id IS NOT NULL;" 2>/dev/null | tr -d ' ' || echo "N/A")
log_info "  Count: $count"

print_separator "="
log_info "Creating nutrition data backup..."
print_separator "-"

BACKUP_FILE="$BACKUP_DIR/nutrition_data_backup_$DATE.sql"

# Build table arguments for pg_dump
TABLE_ARGS=""
for table in "${NUTRITION_TABLES[@]}"; do
  TABLE_ARGS="$TABLE_ARGS -t $POSTGRES_SCHEMA.$table"
done

# shellcheck disable=SC2086
if PGPASSWORD="$DB_MAINT_PASSWORD" pg_dump \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$DB_MAINT_USER" \
  -d "$POSTGRES_DB" \
  $TABLE_ARGS \
  --data-only \
  --column-inserts >"$BACKUP_FILE"; then
  log_success "Data backup completed."
else
  log_error "Data backup failed."
  exit 1
fi

print_separator "="
log_info "Creating nutrition schema export..."
print_separator "-"

SCHEMA_FILE="$EXPORT_DIR/nutrition_schema_$DATE.sql"

# shellcheck disable=SC2086
if PGPASSWORD="$DB_MAINT_PASSWORD" pg_dump \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$DB_MAINT_USER" \
  -d "$POSTGRES_DB" \
  $TABLE_ARGS \
  --schema-only >"$SCHEMA_FILE"; then
  log_success "Schema export completed."
else
  log_error "Schema export failed."
  exit 1
fi

print_separator "="
log_info "Compressing files..."
print_separator "-"

if gzip "$BACKUP_FILE"; then
  log_success "Data backup compressed: $(basename "$BACKUP_FILE").gz"
else
  log_warning "Failed to compress data backup"
fi

if gzip "$SCHEMA_FILE"; then
  log_success "Schema export compressed: $(basename "$SCHEMA_FILE").gz"
else
  log_warning "Failed to compress schema export"
fi

print_separator "="
log_info "Cleaning up old files (keeping last 5)..."
print_separator "-"

# Clean up old backups (keep 5 most recent)
find "$BACKUP_DIR" -maxdepth 1 -name 'nutrition_data_backup_*.sql.gz' -print0 | sort -rz | tail -zn +6 | xargs -0 rm -f 2>/dev/null || true
find "$EXPORT_DIR" -maxdepth 1 -name 'nutrition_schema_*.sql.gz' -print0 | sort -rz | tail -zn +6 | xargs -0 rm -f 2>/dev/null || true

# Clean up legacy files if they exist
find "$BACKUP_DIR" -maxdepth 1 -name 'nutritional_info_backup_*.sql.gz' -print0 | xargs -0 rm -f 2>/dev/null || true
find "$EXPORT_DIR" -maxdepth 1 -name 'nutritional_info_schema_*.sql.gz' -print0 | xargs -0 rm -f 2>/dev/null || true

REMAINING_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -name 'nutrition_data_backup_*.sql.gz' 2>/dev/null | wc -l)
REMAINING_EXPORTS=$(find "$EXPORT_DIR" -maxdepth 1 -name 'nutrition_schema_*.sql.gz' 2>/dev/null | wc -l)
log_info "Data backups remaining: $REMAINING_BACKUPS"
log_info "Schema exports remaining: $REMAINING_EXPORTS"

print_separator "="
log_success "Nutrition data backup completed successfully!"
log_info "Data backup: $BACKUP_DIR/$(basename "$BACKUP_FILE").gz"
log_info "Schema export: $EXPORT_DIR/$(basename "$SCHEMA_FILE").gz"
log_info "Backup completed at: $(date)"
print_separator "="
