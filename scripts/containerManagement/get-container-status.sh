#!/bin/bash

set -euo pipefail

NAMESPACE="recipe-db"
DEPLOYMENT="postgres-deployment"
SERVICE="postgres-service"
JOB="db-load-schema-job"
MOUNT_PATH="/mnt/recipe-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MOUNT_CMD="minikube mount ${LOCAL_PATH}:${MOUNT_PATH}"

# Get terminal width or fallback to 80
WIDTH=$(tput cols 2>/dev/null || echo 80)
SEPARATOR=$(printf '%*s\n' "$WIDTH" '' | tr ' ' '=')

function print_section() {
  echo -e "\n$SEPARATOR"
  echo "🔍 $1"
  echo "$SEPARATOR"
}

echo -e "\n📦 Checking container and Kubernetes resource status..."

print_section "Minikube status"
minikube status || echo "⚠️ Minikube not running"

print_section "Namespace '$NAMESPACE'"
if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
  echo "✅ Namespace exists."
else
  echo "❌ Namespace does not exist."
  exit 0
fi

print_section "Deployment '$DEPLOYMENT'"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not-found || echo "❌ Not found"

print_section "Service '$SERVICE'"
kubectl get service "$SERVICE" -n "$NAMESPACE" --ignore-not-found || echo "❌ Not found"

print_section "Init job '$JOB'"
kubectl get job "$JOB" -n "$NAMESPACE" --ignore-not-found || echo "❌ Not found"

print_section "PVCs in namespace '$NAMESPACE'"
kubectl get pvc -n "$NAMESPACE" || echo "❌ No PVCs found"

print_section "Minikube mount status"
if pgrep -f "$MOUNT_CMD" > /dev/null; then
  echo "✅ Mount is active: ${LOCAL_PATH} -> ${MOUNT_PATH}"
else
  echo "❌ Mount not active."
fi

print_section "kubectl proxy status"
PROXY_PID=$(pgrep -f "kubectl proxy" || true)
if [[ -n "$PROXY_PID" ]]; then
  echo "✅ kubectl proxy is running (PID $PROXY_PID)"
else
  echo "❌ kubectl proxy not running."
fi

echo -e "\n📊 Container status check complete.\n$SEPARATOR"
