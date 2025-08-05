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

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
JOB_NAME="db-restore-nutritional-data-job"
NAMESPACE="recipe-database"
YAML_PATH="${LOCAL_PATH}/k8s/jobs/db-restore-nutritional-data-job.yaml"

# Set backup directories
BACKUP_DIR="${LOCAL_PATH}/db/data/backups"
EXPORT_DIR="${LOCAL_PATH}/db/data/exports"

# Default options
BACKUP_DATE=""
RESTORE_OPTIONS=""

# Function to get latest backup date
function get_latest_backup() {
  local latest_backup
  latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -name 'nutritional_info_backup_*.sql.gz' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n 1)
  if [ -n "$latest_backup" ]; then
    basename "$latest_backup" | sed 's/nutritional_info_backup_\(.*\)\.sql\.gz/\1/'
  else
    echo ""
  fi
}

# Function to show usage
function show_usage() {
  echo "Usage: $0 [OPTIONS] [backup_date]"
  echo ""
  echo "Options:"
  echo "  -s, --schema-only    Restore only table structure"
  echo "  -d, --data-only      Restore only data (table must exist)"
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
  local backups
  backups=$(find "$BACKUP_DIR" -maxdepth 1 -name 'nutritional_info_backup_*.sql.gz' -print0 | \
      xargs -0 -n1 basename | \
      sed 's/nutritional_info_backup_\(.*\)\.sql\.gz/  \1/' | \
    sort -r)
  if [[ -n "$backups" ]]; then
    echo "$backups"
  else
    echo "  No backups found in $BACKUP_DIR"
  fi
}

print_separator "="
echo -e "${CYAN}🥗 Nutritional Data Restore via Kubernetes Job${NC}"
print_separator "-"
echo "LOCAL_PATH: $LOCAL_PATH"
echo "NAMESPACE: $NAMESPACE"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--schema-only)
      RESTORE_OPTIONS="$RESTORE_OPTIONS --schema-only"
      shift
      ;;
    -d|--data-only)
      RESTORE_OPTIONS="$RESTORE_OPTIONS --data-only"
      shift
      ;;
    -t|--truncate)
      RESTORE_OPTIONS="$RESTORE_OPTIONS --truncate"
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

# Validate backup files exist
SCHEMA_FILE="$EXPORT_DIR/nutritional_info_schema_$BACKUP_DATE.sql.gz"
DATA_FILE="$BACKUP_DIR/nutritional_info_backup_$BACKUP_DATE.sql.gz"

echo ""
print_separator "="
echo -e "${CYAN}🔍 Validating backup files...${NC}"
print_separator "-"

if [[ "$RESTORE_OPTIONS" != *"--schema-only"* ]] && [ ! -f "$DATA_FILE" ]; then
  echo -e "${RED}❌ Data backup file not found: $DATA_FILE${NC}"
  exit 1
fi

if [[ "$RESTORE_OPTIONS" != *"--data-only"* ]] && [ ! -f "$SCHEMA_FILE" ]; then
  echo -e "${RED}❌ Schema backup file not found: $SCHEMA_FILE${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Backup files validated${NC}"
echo -e "${CYAN}📅 Using backup from: $BACKUP_DATE${NC}"

# Show what will be restored
if [[ "$RESTORE_OPTIONS" == *"--schema-only"* ]]; then
  echo -e "${CYAN}📋 Will restore: Schema only${NC}"
elif [[ "$RESTORE_OPTIONS" == *"--data-only"* ]]; then
  echo -e "${CYAN}📊 Will restore: Data only${NC}"
  if [[ "$RESTORE_OPTIONS" == *"--truncate"* ]]; then
    echo -e "${YELLOW}⚠️  Table will be truncated before restore${NC}"
  fi
else
  echo -e "${CYAN}🔄 Will restore: Schema + Data${NC}"
fi

# Function to trigger the Kubernetes job
function trigger_job() {
  print_separator "="
  echo -e "${CYAN}🚀 Triggering Kubernetes restore job...${NC}"
  print_separator "-"

  echo "📋 Job configuration: $YAML_PATH"

  # Delete existing job if it exists
  echo "Cleaning up any existing job..."
  kubectl delete job "$JOB_NAME" -n "$NAMESPACE" --ignore-not-found=true

  # Wait a moment for cleanup
  sleep 2

  # Export environment variables for envsubst
  export BACKUP_DATE
  export RESTORE_OPTIONS

  # Apply the job YAML with environment variable substitution
  echo "Starting job: $JOB_NAME"
  envsubst < "$YAML_PATH" | kubectl apply -f -

  # Wait for pod to be created
  echo "Waiting for pod to be ready..."
  if kubectl wait --for=condition=ready pod -l job-name="$JOB_NAME" -n "$NAMESPACE" --timeout=120s; then
    print_separator "-"
    echo -e "${GREEN}✅ Job started successfully${NC}"
  else
    print_separator "-"
    echo -e "${YELLOW}⚠️ Pod took longer than expected to become ready, but job has started${NC}"
  fi
}

# Function to monitor job progress
function monitor_job() {
  print_separator "="
  echo -e "${CYAN}⏳ Monitoring job progress...${NC}"
  print_separator "-"

  # Get the pod name for the job
  local pod_name
  echo "Finding job pod..."
  for i in {1..30}; do
    pod_name=$(kubectl get pods -l job-name="$JOB_NAME" -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$pod_name" ]]; then
      echo "Found pod: $pod_name"
      break
    fi
    echo "Waiting for pod to appear... (attempt $i/30)"
    sleep 2
  done

  if [[ -z "$pod_name" ]]; then
    echo -e "${RED}❌ Could not find job pod after 60 seconds${NC}"
    return 1
  fi

  # Follow the logs
  echo "📋 Following job logs (Ctrl+C to stop watching, job will continue):"
  print_separator "-"

  # Follow logs with timeout protection
  kubectl logs -f "$pod_name" -n "$NAMESPACE" &
  local logs_pid=$!

  # Wait for job completion or user interrupt
  echo ""
  echo -e "${CYAN}⏳ Waiting for job completion...${NC}"
  if kubectl wait --for=condition=complete --timeout=1800s job/"$JOB_NAME" -n "$NAMESPACE"; then
    echo ""
    print_separator "-"
    echo -e "${GREEN}✅ Job completed successfully!${NC}"
  else
    echo ""
    print_separator "-"
    echo -e "${YELLOW}⚠️ Job did not complete within timeout or failed${NC}"

    # Check job status
    local job_status
    job_status=$(kubectl get job "$JOB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "Unknown")
    echo "Job status: $job_status"

    if [[ "$job_status" == "Failed" ]]; then
      echo -e "${RED}❌ Job failed - check logs above for details${NC}"
      # Kill the logs process
      kill $logs_pid 2>/dev/null || true
      return 1
    fi
  fi

  # Kill the logs process if still running
  kill $logs_pid 2>/dev/null || true
  wait $logs_pid 2>/dev/null || true
}

# Main execution
function main() {
  local start_time
  start_time=$(date +%s)

  print_separator "="
  echo -e "${CYAN}🚀 Starting nutritional data restore process...${NC}"
  print_separator "-"
  echo "Started at: $(date)"

  # Trigger the Kubernetes job
  trigger_job

  # Monitor job progress
  monitor_job

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  print_separator "="
  echo -e "${GREEN}✅ Nutritional data restore process completed!${NC}"
  echo "    Total time:  ${duration}s"
  echo "    Finished at: $(date)"
  print_separator "="
}

# Handle interrupts gracefully
trap 'print_separator "-"; echo -e "${RED}❌ Script interrupted${NC}"; print_separator "="; exit 130' INT TERM

# Run main function
main "$@"
