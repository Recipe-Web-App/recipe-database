#!/bin/bash
# scripts/dbManagement/setup-monitoring-user.sh
# Set up PostgreSQL monitoring user via direct NodePort connection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_db-common.sh
source "$SCRIPT_DIR/_db-common.sh"

NAMESPACE="recipe-database"

# Default monitoring user credentials (can be overridden by environment)
MONITORING_USER="${MONITORING_USER:-postgres_exporter}"
MONITORING_PASSWORD="${MONITORING_PASSWORD:-$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)}"

print_separator "="
log_info "Setting up PostgreSQL Monitoring User"
print_separator "="

log_info "Loading environment variables..."
load_env

# Verify required tools
require_commands psql kubectl || exit 1

print_separator "="
log_info "Monitoring User Configuration:"
print_separator "-"

log_info "Username: $MONITORING_USER"
if [[ "${MONITORING_PASSWORD}" == "${MONITORING_PASSWORD:-}" ]]; then
  log_info "Password: [Auto-generated secure password]"
else
  log_info "Password: [Using provided password]"
fi

print_separator "="
log_info "Testing database connectivity..."
print_separator "-"

check_db_connection "$POSTGRES_USER" "POSTGRES_PASSWORD" || exit 1

print_separator "="
log_info "Creating monitoring user..."
print_separator "-"

# Create temporary SQL script with substituted values
TEMP_SQL=$(mktemp)
trap 'rm -f $TEMP_SQL' EXIT

# Generate SQL script with substituted placeholders
sed -e "s/__MONITORING_USER__/$MONITORING_USER/g" \
  -e "s/__MONITORING_PASSWORD__/$MONITORING_PASSWORD/g" \
  -e "s/__POSTGRES_DB__/$POSTGRES_DB/g" \
  "$LOCAL_PATH/db/init/users/005_create_monitoring_user.sql" >"$TEMP_SQL"

# Execute the SQL script with admin user
log_info "Executing user creation script..."
if PGPASSWORD="$POSTGRES_PASSWORD" psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -f "$TEMP_SQL"; then
  log_success "Monitoring user created successfully"
else
  log_error "Failed to create monitoring user"
  exit 1
fi

print_separator "="
log_info "Testing monitoring user permissions..."
print_separator "-"

# Test basic connectivity with monitoring user
log_info "Testing user authentication..."
if PGPASSWORD="$MONITORING_PASSWORD" psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$MONITORING_USER" \
  -d "$POSTGRES_DB" \
  -c "SELECT version();" >/dev/null 2>&1; then
  log_success "Monitoring user can authenticate"
else
  log_error "Monitoring user authentication failed"
  exit 1
fi

# Test access to system tables
log_info "Testing access to system tables..."
if PGPASSWORD="$MONITORING_PASSWORD" psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$MONITORING_USER" \
  -d "$POSTGRES_DB" \
  -c "SELECT count(*) FROM pg_stat_database;" >/dev/null 2>&1; then
  log_success "Monitoring user can access system tables"
else
  log_warning "Monitoring user cannot access system tables"
fi

# Test access to recipe_manager tables
log_info "Testing access to recipe_manager schema..."
if PGPASSWORD="$MONITORING_PASSWORD" psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$MONITORING_USER" \
  -d "$POSTGRES_DB" \
  -c "SELECT count(*) FROM recipe_manager.recipes;" >/dev/null 2>&1; then
  log_success "Monitoring user can access recipe_manager tables"
else
  log_warning "Monitoring user cannot access recipe_manager tables (may be empty or not initialized)"
fi

print_separator "="
log_info "Updating Kubernetes Secret..."
print_separator "-"

# Create the DATA_SOURCE_NAME for postgres_exporter
DATA_SOURCE_NAME="postgresql://${MONITORING_USER}:${MONITORING_PASSWORD}@localhost:5432/${POSTGRES_DB}?sslmode=disable"

# Update the secret with the monitoring user credentials
log_info "Adding POSTGRES_EXPORTER_DATA_SOURCE_NAME to secret..."

# Get current secret data
CURRENT_SECRET=$(kubectl get secret recipe-database-secret -n "$NAMESPACE" -o json 2>/dev/null || echo '{"data":{}}')

# Add the new data source name to the secret
echo "$CURRENT_SECRET" |
  jq --arg dsn "$(echo -n "$DATA_SOURCE_NAME" | base64 -w 0)" \
    '.data.POSTGRES_EXPORTER_DATA_SOURCE_NAME = $dsn' |
  kubectl apply -f -

log_success "Secret updated with monitoring user credentials"

print_separator "="
log_info "Checking for postgres_exporter..."
print_separator "-"

# Check if postgres_exporter deployment exists
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=recipe-database -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)

if [[ -n "$POD_NAME" ]] && kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | grep -q postgres-exporter; then
  log_info "Found postgres_exporter container, restarting deployment..."

  kubectl rollout restart deployment/recipe-database -n "$NAMESPACE"
  kubectl rollout status deployment/recipe-database -n "$NAMESPACE" --timeout=120s

  # Get the new pod name
  POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=recipe-database -o jsonpath="{.items[0].metadata.name}")

  log_info "Waiting for postgres_exporter to be ready..."
  sleep 30

  # Test metrics endpoint
  if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres-exporter -- wget -q -O- http://localhost:9187/metrics 2>/dev/null | head -5 >/dev/null; then
    log_success "postgres_exporter is working with new credentials"
  else
    log_warning "postgres_exporter is not responding with new credentials"
    log_info "Check logs: kubectl logs -n $NAMESPACE $POD_NAME -c postgres-exporter"
  fi
else
  log_info "postgres_exporter container not found"
  log_info "Run deploy-supporting-services.sh to add monitoring"
fi

print_separator "="
log_info "Setup Summary:"
print_separator "-"

log_success "Monitoring user created: $MONITORING_USER"
log_info "User permissions configured for:"
log_info "   - PostgreSQL system tables"
log_info "   - recipe_manager schema tables"
log_info "   - pg_stat_statements (if available)"
log_success "Kubernetes secret updated"

print_separator "="
log_info "Connection Information:"
print_separator "-"

log_info "Data Source Name (for manual configuration):"
log_info "   postgresql://${MONITORING_USER}:[password]@localhost:5432/${POSTGRES_DB}?sslmode=disable"
log_info ""
log_info "Monitoring user credentials stored in:"
log_info "   Secret: recipe-database-secret"
log_info "   Key: POSTGRES_EXPORTER_DATA_SOURCE_NAME"

print_separator "="
log_info "Next Steps:"
print_separator "-"

log_info "1. Check monitoring status:"
log_info "   ./scripts/containerManagement/get-supporting-services-status.sh"
log_info ""
log_info "2. Access metrics:"
log_info "   kubectl port-forward -n $NAMESPACE svc/postgres-exporter-service 9187:9187"
log_info "   curl http://localhost:9187/metrics"
log_info ""
log_info "3. Import Grafana dashboard:"
log_info "   monitoring/grafana-dashboards/postgresql-overview.json"

print_separator "="
log_success "Monitoring user setup complete!"
print_separator "="
