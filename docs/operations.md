# Operations Guide

This guide covers day-to-day operations, maintenance, and management of the
Recipe Database in production environments.

## Table of Contents

- [Daily Operations](#daily-operations)
- [Database Maintenance](#database-maintenance)
- [Backup and Recovery](#backup-and-recovery)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [Performance Tuning](#performance-tuning)
- [Scaling](#scaling)
- [Security Operations](#security-operations)
- [Incident Response](#incident-response)

## Daily Operations

### Health Checks

Run these checks daily to ensure system health:

```bash
# Quick health check
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh

# Database connectivity test
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- pg_isready -U postgres

# Check resource usage
kubectl top pods -n recipe-database
kubectl top nodes
```

### Log Review

Monitor logs for issues:

```bash
# Database logs
kubectl logs -n recipe-database deployment/recipe-database -c recipe-database --tail=100

# Monitoring logs
kubectl logs -n recipe-database deployment/recipe-database -c postgres-exporter --tail=50

# Check for errors in last hour
kubectl logs -n recipe-database deployment/recipe-database -c recipe-database --since=1h | grep -i error
```

### Metrics Review

Check key metrics daily:

```bash
# Port forward to metrics endpoint
kubectl port-forward -n recipe-database svc/recipe-database-service 9187:9187 &

# Key metrics to check
curl -s http://localhost:9187/metrics | grep -E "(pg_up|pg_stat_database_numbackends|pg_stat_database_xact_commit)"

# Recipe-specific metrics
curl -s http://localhost:9187/metrics | grep -E "(recipe_stats|user_activity)"
```

### Routine Maintenance Commands

```bash
# Update statistics (weekly)
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "ANALYZE;"

# Vacuum tables (as needed)
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "VACUUM ANALYZE;"
```

## Database Maintenance

### Regular Maintenance Tasks

#### Weekly Tasks

##### Analyze Database Statistics

```bash
# Update table statistics for query optimizer
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    ANALYZE recipe_manager.recipes;
    ANALYZE recipe_manager.ingredients;
    ANALYZE recipe_manager.reviews;
    ANALYZE recipe_manager.users;"
```

##### Check Index Usage

```bash
# Monitor index usage
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
    FROM pg_stat_user_indexes
    WHERE schemaname = 'recipe_manager'
    ORDER BY idx_scan ASC;"
```

#### Monthly Tasks

##### Monthly Database Maintenance

```bash
# Full vacuum and analyze (during maintenance window)
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "VACUUM FULL ANALYZE;"

# Reindex if needed (check for bloat first)
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "REINDEX DATABASE recipe_database;"
```

##### Check Database Size Growth

```bash
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
      pg_total_relation_size(schemaname||'.'||tablename) as size_bytes
    FROM pg_tables
    WHERE schemaname = 'recipe_manager'
    ORDER BY size_bytes DESC;"
```

### Schema Management

#### Adding New Columns

```bash
# Example: Add new column to recipes table
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    ALTER TABLE recipe_manager.recipes
    ADD COLUMN dietary_restrictions TEXT[];

    COMMENT ON COLUMN recipe_manager.recipes.dietary_restrictions
    IS 'Array of dietary restrictions (vegetarian, vegan, gluten-free, etc.)';

    -- Update statistics after schema change
    ANALYZE recipe_manager.recipes;"
```

#### Creating New Indexes

```bash
# Example: Add index for performance optimization
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    CREATE INDEX CONCURRENTLY idx_recipes_created_at_desc
    ON recipe_manager.recipes (created_at DESC);

    -- Monitor index creation progress
    SELECT * FROM pg_stat_progress_create_index;"
```

### User Management

#### Creating Application Users

```bash
# Create new application user
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    CREATE USER recipe_api WITH PASSWORD 'secure_password'; <!-- pragma: allowlist secret -->
    GRANT CONNECT ON DATABASE recipe_database TO recipe_api;
    GRANT USAGE ON SCHEMA recipe_manager TO recipe_api;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA recipe_manager TO recipe_api;
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA recipe_manager TO recipe_api;"
```

#### Rotating Passwords

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update user password
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "ALTER USER recipe_api PASSWORD '$NEW_PASSWORD';"

# Update application configuration
kubectl patch secret recipe-database-secret -n recipe-database \
  --patch="{\"data\":{\"API_PASSWORD\":\"$(echo -n $NEW_PASSWORD | base64 -w 0)\"}}"
```

## Backup and Recovery

### Automated Backups

#### Daily Backup Script

```bash
#!/bin/bash
# Save as scripts/dbManagement/automated-backup.sh

BACKUP_DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="/backups/recipe-database"
NAMESPACE="recipe-database"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create database backup
kubectl exec -n "$NAMESPACE" deployment/recipe-database -c recipe-database -- \
  pg_dump -U postgres -d recipe_database --clean --if-exists | \
  gzip > "$BACKUP_DIR/recipe-database-backup-$BACKUP_DATE.sql.gz"

# Keep only last 30 days of backups
find "$BACKUP_DIR" -name "recipe-database-backup-*.sql.gz" -mtime +30 -delete

echo "Backup completed: recipe-database-backup-$BACKUP_DATE.sql.gz"
```

#### Backup Verification

```bash
# Test backup integrity
LATEST_BACKUP=$(ls -t /backups/recipe-database/recipe-database-backup-*.sql.gz | head -1)
gunzip -t "$LATEST_BACKUP" && echo "Backup integrity OK" || echo "Backup corrupted!"

# Test restore process (to test database)
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  createdb -U postgres recipe_test

zcat "$LATEST_BACKUP" | kubectl exec -i -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_test

# Cleanup test database
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  dropdb -U postgres recipe_test
```

### Recovery Procedures

#### Point-in-Time Recovery

```bash
# Stop application connections
kubectl scale deployment recipe-app --replicas=0

# Create backup of current state
./scripts/dbManagement/backup-db.sh

# Restore from backup
RESTORE_FILE="recipe-database-backup-2024-01-15_10-30-00.sql.gz"
zcat "/backups/recipe-database/$RESTORE_FILE" | \
  kubectl exec -i -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database

# Verify restore
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "SELECT COUNT(*) FROM recipe_manager.recipes;"

# Resume application
kubectl scale deployment recipe-app --replicas=3
```

#### Disaster Recovery

```bash
# Full disaster recovery procedure
# 1. Deploy new database instance
./scripts/containerManagement/deploy-container.sh

# 2. Restore from latest backup
LATEST_BACKUP=$(ls -t /backups/recipe-database/recipe-database-backup-*.sql.gz | head -1)
zcat "$LATEST_BACKUP" | \
  kubectl exec -i -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database

# 3. Set up monitoring
./scripts/dbManagement/setup-monitoring-user.sh
./scripts/containerManagement/deploy-supporting-services.sh

# 4. Verify data integrity
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT 'recipes' as table_name, COUNT(*) as count FROM recipe_manager.recipes
    UNION ALL
    SELECT 'users' as table_name, COUNT(*) as count FROM recipe_manager.users
    UNION ALL
    SELECT 'ingredients' as table_name, COUNT(*) as count FROM recipe_manager.ingredients;"
```

## Monitoring and Alerting

### Key Metrics to Monitor

#### Database Health Metrics

- **pg_up**: Database availability (should be 1)
- **pg_stat_database_numbackends**: Number of connections
- **pg_stat_database_xact_commit_rate**: Transaction commit rate
- **pg_stat_database_blks_hit_rate**: Cache hit ratio (should be >95%)

#### Performance Metrics

- **pg_stat_activity_max_tx_duration**: Longest running transaction
- **pg_locks_count**: Number of locks held
- **pg*stat_bgwriter*\***: Background writer statistics

#### Business Metrics

- **recipe_stats_total_recipes**: Recipe creation rate
- **user*activity*\***: User engagement metrics
- **table_sizes_size_bytes**: Database growth

### Setting Up Alerts

#### Prometheus Alert Rules

```yaml
# Add to monitoring/prometheus-rules/additional-alerts.yaml
groups:
  - name: recipe-database-business
    rules:
      - alert: LowRecipeCreationRate
        expr: rate(recipe_stats_total_recipes[24h]) < 1
        for: 2h
        labels:
          severity: warning
        annotations:
          summary: "Recipe creation rate is unusually low"
          description: "Only {{ $value }} recipes created in the last 24 hours"

      - alert: DatabaseGrowthHigh
        expr: increase(pg_database_size_bytes[24h]) > 1073741824 # 1GB
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Database growing rapidly"
          description:
            "Database grew by {{ $value | humanizeBytes }} in 24 hours"
```

#### Grafana Dashboard Alerts

Configure alerts in Grafana dashboards:

1. Open dashboard panel
2. Click "Alert" tab
3. Set conditions and thresholds
4. Configure notification channels

### Log Analysis

#### Centralized Logging Setup

```bash
# Install log aggregation (example with Fluentd)
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: recipe-database
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/recipe-database*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      format json
    </source>

    <match kubernetes.**>
      @type elasticsearch
      host elasticsearch.monitoring.svc.cluster.local
      port 9200
      index_name recipe-database-logs
    </match>
EOF
```

## Performance Tuning

### Query Optimization

#### Identifying Slow Queries

```bash
# Enable and check pg_stat_statements
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT
      query,
      calls,
      total_exec_time,
      mean_exec_time,
      stddev_exec_time,
      rows
    FROM pg_stat_statements
    WHERE query NOT LIKE '%pg_stat_statements%'
    ORDER BY mean_exec_time DESC
    LIMIT 10;"
```

#### Adding Missing Indexes

```bash
# Check for missing indexes
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT
      schemaname,
      tablename,
      seq_scan,
      seq_tup_read,
      idx_scan,
      idx_tup_fetch,
      seq_tup_read / seq_scan as avg_seq_read
    FROM pg_stat_user_tables
    WHERE schemaname = 'recipe_manager'
      AND seq_scan > 0
    ORDER BY seq_tup_read DESC;"
```

### Database Configuration Tuning

#### Memory Settings

```bash
# Check current settings
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT name, setting, unit, short_desc
    FROM pg_settings
    WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size');"

# Update configuration (requires restart)
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    ALTER SYSTEM SET shared_buffers = '512MB';
    ALTER SYSTEM SET work_mem = '4MB';
    ALTER SYSTEM SET maintenance_work_mem = '64MB';
    SELECT pg_reload_conf();"
```

#### Connection Settings

```bash
# Monitor connection usage
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT
      state,
      COUNT(*) as connections,
      MAX(EXTRACT(EPOCH FROM (now() - state_change))) as max_duration
    FROM pg_stat_activity
    GROUP BY state;"
```

### Storage Optimization

#### Table Bloat Management

```bash
# Check for table bloat
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT
      schemaname,
      tablename,
      n_dead_tup,
      n_live_tup,
      ROUND((n_dead_tup * 100.0) / NULLIF(n_live_tup + n_dead_tup, 0), 2) as dead_percentage
    FROM pg_stat_user_tables
    WHERE schemaname = 'recipe_manager'
      AND n_dead_tup > 1000
    ORDER BY dead_percentage DESC;"

# Schedule vacuum for high-bloat tables
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "VACUUM ANALYZE recipe_manager.recipes;"
```

## Scaling

### Vertical Scaling

#### Increasing Resources

```bash
# Update deployment with more resources
kubectl patch deployment recipe-database -n recipe-database --patch='
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "recipe-database",
            "resources": {
              "requests": {
                "memory": "1Gi",
                "cpu": "1000m"
              },
              "limits": {
                "memory": "2Gi",
                "cpu": "2000m"
              }
            }
          }
        ]
      }
    }
  }
}'

# Monitor rollout
kubectl rollout status deployment/recipe-database -n recipe-database
```

#### Storage Expansion

```bash
# Expand PVC (if storage class supports it)
kubectl patch pvc recipe-database-pvc -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'

# Monitor expansion
kubectl get pvc recipe-database-pvc -w
```

### Horizontal Scaling (Read Replicas)

#### Setting Up Read Replica

```yaml
# read-replica-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recipe-database-read-replica
  namespace: recipe-database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: recipe-database-read-replica
  template:
    metadata:
      labels:
        app: recipe-database-read-replica
    spec:
      containers:
        - name: postgres-read-replica
          image: postgres:15.4
          env:
            - name: PGUSER
              value: "replicator"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: recipe-database-secret
                  key: POSTGRES_PASSWORD
            - name: POSTGRES_MASTER_SERVICE
              value: "recipe-database-service"
          command:
            - /bin/bash
            - -c
            - |
              pg_basebackup -h $POSTGRES_MASTER_SERVICE -D /var/lib/postgresql/data -U replicator -W
              echo "standby_mode = 'on'" >> /var/lib/postgresql/data/recovery.conf
              echo "primary_conninfo = 'host=$POSTGRES_MASTER_SERVICE port=5432 user=replicator'" >> /var/lib/postgresql/data/recovery.conf
              postgres
```

## Security Operations

### Security Monitoring

#### Audit Log Analysis

```bash
# Check for failed login attempts
kubectl logs -n recipe-database deployment/recipe-database -c recipe-database | \
  grep -i "authentication failed"

# Monitor privilege escalations
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT * FROM pg_stat_activity
    WHERE usename = 'postgres'
      AND application_name NOT IN ('psql', 'pg_dump', 'pg_restore');"
```

#### Permission Audits

```bash
# Review user permissions
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT
      r.rolname,
      r.rolsuper,
      r.rolinherit,
      r.rolcreaterole,
      r.rolcreatedb,
      r.rolcanlogin,
      r.rolconnlimit
    FROM pg_roles r
    WHERE r.rolname NOT LIKE 'pg_%'
    ORDER BY r.rolname;"
```

### Security Updates

#### Applying Security Patches

```bash
# Update container image
kubectl set image deployment/recipe-database -n recipe-database \
  recipe-database=postgres:15.4-security-update

# Monitor rollout
kubectl rollout status deployment/recipe-database -n recipe-database

# Verify update
kubectl get pods -n recipe-database -o jsonpath='{.items[0].spec.containers[0].image}'
```

## Incident Response

### Common Incident Types

#### Database Connection Issues

```bash
# Immediate response
kubectl get pods -n recipe-database
kubectl describe pod -l app=recipe-database -n recipe-database

# Check service endpoints
kubectl get endpoints recipe-database-service -n recipe-database

# Test connectivity
kubectl run debug-pod --image=postgres:15 --rm -it --restart=Never -- \
  psql -h recipe-database-service.recipe-database.svc.cluster.local -U postgres -d recipe_database
```

#### Performance Degradation

```bash
# Check active queries
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT pid, state, query_start, left(query, 50) as query_preview
    FROM pg_stat_activity
    WHERE state = 'active'
    ORDER BY query_start;"

# Check system resources
kubectl top pod -n recipe-database
kubectl describe node $(kubectl get pods -n recipe-database -o jsonpath='{.items[0].spec.nodeName}')

# Emergency: Kill long-running queries
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE query_start < now() - interval '10 minutes' AND state = 'active';"
```

#### Data Corruption

```bash
# Check database integrity
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT datname, pg_database_size(datname) as size
    FROM pg_database
    WHERE datname = 'recipe_database';"

# Run integrity checks
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT schemaname, tablename,
           pg_relation_size(schemaname||'.'||tablename) as size
    FROM pg_tables
    WHERE schemaname = 'recipe_manager'
    ORDER BY size DESC;"
```

### Incident Documentation

For each incident, document:

- **Timeline**: When issue started/resolved
- **Impact**: Affected services/users
- **Root Cause**: What caused the issue
- **Resolution**: Steps taken to resolve
- **Prevention**: Changes to prevent recurrence

### Escalation Procedures

1. **Level 1**: DevOps team handles routine issues
2. **Level 2**: Database specialists for complex issues
3. **Level 3**: Vendor support for critical infrastructure issues
4. **Management**: Notify for business-critical outages

---

For additional operational procedures or specific scenarios not covered here,
refer to your organization's runbooks or escalate to the appropriate support
channels.
