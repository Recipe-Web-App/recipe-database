#!/bin/bash
# scripts/containerManagement/get-supporting-services-status.sh

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

# Function to check resource status with colored output
function check_resource_status() {
  local resource_type="$1"
  local resource_name="$2"
  local namespace="$3"
  local description="$4"

  if kubectl get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
    echo "  ✅ $description"
    return 0
  else
    echo "  ❌ $description"
    return 1
  fi
}

# Function to get pod container status
function get_container_status() {
  local pod_name="$1"
  local container_name="$2"
  local namespace="$3"

  local status
  status=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].ready}" 2>/dev/null || echo "false")

  if [[ "$status" == "true" ]]; then
    echo "✅ Running"
  elif [[ "$status" == "false" ]]; then
    echo "❌ Not Ready"
  else
    echo "❓ Not Found"
  fi
}

print_separator "="
echo "📊 PostgreSQL Monitoring Supporting Services Status"
print_separator "="

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Namespace '$NAMESPACE' not found!"
  echo "   Please run deploy-container.sh first to create the namespace."
  exit 1
fi

print_separator "="
echo "🔍 Main Database Status:"
print_separator "-"

if kubectl get deployment recipe-database -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "  ✅ Main deployment: recipe-database"

  # Get pod information
  POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=recipe-database -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

  if [[ -n "$POD_NAME" ]]; then
    echo "  📦 Pod: $POD_NAME"

    # Check main PostgreSQL container
    PG_STATUS=$(get_container_status "$POD_NAME" "recipe-database" "$NAMESPACE")
    echo "  🐘 PostgreSQL container: $PG_STATUS"

    # Check postgres_exporter container
    EXPORTER_STATUS=$(get_container_status "$POD_NAME" "postgres-exporter" "$NAMESPACE")
    echo "  📊 postgres_exporter container: $EXPORTER_STATUS"
  else
    echo "  ❌ No pods found for recipe-database"
  fi
else
  echo "  ❌ Main deployment: recipe-database (not found)"
  echo "     Please run deploy-container.sh first."
  exit 1
fi

print_separator "="
echo "🔧 Supporting Services Status:"
print_separator "-"

# Check ConfigMap
check_resource_status "configmap" "postgres-exporter-config" "$NAMESPACE" "postgres_exporter ConfigMap"

# Check ServiceMonitor
if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  check_resource_status "servicemonitor" "recipe-database-postgres-exporter" "$NAMESPACE" "ServiceMonitor (Prometheus discovery)"
else
  echo "  ⚠️  ServiceMonitor (Prometheus Operator CRD not available)"
fi

# Check PrometheusRule
if kubectl get crd prometheusrules.monitoring.coreos.com >/dev/null 2>&1; then
  check_resource_status "prometheusrule" "recipe-database-alerts" "$NAMESPACE" "PrometheusRule (alerting rules)"
else
  echo "  ⚠️  PrometheusRule (Prometheus Operator CRD not available)"
fi

# Check Service ports
echo ""
echo "🌐 Service Configuration:"
SERVICE_PORTS=$(kubectl get service recipe-database-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].name}' 2>/dev/null || echo "")
if echo "$SERVICE_PORTS" | grep -q "metrics"; then
  echo "  ✅ Metrics port (9187) exposed in service"
else
  echo "  ❌ Metrics port (9187) not exposed in service"
fi

if echo "$SERVICE_PORTS" | grep -q "postgres"; then
  echo "  ✅ PostgreSQL port (5432) exposed in service"
else
  echo "  ❌ PostgreSQL port (5432) not exposed in service"
fi

print_separator "="
echo "🧪 Functional Tests:"
print_separator "-"

if [[ -n "$POD_NAME" ]]; then
  # Test PostgreSQL connectivity
  echo "🐘 Testing PostgreSQL connectivity..."
  if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c recipe-database -- pg_isready -U postgres >/dev/null 2>&1; then
    echo "  ✅ PostgreSQL is accepting connections"
  else
    echo "  ❌ PostgreSQL is not accepting connections"
  fi

  # Test metrics endpoint
  echo "📊 Testing postgres_exporter metrics endpoint..."
  if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres-exporter -- wget -q -O- http://localhost:9187/metrics 2>/dev/null | head -1 | grep -q "HELP\|TYPE" 2>/dev/null; then
    echo "  ✅ Metrics endpoint is responding"

    # Count metrics
    METRIC_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres-exporter -- wget -q -O- http://localhost:9187/metrics 2>/dev/null | grep -c "^pg_" || echo "0")
    echo "  📈 Available metrics: $METRIC_COUNT"
  else
    echo "  ❌ Metrics endpoint is not responding"
  fi

  # Test custom queries
  echo "📝 Testing custom recipe metrics..."
  if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres-exporter -- wget -q -O- http://localhost:9187/metrics 2>/dev/null | grep -q "recipe_stats\|user_activity" 2>/dev/null; then
    echo "  ✅ Custom recipe metrics are available"
  else
    echo "  ⚠️  Custom recipe metrics not found (may require monitoring user setup)"
  fi
fi

print_separator "="
echo "📋 Summary:"
print_separator "-"

# Determine overall status
OVERALL_STATUS="✅ Healthy"

if [[ -z "$POD_NAME" ]]; then
  OVERALL_STATUS="❌ Critical - No pods found"
elif [[ "$(get_container_status "$POD_NAME" "recipe-database" "$NAMESPACE")" != "✅ Running" ]]; then
  OVERALL_STATUS="❌ Critical - Main database not running"
elif [[ "$(get_container_status "$POD_NAME" "postgres-exporter" "$NAMESPACE")" != "✅ Running" ]]; then
  OVERALL_STATUS="⚠️  Warning - Monitoring not available"
fi

echo "🎯 Overall Status: $OVERALL_STATUS"

print_separator "="
echo "🔗 Access Information:"
print_separator "-"

if [[ -n "$POD_NAME" ]]; then
  echo "📊 Metrics Endpoint:"
  echo "   kubectl port-forward -n $NAMESPACE $POD_NAME 9187:9187"
  echo "   Then visit: http://localhost:9187/metrics"
  echo ""
  echo "🐘 PostgreSQL Access:"
  echo "   kubectl port-forward -n $NAMESPACE $POD_NAME 5432:5432"
  echo "   Then connect to: localhost:5432"
  echo ""
  echo "📜 View Logs:"
  echo "   PostgreSQL:       kubectl logs -n $NAMESPACE $POD_NAME -c recipe-database"
  echo "   postgres_exporter: kubectl logs -n $NAMESPACE $POD_NAME -c postgres-exporter"
fi

print_separator "="
echo "🛠️  Quick Actions:"
print_separator "-"

echo "🚀 Deploy/Update Supporting Services:"
echo "   ./scripts/containerManagement/deploy-supporting-services.sh"
echo ""
echo "🧹 Remove Supporting Services:"
echo "   ./scripts/containerManagement/cleanup-supporting-services.sh"
echo ""
echo "🔧 Setup Monitoring User:"
echo "   ./scripts/dbManagement/setup-monitoring-user.sh"
echo ""
echo "📚 Full Documentation:"
echo "   monitoring/README.md"

print_separator "="
