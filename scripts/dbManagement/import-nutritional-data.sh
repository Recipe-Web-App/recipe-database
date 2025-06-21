#!/bin/bash
# scripts/dbManagement/import-nutritional-data.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
JOB_NAME="db-import-nutritional-data-job"
NAMESPACE="recipe-database"
YAML_PATH="${LOCAL_PATH}/k8s/jobs/db-import-nutritional-data-job.yaml"

# Configuration
OPENFOODFACTS_URL="https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
LOCAL_DATA_DIR="${LOCAL_PATH}/db/data/imports"
COMPRESSED_FILE="${LOCAL_DATA_DIR}/openfoodfacts.csv.gz"

# Options
FORCE_DOWNLOAD="${FORCE_DOWNLOAD:-false}"
KEEP_FILES="${KEEP_FILES:-false}"

print_separator "="
echo "🥗 OpenFoodFacts Nutritional Data Import"
print_separator "-"
echo "LOCAL_PATH: $LOCAL_PATH"
echo "NAMESPACE: $NAMESPACE"
echo "FORCE_DOWNLOAD: $FORCE_DOWNLOAD"
echo "KEEP_FILES: $KEEP_FILES"

# Create local data directory
mkdir -p "$LOCAL_DATA_DIR"

# Function to download OpenFoodFacts CSV
download_csv() {
  print_separator "="
  echo "📥 Downloading OpenFoodFacts CSV..."
  print_separator "-"
  echo "URL: $OPENFOODFACTS_URL"
  echo "Destination: $COMPRESSED_FILE"

  if command -v wget >/dev/null 2>&1; then
    wget --continue --progress=bar:force:noscroll -O "$COMPRESSED_FILE" "$OPENFOODFACTS_URL"
  elif command -v curl >/dev/null 2>&1; then
    curl -L --continue-at - -o "$COMPRESSED_FILE" "$OPENFOODFACTS_URL"
  else
    print_separator "-"
    echo "❌ Error: Neither wget nor curl is available"
    print_separator "="
    exit 1
  fi

  if [[ ! -f "$COMPRESSED_FILE" ]]; then
    print_separator "-"
    echo "❌ Error: Download failed - file not found"
    print_separator "="
    exit 1
  fi

  local file_size
  file_size=$(du -h "$COMPRESSED_FILE" | cut -f1)
  print_separator "-"
  echo "✅ Download completed - File size: $file_size"
}

# Function to trigger the Kubernetes job
trigger_job() {
  print_separator "="
  echo "🚀 Triggering Kubernetes import job..."
  print_separator "-"

  echo "📋 Job configuration: $YAML_PATH"

  # Delete existing job if it exists
  echo "Cleaning up any existing job..."
  kubectl delete job "$JOB_NAME" -n "$NAMESPACE" --ignore-not-found=true

  # Wait a moment for cleanup
  sleep 2

  # Apply the job YAML
  echo "Starting job: $JOB_NAME"
  kubectl apply -f "$YAML_PATH"

  # Wait for pod to be created
  echo "Waiting for pod to be ready..."
  if kubectl wait --for=condition=ready pod -l job-name="$JOB_NAME" -n "$NAMESPACE" --timeout=120s; then
    print_separator "-"
    echo "✅ Job started successfully"
  else
    print_separator "-"
    echo "⚠️ Pod took longer than expected to become ready, but job has started"
  fi
}

# Function to monitor job progress
monitor_job() {
  print_separator "="
  echo "⏳ Monitoring job progress..."
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
    echo "❌ Could not find job pod after 60 seconds"
    return 1
  fi

  # Follow the logs
  echo "� Following job logs (Ctrl+C to stop watching, job will continue):"
  print_separator "-"

  # Follow logs with timeout protection
  kubectl logs -f "$pod_name" -n "$NAMESPACE" &
  local logs_pid=$!

  # Wait for job completion or user interrupt
  echo ""
  echo "⏳ Waiting for job completion..."
  if kubectl wait --for=condition=complete --timeout=3600s job/"$JOB_NAME" -n "$NAMESPACE"; then
    echo ""
    print_separator "-"
    echo "✅ Job completed successfully!"
  else
    echo ""
    print_separator "-"
    echo "⚠️ Job did not complete within timeout or failed"

    # Check job status
    local job_status
    job_status=$(kubectl get job "$JOB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "Unknown")
    echo "Job status: $job_status"

    if [[ "$job_status" == "Failed" ]]; then
      echo "❌ Job failed - check logs above for details"
      # Kill the logs process
      kill $logs_pid 2>/dev/null || true
      return 1
    fi
  fi

  # Kill the logs process if still running
  kill $logs_pid 2>/dev/null || true
  wait $logs_pid 2>/dev/null || true
}

# Function to cleanup files
cleanup() {
  if [[ "$KEEP_FILES" != "true" ]]; then
    print_separator "="
    echo "🧹 Cleaning up downloaded files..."
    print_separator "-"

    if [[ -f "$COMPRESSED_FILE" ]]; then
      echo "Removing: $COMPRESSED_FILE"
      rm -f "$COMPRESSED_FILE"
    fi

    print_separator "-"
    echo "✅ Cleanup completed"
  else
    echo "ℹ️  Keeping downloaded files (KEEP_FILES=true)"
  fi
}

# Main execution
main() {
  local start_time
  start_time=$(date +%s)

  print_separator "="
  echo "🚀 Starting OpenFoodFacts import process..."
  print_separator "-"
  echo "Started at: $(date)"

  # Download if needed
  if [[ ! -f "$COMPRESSED_FILE" || "$FORCE_DOWNLOAD" == "true" ]]; then
    download_csv
  else
    echo "ℹ️  Compressed CSV already exists: $COMPRESSED_FILE"
    echo "    Use FORCE_DOWNLOAD=true to force re-download"
  fi

  # Trigger the Kubernetes job
  trigger_job

  # Monitor job progress
  monitor_job

  # Cleanup files
  cleanup

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  print_separator "="
  echo "✅ OpenFoodFacts import process completed!"
  echo "    Total time:  ${duration}s"
  echo "    Finished at: $(date)"
  print_separator "="
}

# Handle interrupts gracefully
trap 'print_separator "-"; echo "❌ Script interrupted"; print_separator "="; exit 130' INT TERM

# Parse command line arguments
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
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --force-download    Force re-download even if files exist"
      echo "  --keep-files        Keep downloaded files after completion"
      echo "  --help, -h          Show this help message"
      echo ""
      echo "Environment variables:"
      echo "  FORCE_DOWNLOAD=true    Same as --force-download"
      echo "  KEEP_FILES=true        Same as --keep-files"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Run main function
main "$@"
