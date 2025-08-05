# Setup Guide

This guide provides detailed instructions for setting up the Recipe Database in
various environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [Production Deployment](#production-deployment)
- [Environment Configuration](#environment-configuration)
- [Database Initialization](#database-initialization)
- [Monitoring Setup](#monitoring-setup)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

#### Development Environment

- **Git** (2.30+) - Version control
- **Docker** (20.10+) - Container runtime
- **kubectl** (1.24+) - Kubernetes CLI
- **minikube** (1.28+) - Local Kubernetes (development only)
- **Python** (3.8+) - Data processing scripts
- **PostgreSQL client tools** - Database interaction (psql, pg_dump, etc.)

#### Production Environment

- **Kubernetes cluster** (1.24+) - Container orchestration
- **Persistent storage** - For database data persistence
- **Load balancer** (optional) - For external access
- **Monitoring stack** (optional) - Prometheus and Grafana

### System Requirements

#### Minimum Requirements

- **CPU**: 2 cores
- **Memory**: 4GB RAM
- **Storage**: 20GB available space
- **Network**: Outbound internet access for image downloads

#### Recommended for Production

- **CPU**: 4+ cores
- **Memory**: 8GB+ RAM
- **Storage**: 100GB+ SSD storage
- **Network**: Dedicated network with backup connectivity

### Verification Commands

Run these commands to verify your prerequisites:

```bash
# Check Docker
docker --version
docker info

# Check Kubernetes
kubectl version --client
kubectl cluster-info

# Check Python
python3 --version
pip3 --version

# Check PostgreSQL tools
psql --version
pg_dump --version

# Check additional tools
jq --version
envsubst --version
```

## Local Development Setup

### 1. Environment Preparation

```bash
# Clone the repository
git clone <your-repository-url>
cd recipe-database

# Create environment file
cp .env.example .env
```

### 2. Configure Environment Variables

Edit `.env` with your local settings:

```bash
# Database Configuration
POSTGRES_USER=recipe_admin
POSTGRES_PASSWORD=dev_password_123
POSTGRES_DB=recipe_database
DB_MAINT_USER=db_maintenance
DB_MAINT_PASSWORD=maint_password_123

# Development Settings
ENVIRONMENT=development
DEBUG_MODE=true

# Monitoring (optional for development)
MONITORING_USER=postgres_exporter
MONITORING_PASSWORD=monitor_pass_123
```

### 3. Start Local Kubernetes

```bash
# Start minikube with sufficient resources
minikube start --cpus=4 --memory=8192 --disk-size=50g

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server

# Verify cluster is ready
kubectl get nodes
```

### 4. Deploy Database

```bash
# Deploy the main database container
./scripts/containerManagement/deploy-container.sh

# Wait for deployment to be ready
kubectl wait --for=condition=Ready pod -l app=recipe-database -n recipe-database --timeout=300s

# Check deployment status
./scripts/containerManagement/get-container-status.sh
```

### 5. Initialize Database

```bash
# Load database schema
./scripts/dbManagement/load-schema.sh

# Load test data for development
./scripts/dbManagement/load-test-fixtures.sh

# Verify database is working
./scripts/dbManagement/db-connect.sh
```

### 6. Setup Monitoring (Optional)

```bash
# Create monitoring user
./scripts/dbManagement/setup-monitoring-user.sh

# Deploy monitoring infrastructure
./scripts/containerManagement/deploy-supporting-services.sh

# Check monitoring status
./scripts/containerManagement/get-supporting-services-status.sh
```

### 7. Access Database

```bash
# Port forward for direct access
kubectl port-forward -n recipe-database svc/recipe-database-service 5432:5432

# Connect with psql (in another terminal)
psql -h localhost -p 5432 -U recipe_admin -d recipe_database

# Access metrics (if monitoring enabled)
kubectl port-forward -n recipe-database svc/recipe-database-service 9187:9187
curl http://localhost:9187/metrics
```

## Production Deployment

### 1. Pre-deployment Checklist

- [ ] Kubernetes cluster is configured and accessible
- [ ] Sufficient resources allocated (CPU, memory, storage)
- [ ] Network policies and security groups configured
- [ ] Backup strategy planned and tested
- [ ] Monitoring infrastructure available (Prometheus/Grafana)
- [ ] SSL certificates ready (if external access needed)
- [ ] Environment variables configured securely

### 2. Production Environment File

Create a production `.env` file with secure values:

```bash
# Production Database Configuration
POSTGRES_USER=recipe_prod_admin
POSTGRES_PASSWORD=$(openssl rand -base64 32)
POSTGRES_DB=recipe_production
DB_MAINT_USER=db_prod_maint
DB_MAINT_PASSWORD=$(openssl rand -base64 32)

# Monitoring Configuration
MONITORING_USER=postgres_exporter
MONITORING_PASSWORD=$(openssl rand -base64 32)

# Production Settings
ENVIRONMENT=production
DEBUG_MODE=false

# Additional production variables...
```

### 3. Secure Secret Management

```bash
# Create namespace
kubectl create namespace recipe-database

# Create secrets using kubectl (more secure than env files in production)
kubectl create secret generic recipe-database-secret \
  --from-literal=POSTGRES_PASSWORD='your-secure-password' \ <!-- pragma: allowlist secret -->
  --from-literal=DB_MAINT_PASSWORD='your-maint-password' \  <!-- pragma: allowlist secret -->
  --from-literal=POSTGRES_EXPORTER_DATA_SOURCE_NAME='postgresql://user:pass@localhost:5432/db?sslmode=require' \  <!-- pragma: allowlist secret -->
  --namespace=recipe-database

# Verify secret creation
kubectl get secrets -n recipe-database
```

### 4. Production Deployment

```bash
# Deploy with production configuration
ENVIRONMENT=production ./scripts/containerManagement/deploy-container.sh

# Initialize database
./scripts/dbManagement/load-schema.sh

# DO NOT load test fixtures in production
# ./scripts/dbManagement/load-test-fixtures.sh  # Skip this step

# Setup monitoring
./scripts/dbManagement/setup-monitoring-user.sh
./scripts/containerManagement/deploy-supporting-services.sh
```

### 5. Production Validation

```bash
# Check all components are healthy
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh

# Test database connectivity
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- pg_isready

# Verify monitoring is working
kubectl port-forward -n recipe-database svc/recipe-database-service 9187:9187
curl -s http://localhost:9187/metrics | head -20
```

### 6. Backup Configuration

```bash
# Create initial backup
./scripts/dbManagement/backup-db.sh

# Set up automated backups (configure according to your infrastructure)
# This might involve setting up CronJobs, backup operators, or external backup services
```

## Environment Configuration

### Environment Variables Reference

#### Required Variables

| Variable            | Description              | Example               |
| ------------------- | ------------------------ | --------------------- |
| `POSTGRES_USER`     | Main database admin user | `recipe_admin`        |
| `POSTGRES_PASSWORD` | Admin user password      | `secure_password_123` |
| `POSTGRES_DB`       | Database name            | `recipe_database`     |
| `DB_MAINT_USER`     | Maintenance user         | `db_maintenance`      |
| `DB_MAINT_PASSWORD` | Maintenance password     | `maint_password_123`  |

#### Optional Variables

| Variable                   | Description         | Default             |
| -------------------------- | ------------------- | ------------------- |
| `MONITORING_USER`          | Monitoring user     | `postgres_exporter` |
| `MONITORING_PASSWORD`      | Monitoring password | Auto-generated      |
| `POSTGRES_MAX_CONNECTIONS` | Max connections     | `100`               |
| `POSTGRES_SHARED_BUFFERS`  | Shared buffers      | `256MB`             |

### Configuration Templates

#### Development Configuration

```bash
# .env.development
POSTGRES_USER=dev_admin
POSTGRES_PASSWORD=dev_password_123
POSTGRES_DB=recipe_dev
DB_MAINT_USER=dev_maint
DB_MAINT_PASSWORD=dev_maint_123
ENVIRONMENT=development
DEBUG_MODE=true
LOG_LEVEL=DEBUG
```

#### Production Configuration

```bash
# .env.production
POSTGRES_USER=prod_admin
POSTGRES_PASSWORD=${SECURE_RANDOM_PASSWORD}
POSTGRES_DB=recipe_production
DB_MAINT_USER=prod_maint
DB_MAINT_PASSWORD=${SECURE_RANDOM_PASSWORD}
ENVIRONMENT=production
DEBUG_MODE=false
LOG_LEVEL=INFO
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=512MB
```

## Database Initialization

### Schema Loading Process

The database initialization follows this sequence:

1. **Schema Creation** (`db/init/schema/001_create_schema.sql`)
2. **Enums Definition** (`db/init/schema/002_create_enums.sql`)
3. **Tables Creation** (`db/init/schema/003_*.sql` to `026_*.sql`)
4. **Functions** (`db/init/functions/*.sql`)
5. **Views** (`db/init/views/*.sql`)
6. **Triggers** (`db/init/triggers/*.sql`)
7. **Users** (`db/init/users/*.sql`)

### Custom Initialization

If you need custom initialization:

```bash
# Create custom SQL files
echo "INSERT INTO recipe_manager.custom_data VALUES (1, 'custom');" > db/init/custom/001_custom_data.sql

# Run custom initialization
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -f /mnt/recipe-database/db/init/custom/001_custom_data.sql
```

### Data Migration

For data migration from existing systems:

```bash
# Export data from existing system
pg_dump -h old-server -U user -d old_db --data-only --inserts > migration_data.sql

# Copy to container and import
kubectl cp migration_data.sql recipe-database/recipe-database-pod:/tmp/
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -f /tmp/migration_data.sql
```

## Monitoring Setup

### Monitoring Components

The monitoring stack includes:

- **postgres_exporter**: Metrics collection from PostgreSQL
- **ServiceMonitor**: Prometheus service discovery
- **PrometheusRule**: Alerting rules
- **ConfigMap**: Custom metrics queries

### Monitoring Prerequisites

For full monitoring functionality, ensure:

- Prometheus Operator is installed in your cluster
- Grafana is available for dashboards
- Proper RBAC permissions for service discovery

### Monitoring Configuration

```bash
# Check if Prometheus Operator is available
kubectl get crd servicemonitors.monitoring.coreos.com

# If available, monitoring will be automatically configured
# If not, manual Prometheus configuration is needed
```

### Custom Metrics

The system includes custom recipe-specific metrics:

- `recipe_stats_total_recipes`: Recipe creation rate
- `user_activity_active_*`: User engagement metrics
- `table_sizes_size_bytes`: Database growth tracking
- `slow_queries_*`: Query performance monitoring

### Grafana Dashboard Import

1. Open Grafana interface
2. Navigate to **Dashboards > Import**
3. Upload `monitoring/grafana-dashboards/postgresql-overview.json`
4. Configure data source (Prometheus)
5. Save and view dashboard

## Troubleshooting

### Common Issues

#### Database Won't Start

**Symptoms**: Pod in CrashLoopBackOff state

**Solutions**:

```bash
# Check pod logs
kubectl logs -n recipe-database deployment/recipe-database -c recipe-database

# Check resource limits
kubectl describe pod -n recipe-database -l app=recipe-database

# Verify PVC is bound
kubectl get pvc -n recipe-database

# Check node resources
kubectl top nodes
```

#### Schema Loading Fails

**Symptoms**: Schema loading script exits with errors

**Solutions**:

```bash
# Check database connectivity
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- pg_isready

# Manual schema loading with debugging
kubectl exec -it -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -v ON_ERROR_STOP=1 < /path/to/schema.sql

# Check for conflicting objects
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "\\dt recipe_manager.*"
```

#### Monitoring Not Working

**Symptoms**: No metrics in Prometheus, postgres_exporter not responding

**Solutions**:

```bash
# Check postgres_exporter logs
kubectl logs -n recipe-database deployment/recipe-database -c postgres-exporter

# Verify monitoring user exists
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "\\du postgres_exporter"

# Test metrics endpoint manually
kubectl exec -n recipe-database deployment/recipe-database -c postgres-exporter -- \
  wget -q -O- http://localhost:9187/metrics | head -10

# Check ServiceMonitor is discovered
kubectl get servicemonitor -n recipe-database
```

#### Connection Issues

**Symptoms**: Cannot connect to database from applications

**Solutions**:

```bash
# Check service configuration
kubectl get svc -n recipe-database
kubectl describe svc recipe-database-service -n recipe-database

# Test connectivity from within cluster
kubectl run test-pod --image=postgres:15 --rm -it --restart=Never -- \
  psql -h recipe-database-service.recipe-database.svc.cluster.local -U recipe_admin -d recipe_database

# Check network policies
kubectl get networkpolicy -n recipe-database
```

### Performance Issues

#### Slow Queries

**Investigation**:

```bash
# Check for long-running queries
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT pid, state, query_start, query
    FROM pg_stat_activity
    WHERE state = 'active' AND query_start < now() - interval '1 minute';"

# Check for locks
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT * FROM pg_locks WHERE NOT granted;"
```

#### High Resource Usage

**Investigation**:

```bash
# Check resource usage
kubectl top pod -n recipe-database

# Check database statistics
kubectl exec -n recipe-database deployment/recipe-database -c recipe-database -- \
  psql -U postgres -d recipe_database -c "
    SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del
    FROM pg_stat_user_tables
    ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC;"
```

### Getting Help

If you encounter issues not covered here:

1. **Check logs** for all components
2. **Review configuration** for typos or missing values
3. **Search existing issues** on GitHub
4. **Create detailed issue** with:
   - Environment details
   - Error messages
   - Steps to reproduce
   - Relevant logs

### Support Resources

- **Documentation**: [docs/](.) directory
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community help
- **Monitoring Guide**: [monitoring/README.md](../monitoring/README.md)
- **Security Policy**: [SECURITY.md](../SECURITY.md)

---

For additional help or specific deployment scenarios, please refer to the other
documentation files or create a GitHub discussion.
