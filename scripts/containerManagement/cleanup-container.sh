#!/bin/bash
# scripts/containerManagement/cleanup-container.sh

set -euo pipefail

NAMESPACE="recipe-database"
MOUNT_PATH="/mnt/recipe-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MOUNT_CMD="minikube mount ${LOCAL_PATH}:${MOUNT_PATH}"
IMAGE_NAME="recipe-database"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Utility function for printing section separators
print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

print_separator
echo "🧪 Checking Minikube status..."
print_separator

if ! minikube status >/dev/null 2>&1; then
  echo "⚠️ Minikube is not running. Starting Minikube..."
  if ! minikube start; then
    echo "❌ Failed to start Minikube. Exiting."
    exit 1
  fi
else
  echo "✅ Minikube is already running."
fi

print_separator
echo "🧹 Deleting Kubernetes resources in namespace '$NAMESPACE'..."
print_separator

kubectl delete -f k8s/configmap-template.yaml -n "$NAMESPACE" --ignore-not-found
kubectl delete -f k8s/deployment.yaml -n "$NAMESPACE" --ignore-not-found
kubectl delete -f k8s/secret-template.yaml -n "$NAMESPACE" --ignore-not-found
kubectl delete -f k8s/service.yaml -n "$NAMESPACE" --ignore-not-found

print_separator
echo "🧹 Deleting database initialization job..."
print_separator

kubectl delete job db-load-schema-job -n "$NAMESPACE" --ignore-not-found

print_separator
echo "🧹 Deleting database load test fixture job..."
print_separator

kubectl delete job db-load-test-fixtures-job -n "$NAMESPACE" --ignore-not-found

print_separator
echo "🔌 Checking for active Minikube mount..."
print_separator

if pgrep -f "$MOUNT_CMD" > /dev/null; then
  echo "🛑 Killing Minikube mount process..."
  pkill -f "$MOUNT_CMD"
  echo "✅ Minikube mount stopped."
else
  echo "ℹ️ No active Minikube mount found."
fi

print_separator
read -r -p "⚠️ Do you want to delete the PersistentVolumeClaim (PVC)? This will delete all stored database data! (y/N): " del_pvc
print_separator

if [[ "$del_pvc" =~ ^[Yy]$ ]]; then
  kubectl delete -f k8s/pvc.yaml -n "$NAMESPACE" --ignore-not-found
  echo "🧨 PVC deleted."
else
  echo "💾 PVC retained."
fi

print_separator
echo "🐳 Removing Docker image '${FULL_IMAGE_NAME}' from Minikube..."
print_separator

eval "$(minikube docker-env)"
docker rmi -f "$FULL_IMAGE_NAME" || echo "Image not found or already removed."

print_separator
read -r -p "🛑 Do you want to stop (shut down) Minikube now? (y/N): " stop_mk
print_separator

if [[ "$stop_mk" =~ ^[Yy]$ ]]; then
  echo "📴 Stopping Minikube..."
  minikube stop
  echo "✅ Minikube stopped."
else
  echo "🟢 Minikube left running."
fi

print_separator
echo "✅ Cleanup complete."
print_separator
