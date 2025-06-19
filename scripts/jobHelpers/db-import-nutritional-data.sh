#!/bin/bash
# scripts/jobHelpers/db-import-nutritional-data.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Configuration
DATA_MOUNT_DIR="/app/data"  # Where the volume is actually mounted
CSV_FILE="$DATA_MOUNT_DIR/openfoodfacts.csv.gz"  # Use compressed file directly
PYTHON_SCRIPT="/app/python/nutritional_data_importer/nutritional_data_importer.py"

print_separator "="
echo "🥗 OpenFoodFacts Import Job"
print_separator "-"
echo "DATA_MOUNT_DIR: $DATA_MOUNT_DIR"
echo "IMPORT_DATA_DIR: $IMPORT_DATA_DIR (env var)"

# Function to install Python dependencies
install_dependencies() {
  print_separator "="
  echo "🐍 Installing Python dependencies..."
  print_separator "-"
  
  local requirements_file="/app/python/requirements.txt"
  local venv_dir="/tmp/venv"
  
  if [[ ! -f "$requirements_file" ]]; then
    echo "❌ Error: Requirements file not found: $requirements_file"
    print_separator "="
    exit 1
  fi
  
  echo "Creating virtual environment at: $venv_dir"
  if python3 -m venv "$venv_dir"; then
    echo ""
    echo "✅ Virtual environment created successfully"
    print_separator "-"
  else
    echo "❌ Failed to create virtual environment"
    print_separator "="
    exit 1
  fi
  
  echo "Installing from: $requirements_file"
  if "$venv_dir/bin/pip" install --no-cache-dir -r "$requirements_file"; then
    echo ""
    echo "✅ Python dependencies installed successfully"
  else
    echo "❌ Failed to install Python dependencies"
    print_separator "="
    exit 1
  fi
  
  # Export the virtual environment paths for the Python script
  export PATH="$venv_dir/bin:$PATH"
  export VIRTUAL_ENV="$venv_dir"
}

# Function to verify data directory and CSV file exist
verify_data() {
  print_separator "="
  echo "📋 Verifying data directory and CSV file..."
  print_separator "-"
  
  # Check if data directory exists
  if [[ ! -d "$DATA_MOUNT_DIR" ]]; then
    echo "❌ Error: Data directory not found: $DATA_MOUNT_DIR"
    print_separator "="
    exit 1
  fi
  
  echo "✅ Data directory found: $DATA_MOUNT_DIR"
  
  # Check if CSV file exists
  if [[ ! -f "$CSV_FILE" ]]; then
    echo "❌ Error: CSV file not found: $CSV_FILE"
    print_separator "="
    exit 1
  fi
  
  # Get file information
  local file_size=$(du -h "$CSV_FILE" | cut -f1)
  
  echo "✅ CSV file found: $CSV_FILE"
  echo "    File size: $file_size"
}

# Function to run the Python import script
run_import() {
  print_separator "="
  echo "🐍 Running Python import script..."
  print_separator "-"

  # Build command arguments
  local python_args=()
  python_args+=("$CSV_FILE")
  
  echo "Command: python3 $PYTHON_SCRIPT ${python_args[*]}"
  echo ""
  
  # Run the Python script
  if python3 "$PYTHON_SCRIPT" "${python_args[@]}"; then
    print_separator "-"
    echo "✅ Nutritional data imported successfully"
  else
    print_separator "-"
    echo "❌ Nutritional data import failed"
    print_separator "="
    exit 1
  fi
}

# Main execution
main() {
  local start_time=$(date +%s)
  
  print_separator "="
  echo "🚀 Starting OpenFoodFacts import process..."
  print_separator "-"
  echo "Started at: $(date)"
  
  # Install Python dependencies
  install_dependencies
  
  # Verify data directory and CSV file
  verify_data
  
  # Run the import
  run_import
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  print_separator "="
  echo "🎉 OpenFoodFacts import job completed!"
  echo "    Total time: ${duration}s"
  echo "    Finished at: $(date)"
  print_separator "="
}

# Handle interrupts gracefully
trap 'print_separator "-"; echo "❌ Script interrupted"; print_separator "="; exit 130' INT TERM

# Run main function
main "$@"
