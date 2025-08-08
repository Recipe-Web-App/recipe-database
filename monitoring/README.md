# PostgreSQL Database Monitoring

This directory contains monitoring configurations for the Recipe Database
PostgreSQL instance using Prometheus and Grafana.

## Overview

The monitoring setup includes:

- **postgres_exporter**: Separate deployment for metrics collection
- **ServiceMonitor**: Prometheus service discovery configuration
- **PrometheusRule**: Alerting rules for critical database conditions
- **Grafana Dashboards**: Pre-configured dashboards for visualization

## Components

### 1. Kubernetes Resources

#### postgres_exporter Configuration

- **Container**: `quay.io/prometheuscommunity/postgres-exporter:v0.15.0`
- **Port**: 9187 (metrics endpoint)
- **Config**: Custom queries in ConfigMap for recipe-specific metrics

#### ServiceMonitor

- **File**: `k8s/servicemonitor.yaml`
- **Purpose**: Enables Prometheus to automatically discover and scrape metrics
- **Scrape Interval**: 30 seconds

#### PrometheusRule

- **File**: `k8s/prometheusrule.yaml`
- **Purpose**: Defines alerting rules and recording rules
- **Alerts**: Database connectivity, performance, and business logic alerts

### 2. Database Configuration

#### Monitoring User

- **File**: `db/init/users/005_create_monitoring_user-template.sql`
- **Purpose**: Creates dedicated user for metrics collection
- **Permissions**: Read-only access to system tables and recipe_manager schema

#### Custom Queries

- **Location**: `db/queries/monitoring/`
- **Files**:
  - `recipe_metrics.sql`: Business metrics and recipe statistics
  - `performance_metrics.sql`: Database performance queries
  - `health_checks.sql`: Health check and diagnostic queries

### 3. Grafana Dashboards

#### PostgreSQL Overview Dashboard

- **File**: `monitoring/grafana-dashboards/postgresql-overview.json`
- **Panels**: Database status, connections, performance, recipe metrics
- **Refresh**: 30 seconds

## Setup Instructions

### 1. Deploy Monitoring User

First, create the monitoring user by applying the template with your environment
variables:

```bash
# Set environment variables
export MONITORING_USER="postgres_exporter"
export MONITORING_PASSWORD="your_secure_password" <!-- pragma: allowlist secret -->
export POSTGRES_DB="your_database_name"

# Apply the user creation script
envsubst < db/init/users/005_create_monitoring_user-template.sql | kubectl exec -i your-postgres-pod -- psql
```

### 2. Update Secret Configuration

Add the postgres_exporter data source configuration to your secret:

```bash
# Create the data source URL
DATA_SOURCE_NAME="postgresql://postgres_exporter:your_secure_password@localhost:5432/your_database_name?sslmode=disable"  <!-- pragma: allowlist secret -->

# Update the Kubernetes secret
kubectl create secret generic recipe-database-secret \
  --from-literal=POSTGRES_EXPORTER_DATA_SOURCE_NAME="$DATA_SOURCE_NAME" \
  --namespace=recipe-database \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 3. Deploy Kubernetes Resources

Apply all monitoring-related Kubernetes resources:

```bash
# Deploy the postgres_exporter configuration
kubectl apply -f k8s/postgres-exporter-configmap.yaml

# Deploy the postgres_exporter deployment and service
kubectl apply -f k8s/postgres-exporter-deployment.yaml
kubectl apply -f k8s/postgres-exporter-service.yaml

# Deploy Prometheus service discovery
kubectl apply -f k8s/servicemonitor.yaml

# Deploy alerting rules
kubectl apply -f k8s/prometheusrule.yaml
```

Or use the convenience script:

```bash
# Deploy all monitoring components
./scripts/containerManagement/deploy-supporting-services.sh
```

### 4. Import Grafana Dashboard

1. Open your Grafana instance
2. Navigate to **Dashboards > Import**
3. Upload the JSON file:
   `monitoring/grafana-dashboards/postgresql-overview.json`
4. Configure the Prometheus data source if not already set

## Metrics Available

### Standard PostgreSQL Metrics

- Database connectivity and uptime
- Connection counts and states
- Query performance and execution time
- Buffer cache hit ratio
- Lock information and deadlocks
- Replication lag (if applicable)
- Table and index sizes
- Transaction rates and rollbacks

### Recipe-Specific Business Metrics

- `recipe_stats_total_recipes`: Number of recipes created in last 24 hours
- `user_activity_active_recipe_creators`: Active recipe creators
- `user_activity_active_reviewers`: Active reviewers
- `user_activity_active_favoriters`: Users adding favorites
- `table_sizes_size_bytes`: Size of recipe_manager tables
- `slow_queries_mean_exec_time`: Average execution time of slow queries

## Alerting Rules

### Critical Alerts

- **PostgreSQLDown**: Database instance is not responding
- **PostgreSQLHighConnections**: Connection limit nearly reached (90%+)

### Warning Alerts

- **PostgreSQLTooManyConnections**: High connection usage (80%+)
- **PostgreSQLLowCacheHitRatio**: Cache hit ratio below 90%
- **PostgreSQLSlowQueries**: Queries running longer than 5 minutes
- **PostgreSQLDeadlocks**: Deadlock detection
- **PostgreSQLNoRecentRecipes**: No recipes created in 24 hours

## Troubleshooting

### Common Issues

1. **postgres_exporter container not starting**
   - Check the DATA_SOURCE_NAME secret is correctly formatted
   - Verify the monitoring user has proper permissions
   - Check container logs:
     `kubectl logs deployment/postgres-exporter -n recipe-database`

2. **No metrics in Prometheus**
   - Verify ServiceMonitor is applied and Prometheus has proper RBAC
   - Check if metrics endpoint is accessible:
     `kubectl port-forward svc/postgres-exporter-service 9187:9187`
   - Test metrics endpoint: `curl http://localhost:9187/metrics`

3. **Custom queries failing**
   - Verify pg_stat_statements extension is enabled
   - Check monitoring user permissions
   - Review postgres_exporter logs for query errors

### Useful Commands

```bash
# Check postgres_exporter logs
kubectl logs deployment/postgres-exporter -n recipe-database -f

# Test metrics endpoint
kubectl port-forward svc/postgres-exporter-service 9187:9187
curl http://localhost:9187/metrics | grep recipe_

# Check Prometheus targets
kubectl port-forward svc/prometheus-service 9090:9090
# Navigate to http://localhost:9090/targets

# Verify ServiceMonitor is discovered
kubectl get servicemonitor -n recipe-database
kubectl describe servicemonitor recipe-database-postgres-exporter -n recipe-database
```

## Advanced Configuration

### Adding Custom Metrics

1. Edit `k8s/postgres-exporter-configmap.yaml`
2. Add new queries to the `queries.yaml` section
3. Apply the updated ConfigMap
4. Restart the deployment to pick up changes

### Modifying Alert Thresholds

1. Edit `k8s/prometheusrule.yaml`
2. Adjust alert expressions and thresholds
3. Apply the updated PrometheusRule
4. Prometheus will automatically reload the rules

### Performance Tuning

- Adjust scrape intervals in ServiceMonitor for less frequent collection
- Reduce the number of custom queries if performance impact is significant
- Use recording rules for complex calculations to reduce query load

## Best Practices

### Production Deployment

- Always test monitoring setup in a staging environment first
- Use dedicated monitoring user with minimal permissions
- Enable TLS for monitoring connections in production
- Set up proper network policies to secure monitoring traffic
- Regular monitoring of monitoring (monitor the monitors!)

### Performance Considerations

- postgres_exporter adds minimal overhead (typically <1% CPU)
- Custom queries should be optimized to avoid impacting database performance
- Consider reducing scrape frequency for large databases
- Monitor the monitoring resource usage and adjust as needed

### Security Recommendations

- Rotate monitoring user passwords regularly
- Use network policies to restrict monitoring traffic
- Audit monitoring user permissions periodically
- Monitor for unauthorized access to metrics endpoints
- Encrypt monitoring data in transit and at rest

## Advanced Deployment Options

### High Availability Monitoring

For production environments requiring high availability:

```yaml
# Multi-replica postgres_exporter deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-exporter-ha
spec:
  replicas: 2
  selector:
    matchLabels:
      app: postgres-exporter-ha
  template:
    spec:
      containers:
        - name: postgres-exporter
          image: quay.io/prometheuscommunity/postgres-exporter:v0.15.0
          env:
            - name: DATA_SOURCE_NAME
              valueFrom:
                secretKeyRef:
                  name: postgres-exporter-secret
                  key: DATA_SOURCE_NAME
          ports:
            - containerPort: 9187
```

### Custom Alert Rules

Extend alerting with business-specific rules:

```yaml
# Custom business alerts
groups:
  - name: recipe-business-alerts
    rules:
      - alert: RecipeCreationStopped
        expr: increase(recipe_stats_total_recipes[2h]) == 0
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "No recipes created in the last 2 hours"

      - alert: HighUserChurn
        expr: |
          (
            rate(user_activity_active_recipe_creators[7d]) -
            rate(user_activity_active_recipe_creators[7d] offset 7d)
          ) / rate(user_activity_active_recipe_creators[7d] offset 7d) < -0.2
        for: 1d
        labels:
          severity: warning
        annotations:
          summary: "User engagement dropping significantly"
```

### Integration with External Systems

#### Slack Notifications

```yaml
# Alertmanager configuration for Slack
route:
  group_by: ["alertname"]
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: "web.hook"
receivers:
  - name: "web.hook"
    slack_configs:
      - api_url: "YOUR_SLACK_WEBHOOK_URL"
        channel: "#database-alerts"
        title: "Recipe Database Alert"
        text: "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
```

#### PagerDuty Integration

```yaml
# PagerDuty receiver configuration
receivers:
  - name: "pagerduty"
    pagerduty_configs:
      - service_key: "YOUR_PAGERDUTY_SERVICE_KEY" <!-- pragma: allowlist secret -->
        description: "Recipe Database {{ .GroupLabels.alertname }}"
```

## Monitoring Metrics Reference

### Core PostgreSQL Metrics

- `pg_up`: Database instance availability
- `pg_stat_database_*`: Database-level statistics
- `pg_stat_user_tables_*`: Table-level statistics
- `pg_stat_user_indexes_*`: Index usage statistics
- `pg_locks_*`: Lock information
- `pg_stat_activity_*`: Connection and query activity

### Recipe-Specific Metrics

- `recipe_stats_total_recipes`: Recipe creation count
- `recipe_stats_users_with_recipes`: Active recipe creators
- `user_activity_active_*`: User engagement metrics
- `table_sizes_size_bytes`: Storage utilization

### Custom Query Examples

```sql
-- Top ingredients by popularity
SELECT
  i.name,
  COUNT(ri.recipe_id) as usage_count
FROM recipe_manager.ingredients i
JOIN recipe_manager.recipe_ingredients ri ON i.ingredient_id = ri.ingredient_id
GROUP BY i.name
ORDER BY usage_count DESC
LIMIT 10;

-- Recipe creation trends by day of week
SELECT
  EXTRACT(dow FROM created_at) as day_of_week,
  COUNT(*) as recipe_count
FROM recipe_manager.recipes
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY EXTRACT(dow FROM created_at)
ORDER BY day_of_week;
```

## Troubleshooting Monitoring Issues

### Common Problems and Solutions

#### postgres_exporter Container Crashes

```bash
# Check logs for connection issues
kubectl logs -n recipe-database deployment/recipe-database -c postgres-exporter

# Common fix: Verify data source name format
kubectl get secret recipe-database-secret -n recipe-database \
  -o jsonpath='{.data.POSTGRES_EXPORTER_DATA_SOURCE_NAME}' | base64 -d
```

#### Missing Metrics in Prometheus

```bash
# Verify ServiceMonitor is applied
kubectl get servicemonitor -n recipe-database

# Check Prometheus configuration
kubectl logs -n monitoring deployment/prometheus-operator
```

#### Custom Queries Not Working

```bash
# Test query manually
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres_exporter -d recipe_database -c "SELECT COUNT(*) FROM recipe_manager.recipes;"

# Check monitoring user permissions
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "\\du postgres_exporter"
```

## Monitoring Maintenance

### Regular Tasks

- **Weekly**: Review alert thresholds and adjust as needed
- **Monthly**: Audit monitoring user permissions
- **Quarterly**: Review and optimize custom queries for performance
- **Annually**: Evaluate new monitoring features and update configurations

### Capacity Planning

Monitor these trends for capacity planning:

- Database size growth rate
- Connection count trends
- Query performance degradation
- Resource utilization patterns

For additional monitoring questions or advanced configurations, refer to the
main [troubleshooting guide](../docs/troubleshooting.md) or create a GitHub
issue.
