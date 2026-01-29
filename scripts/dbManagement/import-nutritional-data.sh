#!/bin/bash
# scripts/dbManagement/import-nutritional-data.sh
# Import USDA FoodData Central nutritional data via direct NodePort connection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_db-common.sh
source "$SCRIPT_DIR/_db-common.sh"

# Configuration - USDA FoodData Central
# Download page: https://fdc.nal.usda.gov/download-datasets.html
USDA_DATASET="${USDA_DATASET:-sr_legacy_food}" # sr_legacy_food or foundation_food
USDA_DATE="${USDA_DATE:-2018-04}"              # Dataset release date
USDA_BASE_URL="https://fdc.nal.usda.gov/fdc-datasets"
USDA_ZIP_FILE="FoodData_Central_${USDA_DATASET}_csv_${USDA_DATE}.zip"
USDA_URL="${USDA_BASE_URL}/${USDA_ZIP_FILE}"

LOCAL_DATA_DIR="${LOCAL_PATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}/db/data/imports"
ZIP_FILE="${LOCAL_DATA_DIR}/${USDA_ZIP_FILE}"
EXTRACT_DIR="${LOCAL_DATA_DIR}/usda_data"
PYTHON_DIR="${LOCAL_PATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}/python"

# Options
FORCE_DOWNLOAD="${FORCE_DOWNLOAD:-false}"
KEEP_FILES="${KEEP_FILES:-false}"

# Parse command line arguments first
while [[ $# -gt 0 ]]; do
  case $1 in
    --force-download)
      FORCE_DOWNLOAD=true
      shift
      ;;
    --keep-files)
      KEEP_FILES=true
      shift
      ;;
    --dataset)
      USDA_DATASET="$2"
      USDA_ZIP_FILE="FoodData_Central_${USDA_DATASET}_csv_${USDA_DATE}.zip"
      USDA_URL="${USDA_BASE_URL}/${USDA_ZIP_FILE}"
      ZIP_FILE="${LOCAL_DATA_DIR}/${USDA_ZIP_FILE}"
      shift 2
      ;;
    --date)
      USDA_DATE="$2"
      USDA_ZIP_FILE="FoodData_Central_${USDA_DATASET}_csv_${USDA_DATE}.zip"
      USDA_URL="${USDA_BASE_URL}/${USDA_ZIP_FILE}"
      ZIP_FILE="${LOCAL_DATA_DIR}/${USDA_ZIP_FILE}"
      shift 2
      ;;
    --help | -h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --force-download    Force re-download even if files exist"
      echo "  --keep-files        Keep downloaded files after completion"
      echo "  --dataset NAME      USDA dataset (foundation_food or sr_legacy_food)"
      echo "  --date DATE         Dataset date (e.g., 2024-04-18)"
      echo "  --help, -h          Show this help message"
      echo ""
      echo "Environment variables:"
      echo "  FORCE_DOWNLOAD=true    Same as --force-download"
      echo "  KEEP_FILES=true        Same as --keep-files"
      echo "  USDA_DATASET=name      Same as --dataset"
      echo "  USDA_DATE=date         Same as --date"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

print_separator "="
log_info "USDA FoodData Central Nutritional Data Import"
print_separator "-"

log_info "Loading environment variables..."
load_env

# Update paths with loaded LOCAL_PATH
LOCAL_DATA_DIR="${LOCAL_PATH}/db/data/imports"
ZIP_FILE="${LOCAL_DATA_DIR}/${USDA_ZIP_FILE}"
EXTRACT_DIR="${LOCAL_DATA_DIR}/usda_data"
PYTHON_DIR="${LOCAL_PATH}/python"

log_info "Configuration:"
log_info "  Dataset: $USDA_DATASET"
log_info "  Date: $USDA_DATE"
log_info "  Force Download: $FORCE_DOWNLOAD"
log_info "  Keep Files: $KEEP_FILES"
log_info "  Database: $POSTGRES_HOST:$POSTGRES_PORT"

# Verify required tools
require_commands psql python3 || exit 1

# Create directories
mkdir -p "$LOCAL_DATA_DIR"
mkdir -p "$EXTRACT_DIR"

# Function to download USDA data
function download_usda() {
  print_separator "="
  log_info "Downloading USDA FoodData Central data..."
  print_separator "-"
  log_info "URL: $USDA_URL"
  log_info "Destination: $ZIP_FILE"

  if command -v wget >/dev/null 2>&1; then
    wget --continue --progress=bar:force:noscroll -O "$ZIP_FILE" "$USDA_URL"
  elif command -v curl >/dev/null 2>&1; then
    curl -L --continue-at - -o "$ZIP_FILE" "$USDA_URL"
  else
    log_error "Neither wget nor curl is available"
    exit 1
  fi

  if [[ ! -f "$ZIP_FILE" ]]; then
    log_error "Download failed - file not found"
    exit 1
  fi

  local file_size
  file_size=$(du -h "$ZIP_FILE" | cut -f1)
  print_separator "-"
  log_success "Download completed - File size: $file_size"
}

# Function to extract ZIP file
function extract_zip() {
  print_separator "="
  log_info "Extracting USDA data..."
  print_separator "-"

  # Clear extraction directory
  rm -rf "${EXTRACT_DIR:?}/"*

  if command -v unzip >/dev/null 2>&1; then
    unzip -o "$ZIP_FILE" -d "$EXTRACT_DIR"
  else
    log_error "unzip is not available"
    exit 1
  fi

  # Find the extracted directory (USDA ZIPs contain a dated subdirectory)
  local extracted_subdir
  extracted_subdir=$(find "$EXTRACT_DIR" -maxdepth 1 -type d -name "FoodData_Central_*" | head -1)

  if [[ -n "$extracted_subdir" ]]; then
    # Move contents up one level for easier access
    mv "$extracted_subdir"/* "$EXTRACT_DIR/"
    # Use rm -rf to handle hidden files that mv * doesn't match
    rm -rf "$extracted_subdir"
  fi

  # Verify required files exist
  local required_files=("food.csv" "food_nutrient.csv" "nutrient.csv")
  for file in "${required_files[@]}"; do
    if [[ ! -f "$EXTRACT_DIR/$file" ]]; then
      log_error "Required file not found: $file"
      exit 1
    fi
  done

  print_separator "-"
  log_success "Extraction completed. Contents:"
  find "$EXTRACT_DIR" -maxdepth 1 -name "*.csv" -print0 | xargs -0 ls -lh 2>/dev/null | head -10
}

# Function to run Python importer
function run_python_importer() {
  print_separator "="
  log_info "Running Python importer..."
  print_separator "-"

  # Check if virtual environment exists
  local venv_dir="$PYTHON_DIR/venv"
  local requirements="$PYTHON_DIR/requirements.txt"
  local importer="$PYTHON_DIR/nutritional_data_importer/nutritional_data_importer.py"

  if [[ ! -f "$importer" ]]; then
    log_error "Python importer not found: $importer"
    exit 1
  fi

  # Create venv if needed
  if [[ ! -d "$venv_dir" ]]; then
    log_info "Creating Python virtual environment..."
    python3 -m venv "$venv_dir"
  fi

  # Activate venv and install dependencies
  log_info "Installing Python dependencies..."
  # shellcheck disable=SC1091
  source "$venv_dir/bin/activate"
  pip install -q -r "$requirements"

  # Set environment variables for the importer
  export POSTGRES_HOST
  export POSTGRES_PORT
  export POSTGRES_DB
  export POSTGRES_SCHEMA
  export DB_MAINT_USER
  export DB_MAINT_PASSWORD

  log_info "Starting import from: $EXTRACT_DIR"
  print_separator "-"

  # Run the importer
  if python3 "$importer" "$EXTRACT_DIR" --verbose; then
    log_success "Python importer completed successfully"
  else
    log_error "Python importer failed"
    deactivate 2>/dev/null || true
    exit 1
  fi

  deactivate 2>/dev/null || true
}

# Function to cleanup files
function cleanup() {
  if [[ "$KEEP_FILES" != "true" ]]; then
    print_separator "="
    log_info "Cleaning up downloaded files..."
    print_separator "-"

    if [[ -f "$ZIP_FILE" ]]; then
      log_info "Removing: $ZIP_FILE"
      rm -f "$ZIP_FILE"
    fi

    if [[ -d "$EXTRACT_DIR" ]]; then
      log_info "Removing: $EXTRACT_DIR"
      rm -rf "$EXTRACT_DIR"
    fi

    log_success "Cleanup completed"
  else
    log_info "Keeping downloaded files (--keep-files)"
  fi
}

# Main execution
function main() {
  local start_time
  start_time=$(date +%s)

  print_separator "="
  log_info "Starting USDA FoodData Central import process..."
  print_separator "-"
  log_info "Started at: $(date)"

  # Check database connection
  check_db_connection || exit 1

  # Download if needed
  if [[ ! -f "$ZIP_FILE" || "$FORCE_DOWNLOAD" == "true" ]]; then
    download_usda
  else
    log_info "ZIP file already exists: $ZIP_FILE"
    log_info "Use --force-download to force re-download"
  fi

  # Extract ZIP
  extract_zip

  # Run the Python importer locally
  run_python_importer

  # Cleanup files
  cleanup

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  print_separator "="
  log_success "USDA FoodData Central import completed!"
  log_info "Total time: ${duration}s"
  log_info "Finished at: $(date)"
  print_separator "="
}

# Handle interrupts gracefully
trap 'print_separator "-"; log_info "Script interrupted"; print_separator "="; exit 130' INT TERM

# Run main function
main
