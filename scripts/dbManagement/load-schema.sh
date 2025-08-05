#!/bin/bash
# scripts/dbManagement/load-schema.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
JOB_NAME="db-load-schema-job"
NAMESPACE="recipe-database"
YAML_PATH="${LOCAL_PATH}/k8s/jobs/db-load-schema-job.yaml"

print_separator "="
echo "🚀 Applying database initialization job..."
print_separator "-"

kubectl apply -f "$YAML_PATH" -n "$NAMESPACE"

print_separator "="
echo "⏳ Waiting for job '$JOB_NAME' to complete (timeout: 60s)..."
print_separator "-"

if kubectl wait --for=condition=complete --timeout=60s job/$JOB_NAME -n "$NAMESPACE"; then
  echo "✅ Job completed successfully."
  echo "📜 Job logs:"
  kubectl logs job/$JOB_NAME -n "$NAMESPACE"
  print_separator "-"
  echo "🧹 Cleaning up job..."
  kubectl delete job "$JOB_NAME" -n "$NAMESPACE"
else
  echo "❌ Job failed or timed out. Logs preserved for debugging."
  print_separator "-"
  kubectl describe job "$JOB_NAME" -n "$NAMESPACE"
  kubectl logs job/$JOB_NAME -n "$NAMESPACE" || true
fi

print_separator "="
echo "✅ Database initialization complete."
print_separator "="
