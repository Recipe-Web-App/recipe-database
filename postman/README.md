# Recipe Database Postman Collection

This directory contains Postman collections for monitoring and managing the
Recipe Database PostgreSQL system.

## Collections

### Recipe-Database-Monitoring.postman_collection.json

A comprehensive collection for monitoring database metrics, health checks, and
management operations.

## Setup Instructions

### 1. Import Collection

1. Open Postman
2. Click "Import"
3. Select the `Recipe-Database-Monitoring.postman_collection.json` file
4. The collection will appear in your workspace

### 2. Set Up Port Forwarding

Before using the collection, you need to set up port forwarding from your local
machine to the Kubernetes service:

```bash
# For metrics endpoint (postgres_exporter)
kubectl port-forward -n recipe-database svc/recipe-database-service 9187:9187

# For direct database access (if needed)
kubectl port-forward -n recipe-database svc/recipe-database-service 5432:5432
```

### 3. Environment Variables

The collection uses these variables (already set with defaults):

- `base_url`: localhost (default)
- `metrics_port`: 9187 (postgres_exporter port)
- `postgres_port`: 5432 (PostgreSQL port)
- `namespace`: recipe-database

You can modify these in Postman's environment settings if needed.

## Available Endpoints

### Monitoring Endpoints

1. **PostgreSQL Metrics** (`GET /metrics`)
   - **URL**: `http://localhost:9187/metrics`
   - **Purpose**: Fetch all Prometheus metrics from postgres_exporter
   - **Returns**: Prometheus format metrics including:
     - Standard PostgreSQL metrics (connections, queries, cache hits)
     - Custom recipe-specific business metrics
     - Database performance metrics
     - Table size and growth metrics

2. **Custom Recipe Metrics**
   - Same endpoint as above, but focused on recipe-specific metrics
   - Look for metrics prefixed with `recipe_` and `user_activity_`

3. **Health Check** (`GET /`)
   - **URL**: `http://localhost:9187/`
   - **Purpose**: Basic service health check

### Database Management

**Note**: The database management requests are conceptual examples. PostgreSQL
doesn't have a built-in HTTP API. In practice, you would:

- Use `kubectl exec` to run queries directly in the pod
- Use a PostgreSQL HTTP proxy like PostgREST
- Use database management tools like pgAdmin
- Use the provided scripts in `scripts/dbManagement/`

Example kubectl commands are provided in each request description.

## Key Metrics Available

### Standard PostgreSQL Metrics

- `pg_up`: Database availability
- `pg_stat_database_numbackends`: Active connections
- `pg_stat_database_xact_commit`: Committed transactions
- `pg_stat_database_xact_rollback`: Rolled back transactions
- `pg_stat_database_blks_hit`: Buffer cache hits
- `pg_stat_database_blks_read`: Disk reads

### Recipe-Specific Business Metrics

- `recipe_stats_total_recipes`: Total recipes created in last 24 hours
- `recipe_stats_users_with_recipes`: Unique users who created recipes
- `recipe_stats_avg_recipe_lifetime_seconds`: Average time between creation and
  update
- `user_activity_active_recipe_creators`: Active recipe creators
- `user_activity_active_reviewers`: Active reviewers
- `user_activity_active_favoriters`: Users favoriting recipes

### Performance Metrics

- `table_sizes_size_bytes`: Size of recipe_manager tables
- `slow_queries_mean_exec_time`: Mean execution time for slow queries
- `slow_queries_calls`: Number of calls for tracked queries

## Usage Examples

### 1. Monitor System Health

1. Run "PostgreSQL Metrics" request
2. Look for `pg_up = 1` (database is up)
3. Check `pg_stat_database_numbackends` for connection count
4. Verify `pg_stat_database_blks_hit` / (`pg_stat_database_blks_hit` +
   `pg_stat_database_blks_read`) > 0.9 for good cache hit ratio

### 2. Monitor Recipe Activity

1. Run "Custom Recipe Metrics" request
2. Look for recipe-specific metrics:
   - `recipe_stats_total_recipes`: New recipes today
   - `user_activity_active_recipe_creators`: Active users
   - `user_activity_active_reviewers`: Review activity

### 3. Check Performance Issues

1. Look for high `slow_queries_mean_exec_time` values
2. Check `table_sizes_size_bytes` for growing tables
3. Monitor connection count with `pg_stat_database_numbackends`

## Troubleshooting

### Connection Issues

If requests fail with connection errors:

1. Verify port forwarding is active:

   ```bash
   kubectl port-forward -n recipe-database svc/recipe-database-service 9187:9187
   ```

2. Check service status:

   ```bash
   ./scripts/containerManagement/get-container-status.sh
   ```

3. Verify pods are running:

   ```bash
   kubectl get pods -n recipe-database
   ```

### No Metrics Data

If metrics endpoint returns no recipe-specific data:

1. Ensure monitoring user is set up:

   ```bash
   ./scripts/dbManagement/setup-monitoring-user.sh
   ```

2. Check postgres_exporter logs:

   ```bash
   kubectl logs -n recipe-database deployment/recipe-database -c postgres-exporter
   ```

3. Verify custom queries configuration:

   ```bash
   kubectl get configmap postgres-exporter-config -n recipe-database -o yaml
   ```

## Alternative Access Methods

### Using kubectl exec

For direct database queries:

```bash
# Connect to database
kubectl exec -it -n recipe-database deployment/recipe-database -c recipe-database -- psql -U $DB_MAINT_USER -d $POSTGRES_DB

# Run health checks
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- psql -U $DB_MAINT_USER -d $POSTGRES_DB -f /app/db/queries/monitoring/health_checks.sql
```

### Using provided scripts

```bash
# Database connection
./scripts/dbManagement/db-connect.sh

# Health status
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh
```

## Security Notes

- The metrics endpoint (9187) exposes database performance data but not
  sensitive content
- Direct database access (5432) requires proper credentials
- Port forwarding is only accessible from your local machine
- In production, consider using proper monitoring tools like Grafana for metrics
  visualization

## Related Documentation

- [../monitoring/README.md](../monitoring/README.md) - Detailed monitoring setup
- [../docs/operations.md](../docs/operations.md) - Day-to-day operations
- [../CLAUDE.md](../CLAUDE.md) - Development guidance
