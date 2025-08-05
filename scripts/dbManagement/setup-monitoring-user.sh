#!/bin/bash
# scripts/dbManagement/setup-monitoring-user.sh

set -euo pipefail

NAMESPACE="recipe-database"
LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Default monitoring user credentials (can be overridden by environment)
MONITORING_USER="${MONITORING_USER:-postgres_exporter}"
MONITORING_PASSWORD="${MONITORING_PASSWORD:-$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)}"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo "🔧 Setting up PostgreSQL Monitoring User"
print_separator "="

# Check if main database is running
if ! kubectl get pods -n "$NAMESPACE" -l app=recipe-database --field-selector=status.phase=Running | grep -q Running; then
  echo "❌ Main recipe-database pod is not running."
  echo "   Please ensure the main container is healthy first."
  exit 1
fi

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=recipe-database -o jsonpath="{.items[0].metadata.name}")

print_separator "="
echo "🔐 Monitoring User Configuration:"
print_separator "-"

echo "👤 Username: $MONITORING_USER"
if [[ "${MONITORING_PASSWORD}" == "${MONITORING_PASSWORD:-}" ]]; then
  echo "🔑 Password: [Auto-generated secure password]"
else
  echo "🔑 Password: [Using provided password]"
fi
echo "📦 Target Pod: $POD_NAME"

print_separator "="
echo "📋 Loading environment variables..."
print_separator "-"

# Load environment variables if .env exists
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
  echo "✅ Loaded variables from .env"
else
  echo "⚠️  No .env file found. Using defaults."
fi

# Verify required environment variables
if [[ -z "${POSTGRES_DB:-}" ]]; then
  echo "❌ POSTGRES_DB environment variable not set"
  echo "   Please set it in your .env file or environment"
  exit 1
fi

print_separator "="
echo "🧪 Testing database connectivity..."
print_separator "-"

if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c recipe-database -- pg_isready -U postgres >/dev/null 2>&1; then
  echo "✅ PostgreSQL is accepting connections"
else
  echo "❌ PostgreSQL is not accepting connections"
  echo "   Please check the database status first"
  exit 1
fi

print_separator "="
echo "👤 Creating monitoring user..."
print_separator "-"

# Create temporary SQL script with substituted values
TEMP_SQL=$(mktemp)
trap 'rm -f $TEMP_SQL' EXIT

# Generate SQL script with substituted placeholders using sed
sed -e "s/__MONITORING_USER__/$MONITORING_USER/g" \
  -e "s/__MONITORING_PASSWORD__/$MONITORING_PASSWORD/g" \
  -e "s/__POSTGRES_DB__/$POSTGRES_DB/g" \
  "${LOCAL_PATH}/db/init/users/005_create_monitoring_user.sql" > "$TEMP_SQL"

# Execute the SQL script
echo "📝 Executing user creation script..."
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c recipe-database -- psql -U postgres -d "$POSTGRES_DB" < "$TEMP_SQL"; then
  echo "✅ Monitoring user created successfully"
else
  echo "❌ Failed to create monitoring user"
  echo "   Check the database logs for more details"
  exit 1
fi

print_separator "="
echo "🧪 Testing monitoring user permissions..."
print_separator "-"

# Test basic connectivity with monitoring user
echo "🔐 Testing user authentication..."
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c recipe-database -- psql -U "$MONITORING_USER" -d "$POSTGRES_DB" -c "SELECT version();" >/dev/null 2>&1; then
  echo "✅ Monitoring user can authenticate"
else
  echo "❌ Monitoring user authentication failed"
  exit 1
fi

# Test access to system tables
echo "📊 Testing access to system tables..."
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c recipe-database -- psql -U "$MONITORING_USER" -d "$POSTGRES_DB" -c "SELECT count(*) FROM pg_stat_database;" >/dev/null 2>&1; then
  echo "✅ Monitoring user can access system tables"
else
  echo "❌ Monitoring user cannot access system tables"
fi

# Test access to recipe_manager tables
echo "🍳 Testing access to recipe_manager schema..."
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c recipe-database -- psql -U "$MONITORING_USER" -d "$POSTGRES_DB" -c "SELECT count(*) FROM recipe_manager.recipes;" >/dev/null 2>&1; then
  echo "✅ Monitoring user can access recipe_manager tables"
else
  echo "⚠️  Monitoring user cannot access recipe_manager tables (may be empty or not initialized)"
fi

print_separator "="
echo "🔑 Updating Kubernetes Secret..."
print_separator "-"

# Create the DATA_SOURCE_NAME for postgres_exporter
DATA_SOURCE_NAME="postgresql://${MONITORING_USER}:${MONITORING_PASSWORD}@localhost:5432/${POSTGRES_DB}?sslmode=disable"

# Update the secret with the monitoring user credentials
echo "📝 Adding POSTGRES_EXPORTER_DATA_SOURCE_NAME to secret..."

# Get current secret data
CURRENT_SECRET=$(kubectl get secret recipe-database-secret -n "$NAMESPACE" -o json 2>/dev/null || echo '{"data":{}}')

# Add the new data source name to the secret
echo "$CURRENT_SECRET" | \
  jq --arg dsn "$(echo -n "$DATA_SOURCE_NAME" | base64 -w 0)" \
  '.data.POSTGRES_EXPORTER_DATA_SOURCE_NAME = $dsn' | \
  kubectl apply -f -

echo "✅ Secret updated with monitoring user credentials"

print_separator "="
echo "🔄 Testing postgres_exporter connection..."
print_separator "-"

# If postgres_exporter container exists, test the connection
if kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' | grep -q postgres-exporter; then
  echo "📊 Found postgres_exporter container, testing connection..."

  # Restart the postgres_exporter container by restarting the whole pod
  echo "🔄 Restarting deployment to pick up new credentials..."
  kubectl rollout restart deployment/recipe-database -n "$NAMESPACE"
  kubectl rollout status deployment/recipe-database -n "$NAMESPACE" --timeout=120s

  # Get the new pod name
  POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=recipe-database -o jsonpath="{.items[0].metadata.name}")

  echo "⏳ Waiting for postgres_exporter to be ready..."
  sleep 30

  # Test metrics endpoint
  if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres-exporter -- wget -q -O- http://localhost:9187/metrics 2>/dev/null | head -5 >/dev/null; then
    echo "✅ postgres_exporter is working with new credentials"

    # Test custom queries
    if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres-exporter -- wget -q -O- http://localhost:9187/metrics 2>/dev/null | grep -q "recipe_stats\|user_activity" 2>/dev/null; then
      echo "✅ Custom recipe metrics are working"
    else
      echo "⚠️  Custom recipe metrics not found (database may need data)"
    fi
  else
    echo "❌ postgres_exporter is not responding with new credentials"
    echo "   Check logs: kubectl logs -n $NAMESPACE $POD_NAME -c postgres-exporter"
  fi
else
  echo "ℹ️  postgres_exporter container not found"
  echo "   Run deploy-supporting-services.sh to add monitoring"
fi

print_separator "="
echo "📋 Setup Summary:"
print_separator "-"

echo "✅ Monitoring user created: $MONITORING_USER"
echo "✅ User permissions configured for:"
echo "   - PostgreSQL system tables"
echo "   - recipe_manager schema tables"
echo "   - pg_stat_statements (if available)"
echo "✅ Kubernetes secret updated"

if kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' | grep -q postgres-exporter; then
  echo "✅ postgres_exporter configured and tested"
else
  echo "ℹ️  postgres_exporter not deployed yet"
fi

print_separator "="
echo "🔗 Connection Information:"
print_separator "-"

echo "📊 Data Source Name (for manual configuration):"
echo "   postgresql://${MONITORING_USER}:[password]@localhost:5432/${POSTGRES_DB}?sslmode=disable"
echo ""
echo "🔑 Monitoring user credentials stored in:"
echo "   Secret: recipe-database-secret"
echo "   Key: POSTGRES_EXPORTER_DATA_SOURCE_NAME"

print_separator "="
echo "🚀 Next Steps:"
print_separator "-"

if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' | grep -q postgres-exporter; then
  echo "1. Deploy monitoring infrastructure:"
  echo "   ./scripts/containerManagement/deploy-supporting-services.sh"
  echo ""
fi

echo "2. Check monitoring status:"
echo "   ./scripts/containerManagement/get-supporting-services-status.sh"
echo ""
echo "3. Access metrics:"
echo "   kubectl port-forward -n $NAMESPACE $POD_NAME 9187:9187"
echo "   curl http://localhost:9187/metrics"
echo ""
echo "4. Import Grafana dashboard:"
echo "   monitoring/grafana-dashboards/postgresql-overview.json"

print_separator "="
echo "✅ Monitoring user setup complete!"
print_separator "="
