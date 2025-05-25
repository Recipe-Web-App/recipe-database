#!/bin/bash
set -euo pipefail

NAMESPACE="recipe-db"
MOUNT_PATH="/mnt/recipe-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MOUNT_CMD="minikube mount ${LOCAL_PATH}:${MOUNT_PATH}"

echo "🧪 Checking Minikube status..."

if ! minikube status >/dev/null 2>&1; then
  echo "⚠️ Minikube is not running. Starting Minikube..."
  if ! minikube start; then
    echo "❌ Failed to start Minikube. Exiting."
    exit 1
  fi
else
  echo "✅ Minikube is already running."
fi

echo "🧹 Deleting Kubernetes resources in namespace '$NAMESPACE'..."

kubectl delete -f k8s/configmap-template.yaml -n "$NAMESPACE" --ignore-not-found
kubectl delete -f k8s/deployment.yaml -n "$NAMESPACE" --ignore-not-found
kubectl delete -f k8s/secret.yaml -n "$NAMESPACE" --ignore-not-found
kubectl delete -f k8s/service.yaml -n "$NAMESPACE" --ignore-not-found

echo "🧹 Deleting database initialization job..."
kubectl delete job db-init-job -n "$NAMESPACE" --ignore-not-found

# 🚫 Kill Minikube mount if running
echo "🔌 Checking for active Minikube mount..."
if pgrep -f "$MOUNT_CMD" > /dev/null; then
  echo "🛑 Killing Minikube mount process..."
  pkill -f "$MOUNT_CMD"
  echo "✅ Minikube mount stopped."
else
  echo "ℹ️ No active Minikube mount found."
fi

# Prompt to delete the PVC
read -r -p "⚠️ Do you want to delete the PersistentVolumeClaim (PVC)? This will delete all stored database data! (y/N): " del_pvc
if [[ "$del_pvc" =~ ^[Yy]$ ]]; then
  kubectl delete -f k8s/pvc.yaml -n "$NAMESPACE" --ignore-not-found
  echo "🧨 PVC deleted."
else
  echo "💾 PVC retained."
fi

# Prompt to stop Minikube
read -r -p "🛑 Do you want to stop (shut down) Minikube now? (y/N): " stop_mk
if [[ "$stop_mk" =~ ^[Yy]$ ]]; then
  echo "📴 Stopping Minikube..."
  minikube stop
  echo "✅ Minikube stopped."
else
  echo "🟢 Minikube left running."
fi

echo "✅ Cleanup complete."
