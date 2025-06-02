#!/bin/bash
# scripts/dbManagement/load-test-fixtures.sh

set -euo pipefail

print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
JOB_NAME="db-load-test-fixtures-job"
NAMESPACE="recipe-database"
YAML_PATH="${LOCAL_PATH}/k8s/jobs/db-load-test-fixtures-job.yaml"

print_separator
echo "🚀 Applying load database test fixtures job..."
print_separator

kubectl apply -f "$YAML_PATH" -n "$NAMESPACE"

print_separator
echo "⏳ Waiting for job '$JOB_NAME' to complete (timeout: 60s)..."
print_separator

if kubectl wait --for=condition=complete --timeout=60s job/$JOB_NAME -n "$NAMESPACE"; then
  echo "✅ Job completed successfully."
  echo "📜 Job logs:"
  kubectl logs job/$JOB_NAME -n "$NAMESPACE"
  print_separator
  echo "🧹 Cleaning up job..."
  kubectl delete job "$JOB_NAME" -n "$NAMESPACE"
else
  echo "❌ Job failed or timed out. Logs preserved for debugging."
  print_separator
  kubectl describe job "$JOB_NAME" -n "$NAMESPACE"
  kubectl logs job/$JOB_NAME -n "$NAMESPACE" || true
fi

print_separator
echo "✅ Database test fixtures loaded."
print_separator
