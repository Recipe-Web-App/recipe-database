#!/bin/bash
set -euo pipefail

MOUNT_PATH="/mnt/recipe-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
JOB_NAME="db-load-schema-job"
NAMESPACE="recipe-db"
YAML_PATH="${LOCAL_PATH}/k8s/jobs/db-load-schema-job.yaml"
MOUNT_PORT=8787

# Start Minikube mount in background if not already running
if ! pgrep -f "minikube mount ${LOCAL_PATH}:${MOUNT_PATH} --port=${MOUNT_PORT}" > /dev/null; then
  echo "🔗 Starting Minikube mount on port ${MOUNT_PORT}..."
  nohup minikube mount "${LOCAL_PATH}:${MOUNT_PATH}" --port="${MOUNT_PORT}" > /tmp/minikube-mount.log 2>&1 &
  echo "⏳ Waiting for Minikube mount to be ready..."
  sleep 5
else
  echo "✅ Minikube mount already running on port ${MOUNT_PORT}."
fi

# Apply the Kubernetes job
echo "🚀 Applying database init job..."
kubectl apply -f "$YAML_PATH" -n "$NAMESPACE"

# Wait for job to complete or fail
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
