#!/bin/bash
# scripts/jobHelpers/db-restore-nutritional-data.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_separator "="
echo -e "${CYAN}🔄 Kubernetes Nutritional Data Restore Job${NC}"
print_separator "-"
SCRIPT_START_TIME=$(date +%s)
echo -e "${CYAN}📅 Started at: $(date)${NC}"
echo -e "${CYAN}🏗️  Pod: $HOSTNAME${NC}"
echo -e "${CYAN}🗃️  Database: $POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB${NC}"
echo -e "${CYAN}📁 Schema: $POSTGRES_SCHEMA${NC}"

# Parse options
SCHEMA_ONLY=false
DATA_ONLY=false
TRUNCATE=false

if [[ "${RESTORE_OPTIONS:-}" == *"--schema-only"* ]]; then
  SCHEMA_ONLY=true
fi
if [[ "${RESTORE_OPTIONS:-}" == *"--data-only"* ]]; then
  DATA_ONLY=true
fi
if [[ "${RESTORE_OPTIONS:-}" == *"--truncate"* ]]; then
  TRUNCATE=true
fi

echo -e "${CYAN}📋 Restore Configuration:${NC}"
echo "   • Backup Date: ${BACKUP_DATE:-latest}"
echo "   • Schema Only: $SCHEMA_ONLY"
echo "   • Data Only: $DATA_ONLY"
echo "   • Truncate: $TRUNCATE"
print_separator "-"

# Function to get latest backup if not specified
get_latest_backup() {
  local latest_backup
  latest_backup=$(ls -t /app/db/data/backups/nutritional_info_backup_*.sql.gz 2>/dev/null | head -n 1)
  if [ -n "$latest_backup" ]; then
    basename "$latest_backup" | sed 's/nutritional_info_backup_\(.*\)\.sql\.gz/\1/'
  else
    echo ""
  fi
}

# Use latest backup if not specified
if [ -z "${BACKUP_DATE:-}" ]; then
  BACKUP_DATE=$(get_latest_backup)
  if [ -z "$BACKUP_DATE" ]; then
    echo -e "${RED}❌ No backups found in /app/db/data/backups${NC}"
    print_separator "="
    exit 1
  fi
  echo -e "${CYAN}ℹ️  Using latest backup: $BACKUP_DATE${NC}"
fi

# Set file paths
SCHEMA_FILE="/app/db/data/exports/nutritional_info_schema_$BACKUP_DATE.sql.gz"
DATA_FILE="/app/db/data/backups/nutritional_info_backup_$BACKUP_DATE.sql.gz"

echo -e "${CYAN}🔍 Validating backup files...${NC}"

# Check if files exist
if [ "$SCHEMA_ONLY" = false ] && [ ! -f "$DATA_FILE" ]; then
  echo -e "${RED}❌ Data backup file not found: $DATA_FILE${NC}"
  print_separator "="
  exit 1
fi

if [ "$DATA_ONLY" = false ] && [ ! -f "$SCHEMA_FILE" ]; then
  echo -e "${RED}❌ Schema backup file not found: $SCHEMA_FILE${NC}"
  print_separator "="
  exit 1
fi

echo -e "${GREEN}✅ Backup files validated${NC}"

print_separator "="
echo -e "${CYAN}🔄 Starting restore process...${NC}"
print_separator "-"
execute_sql() {
  local sql="$1"
  local description="$2"
  
  echo -e "${CYAN}🔧 $description...${NC}"
  
  if PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -c "$sql" > /dev/null; then
    echo -e "${GREEN}✅ $description completed${NC}"
  else
    echo -e "${RED}❌ $description failed${NC}"
    exit 1
  fi
}

# Function to check if table exists
check_table_exists() {
  local exists
  exists=$(PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -t -c "
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = '$POSTGRES_SCHEMA' 
        AND table_name = 'nutritional_info'
      );
    " 2>/dev/null | tr -d ' \n\t')
  
  if [ "$exists" = "t" ]; then
    return 0
  else
    return 1
  fi
}

# Function to restore file with progress
restore_file_with_progress() {
  local file="$1"
  local description="$2"
  local ignore_errors="${3:-false}"
  local show_progress="${4:-false}"
  
  echo -e "${CYAN}📤 $description...${NC}"
  
  if [ "$show_progress" = "true" ]; then
    # Start restore in background
    if [ "$ignore_errors" = "true" ]; then
      gunzip -c "$file" | PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$DB_MAINT_USER" -d "$POSTGRES_DB" > /dev/null 2>&1 &
    else
      gunzip -c "$file" | PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$DB_MAINT_USER" -d "$POSTGRES_DB" > /dev/null &
    fi
    
    local restore_pid=$!
    local start_time=$(date +%s)
    
    echo -e "${CYAN}🔄 Monitoring restore progress...${NC}"
    
    # Monitor progress
    while kill -0 $restore_pid 2>/dev/null; do
      local current_rows
      current_rows=$(PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -t -c "
          SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
        " 2>/dev/null | tr -d ' \n\t' || echo "0")
      
      local elapsed=$(($(date +%s) - start_time))
      local mins=$((elapsed / 60))
      local secs=$((elapsed % 60))
      
      printf "${CYAN}📊 Rows restored: %s | Time elapsed: %02d:%02d${NC}\n" "$current_rows" "$mins" "$secs"
      sleep 5
    done
    
    wait $restore_pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
      local final_rows
      final_rows=$(PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -t -c "
          SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
        " 2>/dev/null | tr -d ' \n\t')
      
      local total_time=$(($(date +%s) - start_time))
      local total_mins=$((total_time / 60))
      local total_secs=$((total_time % 60))
      
      echo -e "${GREEN}✅ $description completed${NC}"
      echo -e "${CYAN}📊 Final row count: $final_rows${NC}"
      echo -e "${CYAN}⏱️  Total time: ${total_mins}m ${total_secs}s${NC}"
    else
      echo -e "${RED}❌ $description failed${NC}"
      exit 1
    fi
  else
    # Schema restore without progress
    if [ "$ignore_errors" = "true" ]; then
      local error_output
      error_output=$(gunzip -c "$file" | PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$DB_MAINT_USER" -d "$POSTGRES_DB" 2>&1)
      
      local filtered_errors
      filtered_errors=$(echo "$error_output" | grep -v "already exists" | grep -v "must be owner" | grep -v "no privileges were granted" || true)
      
      if [ -n "$filtered_errors" ]; then
        echo -e "${YELLOW}⚠️ Some schema restore issues (non-critical):${NC}"
        echo "$filtered_errors" | head -5
      fi
      
      echo -e "${GREEN}✅ $description completed (with expected warnings)${NC}"
    else
      if gunzip -c "$file" | PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$DB_MAINT_USER" -d "$POSTGRES_DB" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $description completed${NC}"
      else
        echo -e "${RED}❌ $description failed${NC}"
        exit 1
      fi
    fi
  fi
}

echo "=================================================================================="
echo -e "${CYAN}🔄 Starting restore process...${NC}"
echo "=================================================================================="

# Set search path
execute_sql "SET search_path TO $POSTGRES_SCHEMA;" "Setting search path"

# Get current table stats
if PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
  -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -t -c "
    SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
  " 2>/dev/null | tr -d ' \n\t'; then
  ROWS_BEFORE=$(PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -t -c "
      SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
    " 2>/dev/null | tr -d ' \n\t')
  echo -e "${CYAN}📊 Current rows in table: $ROWS_BEFORE${NC}"
else
  ROWS_BEFORE="N/A (table may not exist)"
  echo -e "${CYAN}📊 Current table status: $ROWS_BEFORE${NC}"
fi

# Restore schema if needed
if [ "$DATA_ONLY" = false ]; then
  echo ""
  print_separator "-"
  if check_table_exists; then
    echo -e "${YELLOW}ℹ️ Table nutritional_info already exists, skipping schema restore${NC}"
  else
    echo -e "${CYAN}📋 Table doesn't exist, creating from schema...${NC}"
    restore_file_with_progress "$SCHEMA_FILE" "Restoring table schema" "true" "false"
  fi
fi

# Truncate table if requested
if [ "$TRUNCATE" = true ] && [ "$SCHEMA_ONLY" = false ]; then
  echo ""
  print_separator "-"
  execute_sql "TRUNCATE TABLE nutritional_info;" "Truncating table"
fi

# Restore data if needed
if [ "$SCHEMA_ONLY" = false ]; then
  echo ""
  print_separator "-"
  restore_file_with_progress "$DATA_FILE" "Restoring table data" "false" "true"
fi

# Final statistics
print_separator "="
echo -e "${CYAN}📈 Getting final table statistics...${NC}"
print_separator "-"

PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
  -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -c "
    SELECT 
      'Final Rows: ' || COUNT(*) as stat
    FROM $POSTGRES_SCHEMA.nutritional_info
    UNION ALL
    SELECT 
      'Table Size: ' || pg_size_pretty(pg_total_relation_size('$POSTGRES_SCHEMA.nutritional_info'))
    UNION ALL
    SELECT 
      'Data Size: ' || pg_size_pretty(pg_relation_size('$POSTGRES_SCHEMA.nutritional_info'));
  " | while read -r line; do
  echo -e "${CYAN}  $line${NC}"
done

ROWS_AFTER=$(PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
  -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -t -c "
    SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
  " 2>/dev/null | tr -d ' \n\t')

# Calculate total elapsed time
SCRIPT_END_TIME=$(date +%s)
TOTAL_ELAPSED=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
TOTAL_MINS=$((TOTAL_ELAPSED / 60))
TOTAL_SECS=$((TOTAL_ELAPSED % 60))

echo ""
print_separator "="
echo -e "${GREEN}🎉 Nutritional data restore completed successfully!${NC}"
echo -e "${CYAN}📅 Backup date: $BACKUP_DATE${NC}"
echo -e "${CYAN}📊 Rows before: $ROWS_BEFORE${NC}"
echo -e "${CYAN}📊 Rows after: $ROWS_AFTER${NC}"
echo -e "${CYAN}⏱️  Total time elapsed: ${TOTAL_MINS}m ${TOTAL_SECS}s${NC}"
echo -e "${CYAN}⏰ Restore completed at: $(date)${NC}"
print_separator "="
