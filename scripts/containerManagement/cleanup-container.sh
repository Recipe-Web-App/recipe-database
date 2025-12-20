#!/bin/bash
# scripts/containerManagement/cleanup-container.sh

set -euo pipefail

NAMESPACE="recipe-database"
IMAGE_NAME="recipe-database"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "🧪 Checking Minikube status..."
print_separator "-"

if ! minikube status >/dev/null 2>&1; then
  echo "⚠️ Minikube is not running. Starting Minikube..."
  if ! minikube start; then
    echo "❌ Failed to start Minikube. Exiting."
    exit 1
  fi
else
  echo "✅ Minikube is already running."
fi

print_separator "="
echo "🧹 Deleting Kubernetes resources in namespace '$NAMESPACE'..."
print_separator "-"

kubectl delete -f k8s/configmap-template.yaml -n "$NAMESPACE" --ignore-not-found
kubectl delete -f k8s/deployment.yaml -n "$NAMESPACE" --ignore-not-found
kubectl delete -f k8s/secret-template.yaml -n "$NAMESPACE" --ignore-not-found
kubectl delete -f k8s/service-template.yaml -n "$NAMESPACE" --ignore-not-found

print_separator "="
echo "🧹 Deleting database initialization job..."
print_separator "-"

kubectl delete job db-load-schema-job -n "$NAMESPACE" --ignore-not-found

print_separator "="
echo "🧹 Deleting database load test fixture job..."
print_separator "-"

kubectl delete job db-load-test-fixtures-job -n "$NAMESPACE" --ignore-not-found

print_separator "="
echo "🧹 Deleting database import nutritional data job..."
print_separator "-"

kubectl delete job db-import-nutritional-data-job -n "$NAMESPACE" --ignore-not-found

print_separator "="
read -r -p "⚠️ Do you want to delete the PersistentVolumeClaim (PVC)? This will delete all stored database data! (y/N): " del_pvc
print_separator "-"

if [[ "$del_pvc" =~ ^[Yy]$ ]]; then
  kubectl delete -f k8s/pvc.yaml -n "$NAMESPACE" --ignore-not-found
  kubectl delete pv -l app=recipe-database
  echo "🧨 PVC deleted."
else
  echo "💾 PVC retained."
fi

print_separator "="
echo "🐳 Removing Docker image '${FULL_IMAGE_NAME}' from Minikube..."
print_separator "-"

eval "$(minikube docker-env)"
docker rmi -f "$FULL_IMAGE_NAME" || echo "Image not found or already removed."

print_separator "="
read -r -p "🛑 Do you want to stop (shut down) Minikube now? (y/N): " stop_mk
print_separator "-"

if [[ "$stop_mk" =~ ^[Yy]$ ]]; then
  echo "📴 Stopping Minikube..."
  minikube stop
  echo "✅ Minikube stopped."
else
  echo "🟢 Minikube left running."
fi

print_separator "="
echo "🌐 Removing recipe-database.local from /etc/hosts..."
print_separator "-"

DB_HOSTNAME="recipe-database.local"
if grep -q "$DB_HOSTNAME" /etc/hosts; then
  sed -i "/$DB_HOSTNAME/d" /etc/hosts
  echo "✅ Removed $DB_HOSTNAME from /etc/hosts"
else
  echo "ℹ️ No $DB_HOSTNAME entry found in /etc/hosts"
fi

print_separator "="
echo "✅ Cleanup complete."
print_separator "="
