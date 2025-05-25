#!/bin/bash
# scripts/containerManagement/stop-container.sh

set -euo pipefail

NAMESPACE="recipe-db"
MOUNT_PATH="/mnt/recipe-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MOUNT_CMD="minikube mount ${LOCAL_PATH}:${MOUNT_PATH}"

# Utility function for printing section separators
print_separator() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

print_separator
echo "⏹️ Stopping PostgreSQL deployment in namespace: $NAMESPACE"
print_separator

kubectl delete deployment postgres-deployment -n "$NAMESPACE" --ignore-not-found
kubectl delete service postgres-service -n "$NAMESPACE" --ignore-not-found

print_separator
read -rp "🛑 Do you want to stop the Minikube mount process? (y/N) " STOP_MOUNT
print_separator

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

print_separator
read -rp "🛑 Do you want to stop Minikube? (y/N) " STOP_MINIKUBE
print_separator

if [[ "$STOP_MINIKUBE" =~ ^[Yy]$ ]]; then
  echo "🛑 Stopping Minikube..."
  minikube stop
  echo "✅ Minikube stopped."
else
  echo "⏭️ Minikube left running."
fi

print_separator
read -rp "🛑 Do you want to stop kubectl proxy? (y/N) " STOP_PROXY
print_separator

if [[ "$STOP_PROXY" =~ ^[Yy]$ ]]; then
  PROXY_PID=$(pgrep -f "kubectl proxy" || true)
  if [[ -n "$PROXY_PID" ]]; then
    echo "🛑 Stopping kubectl proxy (PID $PROXY_PID)..."
    kill "$PROXY_PID"
    echo "✅ kubectl proxy stopped."
  else
    echo "ℹ️ kubectl proxy is not running."
  fi
else
  echo "⏭️ kubectl proxy left running."
fi

print_separator
echo "✅ PostgreSQL deployment stopped. PVC and other resources remain intact."
print_separator
