#!/bin/bash
# scripts/dbManagement/backup-nutritional-data.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo -e "${CYAN}📥 Loading environment variables...${NC}"
print_separator "-"

# Load environment variables if .env exists
if [ -f .env ]; then
  set -o allexport
  # shellcheck disable=SC1091
  source .env
  set +o allexport
  echo -e "${GREEN}✅ Environment variables loaded.${NC}"
else
  echo -e "${YELLOW}ℹ️ No .env file found. Proceeding without loading environment variables.${NC}"
fi

print_separator "="
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="./db/data/backups"
EXPORT_DIR="./db/data/exports"
BACKUP_FILE="$BACKUP_DIR/nutritional_info_backup_$DATE.sql"
SCHEMA_FILE="$EXPORT_DIR/nutritional_info_schema_$DATE.sql"

mkdir -p "$BACKUP_DIR"
mkdir -p "$EXPORT_DIR"
echo -e "${CYAN}📁 Backup directory ensured at: $BACKUP_DIR${NC}"
echo -e "${CYAN}📁 Export directory ensured at: $EXPORT_DIR${NC}"

print_separator "="
echo -e "${CYAN}🚀 Finding PostgreSQL pod in namespace recipe-database...${NC}"
print_separator "-"

POD_NAME=$(kubectl get pods -n recipe-database -l app=recipe-database -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo -e "${RED}❌ No PostgreSQL pod found in namespace recipe-database with label app=recipe-database${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Found pod: $POD_NAME${NC}"

print_separator "="
echo -e "${CYAN}📊 Getting table statistics...${NC}"
print_separator "-"

kubectl exec -n recipe-database "$POD_NAME" -- \
  bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' psql -U '$DB_MAINT_USER' -d '$POSTGRES_DB' -c \"
    SET search_path TO $POSTGRES_SCHEMA;
    SELECT
      'Total Rows: ' || COUNT(*) as stat
    FROM nutritional_info
    UNION ALL
    SELECT
      'Table Size: ' || pg_size_pretty(pg_total_relation_size('$POSTGRES_SCHEMA.nutritional_info'))
    UNION ALL
    SELECT
      'Data Size: ' || pg_size_pretty(pg_relation_size('$POSTGRES_SCHEMA.nutritional_info'))
    UNION ALL
    SELECT
      'Index Size: ' || pg_size_pretty(pg_total_relation_size('$POSTGRES_SCHEMA.nutritional_info') - pg_relation_size('$POSTGRES_SCHEMA.nutritional_info'));
\"" | while read -r line; do
  echo -e "${CYAN}  $line${NC}"
done

print_separator "="
echo -e "${CYAN}📦 Creating nutritional_info data backup from pod '$POD_NAME'...${NC}"
print_separator "-"

if kubectl exec -n recipe-database "$POD_NAME" -- \
  bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' pg_dump -U '$DB_MAINT_USER' -d '$POSTGRES_DB' \
  --schema='$POSTGRES_SCHEMA' \
  --table='$POSTGRES_SCHEMA.nutritional_info' \
  --data-only \
--column-inserts" >"$BACKUP_FILE"; then
  echo -e "${GREEN}✅ Data backup completed successfully.${NC}"
else
  echo -e "${RED}❌ Data backup failed.${NC}"
  exit 1
fi

print_separator "="
echo -e "${CYAN}📋 Creating nutritional_info schema export from pod '$POD_NAME'...${NC}"
print_separator "-"

if kubectl exec -n recipe-database "$POD_NAME" -- \
  bash -c "PGPASSWORD='$DB_MAINT_PASSWORD' pg_dump -U '$DB_MAINT_USER' -d '$POSTGRES_DB' \
  --schema='$POSTGRES_SCHEMA' \
  --table='$POSTGRES_SCHEMA.nutritional_info' \
--schema-only" >"$SCHEMA_FILE"; then
  echo -e "${GREEN}✅ Schema export completed successfully.${NC}"
else
  echo -e "${RED}❌ Schema export failed.${NC}"
  exit 1
fi

print_separator "="
echo -e "${CYAN}🗜️ Compressing files...${NC}"
print_separator "-"

if gzip "$BACKUP_FILE"; then
  echo -e "${GREEN}✅ Data backup compressed: $(basename "$BACKUP_FILE").gz${NC}"
else
  echo -e "${YELLOW}⚠️ Failed to compress data backup${NC}"
fi

if gzip "$SCHEMA_FILE"; then
  echo -e "${GREEN}✅ Schema export compressed: $(basename "$SCHEMA_FILE").gz${NC}"
else
  echo -e "${YELLOW}⚠️ Failed to compress schema export${NC}"
fi

print_separator "="
echo -e "${CYAN}🧹 Cleaning up old files (keeping last 5)...${NC}"
print_separator "-"

# Clean up old data backups (keep 5 most recent)
find "$BACKUP_DIR" -maxdepth 1 -name 'nutritional_info_backup_*.sql.gz' -print0 | sort -rz | tail -zn +6 | xargs -0 rm -f 2>/dev/null || true

# Clean up old schema exports (keep 5 most recent)
find "$EXPORT_DIR" -maxdepth 1 -name 'nutritional_info_schema_*.sql.gz' -print0 | sort -rz | tail -zn +6 | xargs -0 rm -f 2>/dev/null || true

REMAINING_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -name 'nutritional_info_backup_*.sql.gz' -print0 | grep -cz .)
REMAINING_EXPORTS=$(find "$EXPORT_DIR" -maxdepth 1 -name 'nutritional_info_schema_*.sql.gz' -print0 | grep -cz .)
echo -e "${CYAN}📁 Data backups remaining: $REMAINING_BACKUPS${NC}"
echo -e "${CYAN}📁 Schema exports remaining: $REMAINING_EXPORTS${NC}"

print_separator "="
echo -e "${GREEN}🎉 Nutritional data backup completed successfully!${NC}"
echo -e "${CYAN}📁 Data backup: $BACKUP_DIR/$(basename "$BACKUP_FILE").gz${NC}"
echo -e "${CYAN}📁 Schema export: $EXPORT_DIR/$(basename "$SCHEMA_FILE").gz${NC}"
echo -e "${CYAN}⏰ Backup completed at: $(date)${NC}"
print_separator "="
