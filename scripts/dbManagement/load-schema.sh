#!/bin/bash
set -euo pipefail

LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
JOB_NAME="db-load-schema-job"
NAMESPACE="recipe-db"
YAML_PATH="${LOCAL_PATH}/k8s/jobs/db-load-schema-job.yaml"

echo "🚀 Applying database init job..."
kubectl apply -f "$YAML_PATH" -n "$NAMESPACE"

echo "⏳ Waiting for job '$JOB_NAME' to complete..."
if kubectl wait --for=condition=complete --timeout=60s job/$JOB_NAME -n "$NAMESPACE"; then
  echo "✅ Job completed successfully."
  echo "📜 Job logs:"
  kubectl logs job/$JOB_NAME -n "$NAMESPACE"
  echo "🧹 Cleaning up job..."
  kubectl delete job $JOB_NAME -n "$NAMESPACE"
else
  echo "❌ Job failed or timed out. Logs preserved for debugging."
  kubectl describe job $JOB_NAME -n "$NAMESPACE"
  kubectl logs job/$JOB_NAME -n "$NAMESPACE" || true
fi

echo "✅ Database initialization complete."
