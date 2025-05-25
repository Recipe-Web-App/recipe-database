#!/bin/bash

set -euo pipefail

NAMESPACE="recipe-db"
MOUNT_PATH="/mnt/recipe-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MOUNT_CMD="minikube mount ${LOCAL_PATH}:${MOUNT_PATH}"

echo "⏹️ Stopping PostgreSQL deployment in namespace: $NAMESPACE"

kubectl delete deployment postgres-deployment -n "$NAMESPACE" --ignore-not-found
kubectl delete service postgres-service -n "$NAMESPACE" --ignore-not-found

# 🛑 Optionally kill the Minikube mount process
read -rp "Do you want to stop the Minikube mount process? (y/N) " STOP_MOUNT
if [[ "$STOP_MOUNT" =~ ^[Yy]$ ]]; then
  if pgrep -f "$MOUNT_CMD" > /dev/null; then
    echo "🛑 Stopping Minikube mount..."
    pkill -f "$MOUNT_CMD"
    echo "✅ Minikube mount stopped."
  else
    echo "ℹ️ Minikube mount not running."
  fi
else
  echo "⏭️ Minikube mount left running."
fi

# 🛑 Optionally stop Minikube
read -rp "Do you want to stop minikube? (y/N) " STOP_MINIKUBE
if [[ "$STOP_MINIKUBE" =~ ^[Yy]$ ]]; then
  echo "🛑 Stopping Minikube..."
  minikube stop
else
  echo "⏭️ Minikube left running."
fi

# 🛑 Optionally stop kubectl proxy
read -rp "Do you want to stop kubectl proxy? (y/N) " STOP_PROXY
if [[ "$STOP_PROXY" =~ ^[Yy]$ ]]; then
  PROXY_PID=$(pgrep -f "kubectl proxy" || true)
  if [[ -n "$PROXY_PID" ]]; then
    echo "🛑 Stopping kubectl proxy (PID $PROXY_PID)..."
    kill "$PROXY_PID"
  else
    echo "ℹ️ kubectl proxy is not running."
  fi
else
  echo "⏭️ kubectl proxy left running."
fi

echo "✅ PostgreSQL deployment stopped. PVC and other resources remain intact."
