#!/bin/bash
# scripts/containerManagement/deploy-supporting-services.sh

set -euo pipefail

NAMESPACE="recipe-database"
CONFIG_DIR="k8s"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "🔧 Deploying PostgreSQL Monitoring Supporting Services..."
print_separator "-"

# Check if main database is running
if ! kubectl get deployment recipe-database -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "⚠️  Main recipe-database deployment not found."
  echo "    Please deploy the main container first using deploy-container.sh"
  exit 1
fi

# Check if main database is ready
if ! kubectl get pods -n "$NAMESPACE" -l app=recipe-database --field-selector=status.phase=Running | grep -q Running; then
  echo "⚠️  Main recipe-database pod is not running."
  echo "    Please ensure the main container is healthy before deploying supporting services."
  exit 1
fi

print_separator "="
echo "📊 Deploying postgres_exporter ConfigMap..."
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/postgres-exporter-configmap.yaml"
echo "✅ postgres_exporter ConfigMap applied."

print_separator "="
echo "📊 Deploying postgres_exporter deployment..."
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/postgres-exporter-deployment.yaml"
kubectl apply -f "${CONFIG_DIR}/postgres-exporter-service.yaml"
echo "✅ postgres_exporter deployment and service applied."

print_separator "="
echo "🔍 Deploying ServiceMonitor for Prometheus discovery..."
print_separator "-"

if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  kubectl apply -f "${CONFIG_DIR}/servicemonitor.yaml"
  echo "✅ ServiceMonitor applied."
else
  echo "⚠️  ServiceMonitor CRD not found. Skipping ServiceMonitor deployment."
  echo "    This is normal if you're not using Prometheus Operator."
  echo "    You can still use manual Prometheus configuration."
fi

print_separator "="
echo "🚨 Deploying PrometheusRule for alerting..."
print_separator "-"

if kubectl get crd prometheusrules.monitoring.coreos.com >/dev/null 2>&1; then
  kubectl apply -f "${CONFIG_DIR}/prometheusrule.yaml"
  echo "✅ PrometheusRule applied."
else
  echo "⚠️  PrometheusRule CRD not found. Skipping PrometheusRule deployment."
  echo "    This is normal if you're not using Prometheus Operator."
  echo "    You can still configure alerts manually in Prometheus."
fi

print_separator "="
echo "⏳ Waiting for postgres_exporter deployment to be ready..."
print_separator "-"

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Available deployment/postgres-exporter \
  --timeout=120s

print_separator "="
echo "🧪 Testing postgres_exporter metrics endpoint..."
print_separator "-"

# Wait for the deployment to be ready
kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod \
  --selector=app=postgres-exporter \
  --timeout=120s

# Test if metrics endpoint is accessible
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=postgres-exporter -o jsonpath="{.items[0].metadata.name}")

if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- wget -q -O- http://localhost:9187/metrics | head -5 >/dev/null 2>&1; then
  echo "✅ postgres_exporter metrics endpoint is responding."
else
  echo "⚠️  postgres_exporter metrics endpoint test failed."
  echo "    Check the logs: kubectl logs -n $NAMESPACE $POD_NAME"
fi

print_separator "="
echo "📋 Deployment Summary:"
print_separator "-"

echo "🎯 Deployed Components:"
echo "  ✅ postgres_exporter ConfigMap"
if kubectl get servicemonitor recipe-database-postgres-exporter -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "  ✅ ServiceMonitor (Prometheus discovery)"
else
  echo "  ⚠️  ServiceMonitor (not deployed - Prometheus Operator not found)"
fi
if kubectl get prometheusrule recipe-database-alerts -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "  ✅ PrometheusRule (alerting rules)"
else
  echo "  ⚠️  PrometheusRule (not deployed - Prometheus Operator not found)"
fi
echo "  ✅ postgres_exporter deployment"

print_separator "="
echo "🔗 Access Information:"
print_separator "-"

echo "📊 Metrics Endpoint:"
echo "  URL: http://postgres-exporter-service.$NAMESPACE.svc.cluster.local:9187/metrics"
echo "  Pod: $POD_NAME"

echo ""
echo "🎛️  Grafana Dashboard:"
echo "  Import: monitoring/grafana-dashboards/postgresql-overview.json"

echo ""
echo "📚 Documentation:"
echo "  Setup Guide: monitoring/README.md"

print_separator "="
echo "✅ Supporting services deployment complete!"
print_separator "="

echo ""
echo "🚀 Next Steps:"
echo "1. Ensure monitoring database user is created:"
echo "   ./scripts/dbManagement/setup-monitoring-user.sh"
echo ""
echo "2. Import Grafana dashboard from:"
echo "   monitoring/grafana-dashboards/postgresql-overview.json"
echo ""
echo "3. Check metrics are being collected:"
echo "   kubectl port-forward -n $NAMESPACE svc/postgres-exporter-service 9187:9187"
echo "   curl http://localhost:9187/metrics"
echo ""
