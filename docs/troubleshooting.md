# Troubleshooting Guide

This guide provides solutions to common issues encountered when deploying and
operating the Recipe Database.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Deployment Issues](#deployment-issues)
- [Database Issues](#database-issues)
- [Monitoring Issues](#monitoring-issues)
- [Performance Issues](#performance-issues)
- [Network and Connectivity](#network-and-connectivity)
- [Storage Issues](#storage-issues)
- [Security Issues](#security-issues)
- [Recovery Procedures](#recovery-procedures)

## Quick Diagnostics

### System Health Check

Run these commands first to get an overview of system health:

```bash
# Check all components status
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh

# Check Kubernetes resources
kubectl get all -n recipe-database
kubectl get pvc -n recipe-database
kubectl get secrets -n recipe-database

# Check resource usage
kubectl top pods -n recipe-database
kubectl top nodes
```

### Log Collection

Collect logs for troubleshooting:

```bash
# Create diagnostic directory
mkdir -p troubleshooting/$(date +%Y%m%d_%H%M%S)
cd troubleshooting/$(date +%Y%m%d_%H%M%S)

# Collect pod logs
kubectl logs -n recipe-database deployment/recipe-database -c recipe-database > database.log
kubectl logs -n recipe-database deployment/recipe-database -c postgres-exporter > exporter.log

# Collect resource information
kubectl describe deployment recipe-database -n recipe-database > deployment-describe.txt
kubectl describe pod -l app=recipe-database -n recipe-database > pod-describe.txt
kubectl get events -n recipe-database --sort-by='.lastTimestamp' > events.txt
```

## Deployment Issues

### Pod Won't Start (CrashLoopBackOff)

**Symptoms:**

- Pod status shows `CrashLoopBackOff`
- Pod restarts continuously

**Diagnosis:**

```bash
# Check pod events
kubectl describe pod -l app=recipe-database -n recipe-database

# Check container logs
kubectl logs -n recipe-database deployment/recipe-database -c recipe-database --previous

# Check resource limits
kubectl get pod -l app=recipe-database -n recipe-database -o yaml | grep -A 10 resources
```

**Common Solutions:**

1. **Insufficient Resources**

   ```bash
   # Increase resource limits
   kubectl patch deployment recipe-database -n recipe-database --patch='
   {
     "spec": {
       "template": {
         "spec": {
           "containers": [
             {
               "name": "recipe-database",
               "resources": {
                 "requests": {"memory": "512Mi", "cpu": "500m"},
                 "limits": {"memory": "1Gi", "cpu": "1000m"}
               }
             }
           ]
         }
       }
     }
   }'
   ```

2. **PVC Not Bound**

   ```bash
   kubectl get pvc -n recipe-database

   # If PVC is pending, check storage class
   kubectl get storageclass
   kubectl describe pvc recipe-database-pvc -n recipe-database
   ```

3. **Invalid Configuration**

   ```bash
   # Check ConfigMap and Secret
   kubectl get configmap -n recipe-database
   kubectl get secrets -n recipe-database

   # Verify environment variables
   kubectl get deployment recipe-database -n recipe-database -o yaml | grep -A 20 env:
   ```

### Container Image Issues

**Symptoms:**

- ImagePullBackOff error
- Wrong image version running

**Solutions:**

```bash
# Check image pull policy and availability
kubectl describe pod -l app=recipe-database -n recipe-database | grep -A 5 "Image"

# For local development with minikube
eval $(minikube docker-env)
docker build -t recipe-database:latest .

# Verify image exists
kubectl get pod -l app=recipe-database -n recipe-database -o jsonpath='{.items[0].spec.containers[0].image}'
```

### Schema Loading Failures

**Symptoms:**

- Database starts but schema is not loaded
- Schema loading script fails

**Diagnosis:**

```bash
# Check if schema loading job completed
kubectl get jobs -n recipe-database

# Check job logs
kubectl logs job/db-load-schema-job -n recipe-database
```

**Solutions:**

```bash
# Manual schema loading
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "\dt recipe_manager.*"

# If no tables exist, run schema loading manually
./scripts/dbManagement/load-schema.sh

# Check for conflicting objects
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "DROP SCHEMA IF EXISTS recipe_manager CASCADE;"
```

## Database Issues

### Connection Refused

**Symptoms:**

- Cannot connect to database
- "Connection refused" errors

**Diagnosis:**

```bash
# Check if PostgreSQL is running
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- pg_isready -U postgres

# Check service configuration
kubectl get svc recipe-database-service -n recipe-database -o yaml

# Test internal connectivity
kubectl run test-connection --image=postgres:15 --rm -it --restart=Never -- \
  psql -h recipe-database-service.recipe-database.svc.cluster.local -U postgres -d recipe_database
```

**Solutions:**

1. **Service Configuration Issues**

   ```bash
   # Verify service endpoints
   kubectl get endpoints recipe-database-service -n recipe-database

   # Check port configuration
   kubectl port-forward -n recipe-database svc/recipe-database-service 5432:5432
   psql -h localhost -p 5432 -U postgres -d recipe_database
   ```

2. **Network Policy Issues**

   ```bash
   # Check for restrictive network policies
   kubectl get networkpolicy -n recipe-database

   # Temporarily disable network policies for testing
   kubectl delete networkpolicy --all -n recipe-database
   ```

### Authentication Failures

**Symptoms:**

- "Authentication failed" errors
- Cannot login with correct credentials

**Solutions:**

```bash
# Check password in secret
kubectl get secret recipe-database-secret -n recipe-database -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d

# Reset password
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -c "ALTER USER postgres PASSWORD 'new_password';"  <!-- pragma: allowlist secret -->

# Update secret
kubectl patch secret recipe-database-secret -n recipe-database \
  --patch="{\"data\":{\"POSTGRES_PASSWORD\":\"$(echo -n 'new_password' | base64 -w 0)\"}}"
```

### Database Corruption

**Symptoms:**

- Database won't start
- Corruption errors in logs
- Data inconsistencies

**Emergency Procedures:**

```bash
# 1. Stop all connections
kubectl scale deployment recipe-app --replicas=0

# 2. Create emergency backup
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  pg_dumpall -U postgres | gzip > emergency_backup_$(date +%Y%m%d_%H%M%S).sql.gz

# 3. Check database integrity
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "SELECT pg_database_size('recipe_database');"

# 4. Attempt repair
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "VACUUM FULL;"

# 5. If corruption is severe, restore from backup
# See Recovery Procedures section
```

### Slow Query Performance

**Symptoms:**

- Queries taking longer than usual
- High CPU usage
- Connection timeouts

**Diagnosis:**

```bash
# Check active queries
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT pid, state, query_start, query, state_change
    FROM pg_stat_activity
    WHERE state = 'active'
    ORDER BY query_start;"

# Check for locks
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT * FROM pg_locks WHERE NOT granted;"

# Check statistics
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del, n_dead_tup
    FROM pg_stat_user_tables
    WHERE schemaname = 'recipe_manager'
    ORDER BY n_dead_tup DESC;"
```

**Solutions:**

```bash
# Kill long-running queries (emergency)
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE query_start < now() - interval '10 minutes'
      AND state = 'active'
      AND usename != 'postgres';"

# Update statistics
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "ANALYZE;"

# Vacuum tables with high dead tuple count
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "VACUUM ANALYZE recipe_manager.recipes;"
```

## Monitoring Issues

### postgres_exporter Not Working

**Symptoms:**

- No metrics in Prometheus
- Metrics endpoint not responding
- Monitoring container crashes

**Diagnosis:**

```bash
# Check container status
kubectl get pod -l app=recipe-database -n recipe-database -o jsonpath='{.items[0].status.containerStatuses[?(@.name=="postgres-exporter")].ready}'

# Check exporter logs
kubectl logs -n recipe-database deployment/recipe-database -c postgres-exporter

# Test metrics endpoint
kubectl exec -n recipe-database deployment/recipe-database -c postgres-exporter -- \
  wget -q -O- http://localhost:9187/metrics | head -10
```

**Solutions:**

1. **Connection String Issues**

   ```bash
   # Check data source name
   kubectl get secret recipe-database-secret -n recipe-database \
     -o jsonpath='{.data.POSTGRES_EXPORTER_DATA_SOURCE_NAME}' | base64 -d

   # Verify connection string format
   # Should be: postgresql://user:password@localhost:5432/database?sslmode=disable  <!-- pragma: allowlist secret -->

   # Recreate monitoring user if needed
   ./scripts/dbManagement/setup-monitoring-user.sh
   ```

2. **Permission Issues**

   ```bash
   # Test monitoring user permissions
   kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
     psql -U postgres_exporter -d recipe_database -c "SELECT version();"

   # Check specific table access
   kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
     psql -U postgres_exporter -d recipe_database -c "SELECT count(*) FROM pg_stat_database;"
   ```

3. **Configuration Issues**

   ```bash
   # Check ConfigMap
   kubectl get configmap postgres-exporter-config -n recipe-database -o yaml

   # Restart deployment to pick up config changes
   kubectl rollout restart deployment/recipe-database -n recipe-database
   ```

### ServiceMonitor Not Discovered

**Symptoms:**

- Targets not appearing in Prometheus
- ServiceMonitor exists but not working

**Solutions:**

```bash
# Check if Prometheus Operator is installed
kubectl get crd servicemonitors.monitoring.coreos.com

# Check ServiceMonitor configuration
kubectl get servicemonitor recipe-database-postgres-exporter -n recipe-database -o yaml

# Check if Prometheus has proper RBAC
kubectl get clusterrole prometheus
kubectl get clusterrolebinding prometheus

# Verify label selectors match
kubectl get servicemonitor recipe-database-postgres-exporter -n recipe-database \
  -o jsonpath='{.spec.selector.matchLabels}'
kubectl get svc recipe-database-service -n recipe-database \
  -o jsonpath='{.metadata.labels}'
```

### Missing Custom Metrics

**Symptoms:**

- Standard PostgreSQL metrics work
- Custom recipe metrics not appearing

**Solutions:**

```bash
# Check custom queries configuration
kubectl get configmap postgres-exporter-config -n recipe-database \
  -o jsonpath='{.data.queries\.yaml}' | head -50

# Test custom queries manually
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres_exporter -d recipe_database -c "
    SELECT
      COUNT(*) as total_recipes,
      COUNT(DISTINCT user_id) as users_with_recipes
    FROM recipe_manager.recipes
    WHERE created_at > NOW() - INTERVAL '24 hours';"

# Check if tables have data
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres_exporter -d recipe_database -c "
    SELECT 'recipes' as table_name, COUNT(*) as count FROM recipe_manager.recipes
    UNION ALL
    SELECT 'users' as table_name, COUNT(*) as count FROM recipe_manager.users;"
```

## Performance Issues

### High CPU Usage

**Symptoms:**

- CPU usage consistently high
- Slow response times
- Pod getting OOMKilled

**Diagnosis:**

```bash
# Check resource usage
kubectl top pod -l app=recipe-database -n recipe-database

# Check active connections
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT state, count(*) FROM pg_stat_activity GROUP BY state;"

# Find expensive queries
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT query, calls, total_exec_time, mean_exec_time
    FROM pg_stat_statements
    ORDER BY total_exec_time DESC LIMIT 10;"
```

**Solutions:**

```bash
# Increase resource limits
kubectl patch deployment recipe-database -n recipe-database --patch='
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "recipe-database",
            "resources": {
              "limits": {"cpu": "2000m", "memory": "2Gi"}
            }
          }
        ]
      }
    }
  }
}'

# Optimize PostgreSQL configuration
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    ALTER SYSTEM SET shared_buffers = '512MB';
    ALTER SYSTEM SET work_mem = '4MB';
    ALTER SYSTEM SET maintenance_work_mem = '64MB';
    SELECT pg_reload_conf();"
```

### Memory Issues

**Symptoms:**

- OOMKilled events
- High memory usage
- Swap usage

**Solutions:**

```bash
# Check memory usage patterns
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT name, setting, unit FROM pg_settings
    WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem');"

# Adjust memory settings
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    ALTER SYSTEM SET shared_buffers = '256MB';
    ALTER SYSTEM SET work_mem = '2MB';
    SELECT pg_reload_conf();"

# Check for memory leaks
kubectl top pod -l app=recipe-database -n recipe-database --containers
```

### Storage I/O Issues

**Symptoms:**

- Slow disk operations
- High I/O wait times
- Storage nearly full

**Diagnosis:**

```bash
# Check storage usage
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- df -h

# Check database sizes
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
    FROM pg_tables
    WHERE schemaname = 'recipe_manager'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

**Solutions:**

```bash
# Expand PVC if possible
kubectl patch pvc recipe-database-pvc -n recipe-database \
  --patch='{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'

# Clean up old data
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    DELETE FROM recipe_manager.user_notifications
    WHERE created_at < NOW() - INTERVAL '90 days';"

# Vacuum to reclaim space
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "VACUUM FULL;"
```

## Network and Connectivity

### Service Discovery Issues

**Symptoms:**

- Cannot resolve service DNS names
- Intermittent connectivity

**Solutions:**

```bash
# Test DNS resolution
kubectl run debug-dns --image=busybox --rm -it --restart=Never -- nslookup recipe-database-service.recipe-database.svc.cluster.local

# Check service endpoints
kubectl get endpoints recipe-database-service -n recipe-database

# Verify service selector matches pod labels
kubectl get svc recipe-database-service -n recipe-database -o yaml | grep -A 5 selector
kubectl get pod -l app=recipe-database -n recipe-database --show-labels
```

### Network Policy Issues

**Symptoms:**

- Connection timeouts
- Services cannot communicate

**Solutions:**

```bash
# List network policies
kubectl get networkpolicy -n recipe-database

# Test connectivity without network policies
kubectl delete networkpolicy --all -n recipe-database

# Create test pod to verify connectivity
kubectl run network-test --image=nicolaka/netshoot --rm -it --restart=Never -- \
  nc -v recipe-database-service.recipe-database.svc.cluster.local 5432
```

### Port Forwarding Issues

**Symptoms:**

- Port forward commands fail
- Cannot access services locally

**Solutions:**

```bash
# Check if pod is running
kubectl get pod -l app=recipe-database -n recipe-database

# Use correct port forwarding syntax
kubectl port-forward -n recipe-database deployment/recipe-database 5432:5432

# Try port forwarding to service instead
kubectl port-forward -n recipe-database svc/recipe-database-service 5432:5432

# Check for port conflicts
lsof -i :5432
```

## Storage Issues

### PVC Not Binding

**Symptoms:**

- PVC stuck in Pending state
- Pod cannot start due to volume mount issues

**Solutions:**

```bash
# Check PVC status
kubectl describe pvc recipe-database-pvc -n recipe-database

# Check storage class
kubectl get storageclass

# For minikube, ensure provisioner is working
minikube addons list | grep storage-provisioner

# Manually create PV if needed (for local development)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: recipe-database-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /data/recipe-database
EOF
```

### Data Loss or Corruption

**Symptoms:**

- Missing data after restart
- Database corruption errors
- Inconsistent data

**Recovery Procedures:**

```bash
# Stop all applications accessing the database
kubectl scale deployment recipe-app --replicas=0

# Check filesystem integrity
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  pg_controldata /var/lib/postgresql/data

# If data is corrupted, restore from backup
LATEST_BACKUP=$(ls -t /backups/recipe-database/*.sql.gz | head -1)

# Create new database and restore
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  createdb -U postgres recipe_database_new

zcat "$LATEST_BACKUP" | \
  kubectl exec -i -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database_new

# Rename databases after verification
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -c "
    ALTER DATABASE recipe_database RENAME TO recipe_database_corrupted;
    ALTER DATABASE recipe_database_new RENAME TO recipe_database;"
```

## Security Issues

### Authentication Problems

**Symptoms:**

- Users cannot authenticate
- Permission denied errors

**Solutions:**

```bash
# Check user permissions
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "\\du"

# Reset user passwords
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "ALTER USER recipe_admin PASSWORD 'new_password';" <!-- pragma: allowlist secret -->

# Check pg_hba.conf configuration
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  cat /var/lib/postgresql/data/pg_hba.conf
```

### SSL/TLS Issues

**Symptoms:**

- SSL connection errors
- Certificate validation failures

**Solutions:**

```bash
# Check SSL configuration
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "SHOW ssl;"

# Test SSL connection
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql "sslmode=require host=localhost user=postgres dbname=recipe_database"

# Disable SSL for testing (not recommended for production)
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "ALTER SYSTEM SET ssl = off; SELECT pg_reload_conf();"
```

## Recovery Procedures

### Complete System Recovery

**When to Use:**

- Total system failure
- Data center outage
- Complete data loss

**Procedure:**

```bash
# 1. Deploy fresh database instance
./scripts/containerManagement/deploy-container.sh

# 2. Restore from latest backup
LATEST_BACKUP=$(ls -t /backups/recipe-database/*.sql.gz | head -1)
echo "Restoring from: $LATEST_BACKUP"

zcat "$LATEST_BACKUP" | \
  kubectl exec -i -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database

# 3. Verify data integrity
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT 'recipes' as table_name, COUNT(*) FROM recipe_manager.recipes
    UNION ALL
    SELECT 'users' as table_name, COUNT(*) FROM recipe_manager.users
    UNION ALL
    SELECT 'ingredients' as table_name, COUNT(*) FROM recipe_manager.ingredients;"

# 4. Restore monitoring
./scripts/dbManagement/setup-monitoring-user.sh
./scripts/containerManagement/deploy-supporting-services.sh

# 5. Verify all systems operational
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh
```

### Partial Data Recovery

**When to Use:**

- Specific table corruption
- Accidental data deletion
- Need to recover specific timeframe

**Procedure:**

```bash
# 1. Identify affected data
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT COUNT(*) FROM recipe_manager.recipes WHERE created_at >= '2024-01-01';"

# 2. Create backup of current state
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  pg_dump -U postgres -d recipe_database -t recipe_manager.recipes > current_recipes.sql

# 3. Restore specific table from backup
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "CREATE TABLE recipe_manager.recipes_backup AS SELECT * FROM recipe_manager.recipes;"

# Extract and restore specific table
zcat "$BACKUP_FILE" | grep -A 1000000 "COPY recipe_manager.recipes" | \
  kubectl exec -i -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database

# 4. Merge data as needed
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    INSERT INTO recipe_manager.recipes
    SELECT * FROM recipe_manager.recipes_backup
    WHERE recipe_id NOT IN (SELECT recipe_id FROM recipe_manager.recipes);"
```

## Getting Help

### Information to Collect

When seeking help, provide:

1. **System Information**

   ```bash
   kubectl version
   kubectl get nodes -o wide
   kubectl get all -n recipe-database
   ```

2. **Error Logs**

   ```bash
   kubectl logs -n recipe-database deployment/recipe-database -c recipe-database --tail=100
   kubectl describe pod -l app=recipe-database -n recipe-database
   kubectl get events -n recipe-database --sort-by='.lastTimestamp'
   ```

3. **Resource Status**

   ```bash
   kubectl top pods -n recipe-database
   kubectl get pvc -n recipe-database
   kubectl describe pvc recipe-database-pvc -n recipe-database
   ```

### Escalation Path

1. **Self-Service**: Use this troubleshooting guide
2. **Documentation**: Check other docs in `docs/` directory
3. **Community**: GitHub Issues or Discussions
4. **Support**: Contact your infrastructure team
5. **Emergency**: Follow your organization's incident response procedures

---

If you encounter issues not covered in this guide, please contribute by
documenting the problem and solution for future users.
