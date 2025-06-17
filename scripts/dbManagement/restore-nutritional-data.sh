#!/bin/bash
# scripts/dbManagement/restore-nutritional-data.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set backup directories early
BACKUP_DIR="./db/data/backups"
EXPORT_DIR="./db/data/exports"

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Function to get latest backup date
get_latest_backup() {
  local latest_backup
  latest_backup=$(ls -t "$BACKUP_DIR"/nutritional_info_backup_*.sql.gz 2>/dev/null | head -n 1)
  if [ -n "$latest_backup" ]; then
    basename "$latest_backup" | sed 's/nutritional_info_backup_\(.*\)\.sql\.gz/\1/'
  else
    echo ""
  fi
}

# Function to show usage
show_usage() {
  echo "Usage: $0 [OPTIONS] [backup_date]"
  echo ""
  echo "Options:"
  echo "  -s, --schema-only    Restore only table structure"
  echo "  -d, --data-only      Restore only data (table must exist)"
  echo "  -f, --force          Skip confirmation prompts"
  echo "  -t, --truncate       Truncate table before restoring data"
  echo "  -h, --help           Show this help message"
  echo ""
  echo "If no backup_date is specified, the latest backup will be used."
  echo ""
  echo "Examples:"
  echo "  $0                                            # Restore latest backup (schema + data)"
  echo "  $0 --data-only                                # Restore latest backup (data only)"
  echo "  $0 2025-06-17_14-30-22                       # Restore specific backup"
  echo "  $0 --data-only 2025-06-17_14-30-22          # Restore specific backup (data only)"
  echo "  $0 --truncate --data-only                     # Clear table and restore latest data"
  echo ""
  echo "Available backups:"
  if ls -1 "$BACKUP_DIR"/nutritional_info_backup_*.sql.gz &>/dev/null; then
    ls -1 "$BACKUP_DIR"/nutritional_info_backup_*.sql.gz | \
      sed 's/.*nutritional_info_backup_\(.*\)\.sql\.gz/  \1/' | \
      sort -r
  else
    echo "  No backups found in $BACKUP_DIR"
  fi
}

print_separator "="
echo -e "${CYAN}📥 Loading environment variables...${NC}"
print_separator "-"

# Load environment variables if .env exists
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source .env
  set +o allexport
  echo -e "${GREEN}✅ Environment variables loaded.${NC}"
else
  echo -e "${YELLOW}ℹ️ No .env file found. Proceeding without loading environment variables.${NC}"
fi

# Parse command line arguments
SCHEMA_ONLY=false
DATA_ONLY=false
FORCE=false
TRUNCATE=false
BACKUP_DATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--schema-only)
      SCHEMA_ONLY=true
      shift
      ;;
    -d|--data-only)
      DATA_ONLY=true
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -t|--truncate)
      TRUNCATE=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    -*)
      echo -e "${RED}❌ Unknown option: $1${NC}"
      show_usage
      exit 1
      ;;
    *)
      BACKUP_DATE="$1"
      shift
      ;;
  esac
done

# Use latest backup if no date specified
if [ -z "$BACKUP_DATE" ]; then
  BACKUP_DATE=$(get_latest_backup)
  if [ -z "$BACKUP_DATE" ]; then
    echo -e "${RED}❌ No backups found in $BACKUP_DIR${NC}"
    exit 1
  fi
  echo -e "${CYAN}ℹ️ No backup date specified, using latest: $BACKUP_DATE${NC}"
fi

# Validate arguments
if [ "$SCHEMA_ONLY" = true ] && [ "$DATA_ONLY" = true ]; then
  echo -e "${RED}❌ Cannot specify both --schema-only and --data-only${NC}"
  exit 1
fi

# Set backup files
SCHEMA_FILE="$EXPORT_DIR/nutritional_info_schema_$BACKUP_DATE.sql.gz"
DATA_FILE="$BACKUP_DIR/nutritional_info_backup_$BACKUP_DATE.sql.gz"

print_separator "="
echo -e "${CYAN}🔍 Validating backup files...${NC}"
print_separator "-"

# Check if files exist
if [ "$SCHEMA_ONLY" = false ] && [ ! -f "$DATA_FILE" ]; then
  echo -e "${RED}❌ Data backup file not found: $DATA_FILE${NC}"
  exit 1
fi

if [ "$DATA_ONLY" = false ] && [ ! -f "$SCHEMA_FILE" ]; then
  echo -e "${RED}❌ Schema backup file not found: $SCHEMA_FILE${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Backup files validated${NC}"
echo -e "${CYAN}📅 Using backup from: $BACKUP_DATE${NC}"

# Show what will be restored
if [ "$SCHEMA_ONLY" = true ]; then
  echo -e "${CYAN}📋 Will restore: Schema only${NC}"
elif [ "$DATA_ONLY" = true ]; then
  echo -e "${CYAN}📊 Will restore: Data only${NC}"
  if [ "$TRUNCATE" = true ]; then
    echo -e "${YELLOW}⚠️  Table will be truncated before restore${NC}"
  fi
else
  echo -e "${CYAN}🔄 Will restore: Schema + Data${NC}"
fi

print_separator "="
echo -e "${CYAN}🚀 Finding PostgreSQL pod in namespace recipe-database...${NC}"
print_separator "-"

POD_NAME=$(kubectl get pods -n recipe-database -l app=recipe-database -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo -e "${RED}❌ No PostgreSQL pod found in namespace recipe-database with label app=recipe-database${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Found pod: $POD_NAME${NC}"

# Confirmation prompt
if [ "$FORCE" = false ]; then
  print_separator "="
  echo -e "${YELLOW}⚠️  CONFIRMATION REQUIRED${NC}"
  print_separator "-"
  echo -e "${YELLOW}This will restore nutritional_info data from backup: $BACKUP_DATE${NC}"
  
  if [ "$TRUNCATE" = true ]; then
    echo -e "${RED}⚠️  WARNING: This will DELETE ALL existing data in nutritional_info table!${NC}"
  fi
  
  echo -e "${YELLOW}Do you want to continue? (yes/no):${NC}"
  read -r confirmation
  
  if [[ ! "$confirmation" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${CYAN}ℹ️ Restore cancelled by user${NC}"
    exit 0
  fi
fi

# Function to execute SQL in pod
execute_sql() {
  local sql="$1"
  local description="$2"
  
  echo -e "${CYAN}🔧 $description...${NC}"
  
  if kubectl exec -n recipe-database "$POD_NAME" -- \
    bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -c \"$sql\"" > /dev/null; then
    echo -e "${GREEN}✅ $description completed${NC}"
  else
    echo -e "${RED}❌ $description failed${NC}"
    exit 1
  fi
}

# Function to check if table exists
check_table_exists() {
  local exists
  exists=$(kubectl exec -n recipe-database "$POD_NAME" -- \
    bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -t -c \"
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = '$POSTGRES_SCHEMA' 
        AND table_name = 'nutritional_info'
      );
    \"" 2>/dev/null | tr -d ' \n\t')
  
  if [ "$exists" = "t" ]; then
    return 0  # Table exists
  else
    return 1  # Table doesn't exist
  fi
}

# Function to restore file with progress monitoring
restore_file_with_progress() {
  local file="$1"
  local description="$2"
  local ignore_errors="${3:-false}"
  local show_progress="${4:-false}"
  
  echo -e "${CYAN}📤 $description...${NC}"
  
  if [ "$show_progress" = "true" ]; then
    # Start the restore in background
    if [ "$ignore_errors" = "true" ]; then
      gunzip -c "$file" | kubectl exec -i -n recipe-database "$POD_NAME" -- \
        bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB'" > /dev/null 2>&1 &
    else
      gunzip -c "$file" | kubectl exec -i -n recipe-database "$POD_NAME" -- \
        bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB'" > /dev/null &
    fi
    
    local restore_pid=$!
    local start_time=$(date +%s)
    
    echo -e "${CYAN}🔄 Monitoring restore progress...${NC}"
    
    # Monitor progress
    while kill -0 $restore_pid 2>/dev/null; do
      local current_rows
      current_rows=$(kubectl exec -n recipe-database "$POD_NAME" -- \
        bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -t -c \"
          SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
        \"" 2>/dev/null | tr -d ' \n\t' || echo "0")
      
      local elapsed=$(($(date +%s) - start_time))
      local mins=$((elapsed / 60))
      local secs=$((elapsed % 60))
      
      printf "\r${CYAN}📊 Rows restored: %s | Time elapsed: %02d:%02d${NC}" "$current_rows" "$mins" "$secs"
      sleep 3
    done
    
    # Wait for the process to complete and get exit code
    wait $restore_pid
    local exit_code=$?
    
    # Clear the progress line and show completion
    printf "\r%*s\r" 80 ""
    
    if [ $exit_code -eq 0 ]; then
      local final_rows
      final_rows=$(kubectl exec -n recipe-database "$POD_NAME" -- \
        bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -t -c \"
          SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
        \"" 2>/dev/null | tr -d ' \n\t')
      
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
    # Original non-progress version for schema
    if [ "$ignore_errors" = "true" ]; then
      local error_output
      error_output=$(gunzip -c "$file" | kubectl exec -i -n recipe-database "$POD_NAME" -- \
        bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB'" 2>&1)
      
      local filtered_errors
      filtered_errors=$(echo "$error_output" | grep -v "already exists" | grep -v "must be owner" | grep -v "no privileges were granted" || true)
      
      if [ -n "$filtered_errors" ]; then
        echo -e "${YELLOW}⚠️ Some schema restore issues (non-critical):${NC}"
        echo "$filtered_errors" | head -5
      fi
      
      echo -e "${GREEN}✅ $description completed (with expected warnings)${NC}"
    else
      if gunzip -c "$file" | kubectl exec -i -n recipe-database "$POD_NAME" -- \
        bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB'" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $description completed${NC}"
      else
        echo -e "${RED}❌ $description failed${NC}"
        exit 1
      fi
    fi
  fi
}

print_separator "="
echo -e "${CYAN}🔄 Starting restore process...${NC}"
print_separator "-"

# Set search path
execute_sql "SET search_path TO $POSTGRES_SCHEMA;" "Setting search path"

# Get current table stats before restore
if kubectl exec -n recipe-database "$POD_NAME" -- \
  bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -t -c \"
    SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
  \"" 2>/dev/null | tr -d ' \n\t'; then
  ROWS_BEFORE=$(kubectl exec -n recipe-database "$POD_NAME" -- \
    bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -t -c \"
      SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
    \"" 2>/dev/null | tr -d ' \n\t')
  echo -e "${CYAN}📊 Current rows in table: $ROWS_BEFORE${NC}"
else
  ROWS_BEFORE="N/A (table may not exist)"
  echo -e "${CYAN}📊 Current table status: $ROWS_BEFORE${NC}"
fi

# Restore schema if needed
if [ "$DATA_ONLY" = false ]; then
  print_separator "-"
  
  if check_table_exists; then
    echo -e "${YELLOW}ℹ️ Table nutritional_info already exists, skipping schema restore${NC}"
    echo -e "${CYAN}💡 Use --data-only flag if you only want to restore data${NC}"
  else
    echo -e "${CYAN}📋 Table doesn't exist, creating from schema...${NC}"
    restore_file_with_progress "$SCHEMA_FILE" "Restoring table schema" "true" "false"
  fi
fi

# Truncate table if requested
if [ "$TRUNCATE" = true ] && [ "$SCHEMA_ONLY" = false ]; then
  print_separator "-"
  execute_sql "TRUNCATE TABLE nutritional_info;" "Truncating table"
fi

# Restore data if needed (WITH PROGRESS)
if [ "$SCHEMA_ONLY" = false ]; then
  print_separator "-"
  restore_file_with_progress "$DATA_FILE" "Restoring table data" "false" "true"
fi

print_separator "="
echo -e "${CYAN}📈 Getting final table statistics...${NC}"
print_separator "-"

kubectl exec -n recipe-database "$POD_NAME" -- \
  bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -c \"
    SELECT 
      'Final Rows: ' || COUNT(*) as stat
    FROM $POSTGRES_SCHEMA.nutritional_info
    UNION ALL
    SELECT 
      'Table Size: ' || pg_size_pretty(pg_total_relation_size('$POSTGRES_SCHEMA.nutritional_info'))
    UNION ALL
    SELECT 
      'Data Size: ' || pg_size_pretty(pg_relation_size('$POSTGRES_SCHEMA.nutritional_info'));
  \"" | while read -r line; do
  echo -e "${CYAN}  $line${NC}"
done

print_separator "="
echo -e "${GREEN}🎉 Nutritional data restore completed successfully!${NC}"
echo -e "${CYAN}📅 Backup date: $BACKUP_DATE${NC}"
echo -e "${CYAN}📊 Rows before: $ROWS_BEFORE${NC}"

ROWS_AFTER=$(kubectl exec -n recipe-database "$POD_NAME" -- \
  bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -t -c \"
    SELECT COUNT(*) FROM $POSTGRES_SCHEMA.nutritional_info;
  \"" 2>/dev/null | tr -d ' \n\t')
echo -e "${CYAN}📊 Rows after: $ROWS_AFTER${NC}"
echo -e "${CYAN}⏰ Restore completed at: $(date)${NC}"
print_separator "="
