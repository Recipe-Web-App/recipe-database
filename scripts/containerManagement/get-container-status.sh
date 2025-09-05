#!/bin/bash
# scripts/containerManagement/get-container-status.sh

set -euo pipefail

NAMESPACE="recipe-database"
DEPLOYMENT="postgres-deployment"
SERVICE="postgres-service"
JOB="db-load-schema-job"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "📦 Checking Minikube and Kubernetes resource status..."
print_separator "-"

echo "🔍 Checking Minikube status..."
if minikube status > /dev/null 2>&1; then
  echo "✅ Minikube is running."
else
  echo "❌ Minikube is not running."
fi

print_separator "="
echo "🔍 Checking if namespace '$NAMESPACE' exists..."
if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
  echo "✅ Namespace exists."
else
  echo "❌ Namespace does not exist. Exiting."
  exit 0
fi

print_separator "="
echo "🔍 Checking Deployment '$DEPLOYMENT'..."
if kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not-found | grep -q "$DEPLOYMENT"; then
  echo "✅ Deployment exists."
else
  echo "❌ Deployment not found."
fi

print_separator "="
echo "🔍 Checking Service '$SERVICE'..."
if kubectl get service "$SERVICE" -n "$NAMESPACE" --ignore-not-found | grep -q "$SERVICE"; then
  echo "✅ Service exists."
else
  echo "❌ Service not found."
fi

print_separator "="
echo "🔍 Checking Job '$JOB'..."
if kubectl get job "$JOB" -n "$NAMESPACE" --ignore-not-found | grep -q "$JOB"; then
  echo "✅ Job exists."
else
  echo "❌ Job not found."
fi

print_separator "="
echo "🔍 Checking PVCs in namespace '$NAMESPACE'..."
kubectl get pvc -n "$NAMESPACE" || echo "❌ No PVCs found."


print_separator "="
echo "🔍 Checking kubectl proxy status..."
PROXY_PID=$(pgrep -f "kubectl proxy" || true)
if [[ -n "$PROXY_PID" ]]; then
  echo "✅ kubectl proxy is running (PID $PROXY_PID)"
else
  echo "❌ kubectl proxy not running."
fi

print_separator "="
echo "📊 Container status check complete."
print_separator "="
