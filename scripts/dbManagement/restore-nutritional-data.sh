#!/bin/bash
# scripts/dbManagement/restore-nutritional-data.sh
# Restore USDA nutrition data from backup via direct NodePort connection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_db-common.sh
source "$SCRIPT_DIR/_db-common.sh"

# Tables to restore (USDA-based nutrition schema)
NUTRITION_TABLES=("nutrition_profiles" "macronutrients" "vitamins" "minerals")

# Default options
BACKUP_DATE=""
SCHEMA_ONLY=false
DATA_ONLY=false
TRUNCATE_FIRST=false

# Function to get latest backup date
function get_latest_backup() {
  local backup_dir="$LOCAL_PATH/db/data/backups"
  local latest_backup
  latest_backup=$(find "$backup_dir" -maxdepth 1 -name 'nutrition_data_backup_*.sql.gz' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n 1)
  if [ -n "$latest_backup" ]; then
    basename "$latest_backup" | sed 's/nutrition_data_backup_\(.*\)\.sql\.gz/\1/'
  else
    echo ""
  fi
}

# Function to show usage
function show_usage() {
  local backup_dir="$LOCAL_PATH/db/data/backups"

  echo "Usage: $0 [OPTIONS] [backup_date]"
  echo ""
  echo "Options:"
  echo "  -s, --schema-only    Restore only table structure"
  echo "  -d, --data-only      Restore only data (tables must exist)"
  echo "  -t, --truncate       Truncate tables before restoring data"
  echo "  -h, --help           Show this help message"
  echo ""
  echo "If no backup_date is specified, the latest backup will be used."
  echo ""
  echo "Tables restored: ${NUTRITION_TABLES[*]}"
  echo ""
  echo "Examples:"
  echo "  $0                                    # Restore latest backup (schema + data)"
  echo "  $0 --data-only                        # Restore latest backup (data only)"
  echo "  $0 2025-06-17_14-30-22               # Restore specific backup"
  echo "  $0 --data-only 2025-06-17_14-30-22   # Restore specific backup (data only)"
  echo "  $0 --truncate --data-only             # Clear tables and restore latest data"
  echo ""
  echo "Available backups:"
  local backups
  backups=$(find "$backup_dir" -maxdepth 1 -name 'nutrition_data_backup_*.sql.gz' -print0 2>/dev/null |
    xargs -0 -n1 basename 2>/dev/null |
    sed 's/nutrition_data_backup_\(.*\)\.sql\.gz/  \1/' |
    sort -r)
  if [[ -n "$backups" ]]; then
    echo "$backups"
  else
    echo "  No backups found in $backup_dir"
  fi
}

print_separator "="
log_info "USDA Nutrition Data Restore"
print_separator "-"

log_info "Loading environment variables..."
load_env

# Set backup directories
BACKUP_DIR="$LOCAL_PATH/db/data/backups"
EXPORT_DIR="$LOCAL_PATH/db/data/exports"

log_info "Configuration:"
log_info "  Tables: ${NUTRITION_TABLES[*]}"
log_info "  Backup dir: $BACKUP_DIR"
log_info "  Database: $POSTGRES_HOST:$POSTGRES_PORT"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s | --schema-only)
      SCHEMA_ONLY=true
      shift
      ;;
    -d | --data-only)
      DATA_ONLY=true
      shift
      ;;
    -t | --truncate)
      TRUNCATE_FIRST=true
      shift
      ;;
    -h | --help)
      show_usage
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      show_usage
      exit 1
      ;;
    *)
      BACKUP_DATE="$1"
      shift
      ;;
  esac
done

# Validate mutually exclusive options
if [[ "$SCHEMA_ONLY" == "true" && "$DATA_ONLY" == "true" ]]; then
  log_error "--schema-only and --data-only cannot be used together"
  exit 1
fi

# Use latest backup if no date specified
if [ -z "$BACKUP_DATE" ]; then
  BACKUP_DATE=$(get_latest_backup)
  if [ -z "$BACKUP_DATE" ]; then
    log_error "No backups found in $BACKUP_DIR"
    exit 1
  fi
  log_info "No backup date specified, using latest: $BACKUP_DATE"
fi

# Validate backup files exist
SCHEMA_FILE="$EXPORT_DIR/nutrition_schema_$BACKUP_DATE.sql.gz"
DATA_FILE="$BACKUP_DIR/nutrition_data_backup_$BACKUP_DATE.sql.gz"

print_separator "="
log_info "Validating backup files..."
print_separator "-"

if [[ "$SCHEMA_ONLY" != "true" ]] && [ ! -f "$DATA_FILE" ]; then
  log_error "Data backup file not found: $DATA_FILE"
  exit 1
fi

if [[ "$DATA_ONLY" != "true" ]] && [ ! -f "$SCHEMA_FILE" ]; then
  log_error "Schema backup file not found: $SCHEMA_FILE"
  exit 1
fi

log_success "Backup files validated"
log_info "Using backup from: $BACKUP_DATE"

# Show what will be restored
if [[ "$SCHEMA_ONLY" == "true" ]]; then
  log_info "Will restore: Schema only"
elif [[ "$DATA_ONLY" == "true" ]]; then
  log_info "Will restore: Data only"
  if [[ "$TRUNCATE_FIRST" == "true" ]]; then
    log_warning "Tables will be truncated before restore"
  fi
else
  log_info "Will restore: Schema + Data"
fi

# Verify required tools
require_commands psql gunzip || exit 1

# Check database connection
check_db_connection || exit 1

# Function to truncate nutrition tables
function truncate_tables() {
  print_separator "="
  log_info "Truncating nutrition tables..."
  print_separator "-"

  # Truncate in reverse order due to foreign key constraints
  local tables_reversed=("minerals" "vitamins" "macronutrients" "nutrition_profiles")

  for table in "${tables_reversed[@]}"; do
    log_info "Truncating $POSTGRES_SCHEMA.$table..."
    if PGPASSWORD="$DB_MAINT_PASSWORD" psql \
      -h "$POSTGRES_HOST" \
      -p "$POSTGRES_PORT" \
      -U "$DB_MAINT_USER" \
      -d "$POSTGRES_DB" \
      -c "TRUNCATE TABLE $POSTGRES_SCHEMA.$table CASCADE;" >/dev/null 2>&1; then
      log_success "  $table truncated"
    else
      log_error "  Failed to truncate $table"
      return 1
    fi
  done

  log_success "All tables truncated"
}

# Function to restore schema
function restore_schema() {
  print_separator "="
  log_info "Restoring nutrition schema..."
  print_separator "-"
  log_info "Source: $SCHEMA_FILE"

  if gunzip -c "$SCHEMA_FILE" | PGPASSWORD="$DB_MAINT_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$DB_MAINT_USER" \
    -d "$POSTGRES_DB" \
    -v ON_ERROR_STOP=1 >/dev/null 2>&1; then
    log_success "Schema restored successfully"
  else
    log_error "Schema restore failed"
    # Show error details
    gunzip -c "$SCHEMA_FILE" | PGPASSWORD="$DB_MAINT_PASSWORD" psql \
      -h "$POSTGRES_HOST" \
      -p "$POSTGRES_PORT" \
      -U "$DB_MAINT_USER" \
      -d "$POSTGRES_DB" 2>&1 | tail -20
    return 1
  fi
}

# Function to restore data
function restore_data() {
  print_separator "="
  log_info "Restoring nutrition data..."
  print_separator "-"
  log_info "Source: $DATA_FILE"

  local file_size
  file_size=$(du -h "$DATA_FILE" | cut -f1)
  log_info "Backup size: $file_size"

  if gunzip -c "$DATA_FILE" | PGPASSWORD="$DB_MAINT_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$DB_MAINT_USER" \
    -d "$POSTGRES_DB" \
    -v ON_ERROR_STOP=1 >/dev/null 2>&1; then
    log_success "Data restored successfully"
  else
    log_error "Data restore failed"
    # Show error details
    gunzip -c "$DATA_FILE" | PGPASSWORD="$DB_MAINT_PASSWORD" psql \
      -h "$POSTGRES_HOST" \
      -p "$POSTGRES_PORT" \
      -U "$DB_MAINT_USER" \
      -d "$POSTGRES_DB" 2>&1 | tail -20
    return 1
  fi
}

# Function to show table counts
function show_table_counts() {
  print_separator "="
  log_info "Verifying restored data..."
  print_separator "-"

  for table in "${NUTRITION_TABLES[@]}"; do
    local count
    count=$(PGPASSWORD="$DB_MAINT_PASSWORD" psql \
      -h "$POSTGRES_HOST" \
      -p "$POSTGRES_PORT" \
      -U "$DB_MAINT_USER" \
      -d "$POSTGRES_DB" \
      -t -c "SELECT COUNT(*) FROM $POSTGRES_SCHEMA.$table;" 2>/dev/null | tr -d ' ')
    log_info "  $table: $count rows"
  done
}

# Main execution
function main() {
  local start_time
  start_time=$(date +%s)

  print_separator "="
  log_info "Starting nutritional data restore process..."
  print_separator "-"
  log_info "Started at: $(date)"

  # Truncate if requested
  if [[ "$TRUNCATE_FIRST" == "true" ]]; then
    truncate_tables || exit 1
  fi

  # Restore schema if not data-only
  if [[ "$DATA_ONLY" != "true" ]]; then
    restore_schema || exit 1
  fi

  # Restore data if not schema-only
  if [[ "$SCHEMA_ONLY" != "true" ]]; then
    restore_data || exit 1
  fi

  # Show table counts
  show_table_counts

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  print_separator "="
  log_success "Nutritional data restore completed!"
  log_info "Total time: ${duration}s"
  log_info "Finished at: $(date)"
  print_separator "="
}

# Handle interrupts gracefully
trap 'print_separator "-"; log_error "Script interrupted"; print_separator "="; exit 130' INT TERM

# Run main function
main
