#!/bin/bash
# scripts/containerManagement/cleanup-supporting-services.sh

set -euo pipefail

NAMESPACE="recipe-database"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "🧹 Cleaning up PostgreSQL Monitoring Supporting Services..."
print_separator "-"

# Function to safely delete Kubernetes resources
function safe_delete() {
  local resource_type="$1"
  local resource_name="$2"
  local namespace="$3"

  if kubectl get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
    kubectl delete "$resource_type" "$resource_name" -n "$namespace"
    echo "✅ Deleted $resource_type: $resource_name"
  else
    echo "ℹ️  $resource_type $resource_name not found (already cleaned up)"
  fi
}

print_separator "="
echo "🔍 Removing ServiceMonitor..."
print_separator "-"

safe_delete "servicemonitor" "recipe-database-postgres-exporter" "$NAMESPACE"

print_separator "="
echo "🚨 Removing PrometheusRule..."
print_separator "-"

safe_delete "prometheusrule" "recipe-database-alerts" "$NAMESPACE"

print_separator "="
echo "📊 Removing postgres_exporter ConfigMap..."
print_separator "-"

safe_delete "configmap" "postgres-exporter-config" "$NAMESPACE"

print_separator "="
echo "🔄 Restarting main deployment to remove monitoring sidecar..."
print_separator "-"

# First, we need to update the deployment to remove the postgres_exporter container
# This creates a temporary deployment without the sidecar
echo "📝 Creating temporary deployment without postgres_exporter sidecar..."

# Create a backup of the current deployment
kubectl get deployment recipe-database -n "$NAMESPACE" -o yaml > /tmp/recipe-database-deployment-backup.yaml

# Get the current deployment and remove postgres_exporter container
kubectl get deployment recipe-database -n "$NAMESPACE" -o json | \
  jq 'del(.spec.template.spec.containers[] | select(.name == "postgres-exporter"))' | \
  jq 'del(.spec.template.spec.volumes[] | select(.name == "postgres-exporter-config"))' | \
  kubectl apply -f -

echo "⏳ Waiting for deployment to update..."
kubectl rollout status deployment/recipe-database -n "$NAMESPACE" --timeout=120s

print_separator "="
echo "🧪 Verifying cleanup..."
print_separator "-"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=recipe-database -o jsonpath="{.items[0].metadata.name}")

# Check if postgres_exporter container is gone
if kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' | grep -q postgres-exporter; then
  echo "⚠️  postgres_exporter container still present in pod"
else
  echo "✅ postgres_exporter container successfully removed from pod"
fi

# Check if metrics port is no longer accessible
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- nc -z localhost 9187 2>/dev/null; then
  echo "⚠️  Metrics port 9187 still accessible"
else
  echo "✅ Metrics port 9187 no longer accessible"
fi

print_separator "="
echo "📋 Cleanup Summary:"
print_separator "-"

echo "🧹 Removed Components:"
if ! kubectl get servicemonitor recipe-database-postgres-exporter -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "  ✅ ServiceMonitor (Prometheus discovery)"
else
  echo "  ❌ ServiceMonitor (still present)"
fi

if ! kubectl get prometheusrule recipe-database-alerts -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "  ✅ PrometheusRule (alerting rules)"
else
  echo "  ❌ PrometheusRule (still present)"
fi

if ! kubectl get configmap postgres-exporter-config -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "  ✅ postgres_exporter ConfigMap"
else
  echo "  ❌ postgres_exporter ConfigMap (still present)"
fi

if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' | grep -q postgres-exporter; then
  echo "  ✅ postgres_exporter sidecar container"
else
  echo "  ❌ postgres_exporter sidecar container (still present)"
fi

print_separator "="
echo "🔗 Remaining Resources:"
print_separator "-"

echo "✅ Main database deployment: recipe-database"
echo "✅ Main database service: recipe-database-service"
echo "✅ Database data (PVC): recipe-database-pvc"

print_separator "="
echo "ℹ️  Information:"
print_separator "-"

echo "📁 Backup of original deployment saved to:"
echo "   /tmp/recipe-database-deployment-backup.yaml"
echo ""
echo "🔄 To restore monitoring, run:"
echo "   ./scripts/containerManagement/deploy-supporting-services.sh"
echo ""
echo "🗑️  To completely remove the database, run:"
echo "   ./scripts/containerManagement/cleanup-container.sh"

print_separator "="
echo "✅ Supporting services cleanup complete!"
print_separator "="
