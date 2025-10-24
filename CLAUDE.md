# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Repository Overview

This is a PostgreSQL-based recipe database system designed to run in Kubernetes.
The database handles user management, recipes, ingredients, meal planning, and
nutritional information through a well-structured schema with comprehensive user
preferences support.

## Database Architecture

The system uses PostgreSQL 15.4 with a `recipe_manager` schema containing:

### Core Entities

- **Users**: User accounts with role-based permissions (admin, recipe_manager,
  user)
- **Recipes**: Recipe data with ingredients, steps, reviews, and revisions
- **Ingredients**: Ingredient catalog with nutritional information
- **Meal Plans**: User meal planning functionality
- **Recipe Collections**: User-created collections for organizing recipes with
  visibility and collaboration controls
- **User Preferences**: Comprehensive preference system covering notifications,
  display, privacy, accessibility, language, security, social, sound, and theme
  settings

### Key Features

- User follows and social interactions
- Recipe versioning and revisions
- Rating and review system
- Tag-based recipe categorization
- Recipe collections with collaborative editing
- Nutritional data integration
- Advanced user preference management

### Architectural Patterns

**Schema Organization**:

- Single `recipe_manager` schema for all application tables
- Numbered execution order for reliable initialization (001-035)
- Separation of concerns: schema, functions, triggers, views, users

**Data Integrity**:

- Foreign key constraints with CASCADE/RESTRICT policies
- CHECK constraints for data validation
- Triggers for business logic enforcement (rating bounds, duplicate prevention)
- Automatic timestamp management via `updated_at` triggers

**User Preferences Architecture**:

- Separate tables for each preference category (9 categories total)
- JSON/JSONB for flexible configuration storage
- Enum types for controlled values
- Default values ensure all users have complete preferences

**Monitoring Architecture**:

- Sidecar pattern: postgres_exporter runs alongside PostgreSQL
- Separate deployment option for independent scaling
- Custom metrics via queries in ConfigMap
- ServiceMonitor for automatic Prometheus discovery

## Development Commands

### Quick Start Workflow

```bash
# 1. Deploy the main database container (PostgreSQL only)
./scripts/containerManagement/deploy-container.sh

# 2. Load database schema
./scripts/dbManagement/load-schema.sh

# 3. Load test data (optional but recommended for development)
./scripts/dbManagement/load-test-fixtures.sh

# 4. Setup monitoring (optional - requires steps 1-3 to be complete)
./scripts/dbManagement/setup-monitoring-user.sh
./scripts/containerManagement/deploy-supporting-services.sh
```

### Database Schema Management

```bash
# Load database schema (requires Kubernetes)
./scripts/dbManagement/load-schema.sh

# Load test fixtures
./scripts/dbManagement/load-test-fixtures.sh

# Import nutritional data from OpenFoodFacts CSV
./scripts/dbManagement/import-nutritional-data.sh

# Connect directly to database
./scripts/dbManagement/db-connect.sh

# Export schema for backups
./scripts/dbManagement/export-schema.sh

# Setup monitoring user for postgres_exporter
./scripts/dbManagement/setup-monitoring-user.sh

# Backup database
./scripts/dbManagement/backup-db.sh
```

### Container Management

```bash
# Deploy main database container (PostgreSQL only)
./scripts/containerManagement/deploy-container.sh

# Deploy monitoring and supporting services (postgres-exporter, ServiceMonitor, PrometheusRule)
./scripts/containerManagement/deploy-supporting-services.sh

# Get status of supporting services and monitoring
./scripts/containerManagement/get-supporting-services-status.sh

# Clean up supporting services (keeps main database)
./scripts/containerManagement/cleanup-supporting-services.sh

# Start container
./scripts/containerManagement/start-container.sh

# Stop container
./scripts/containerManagement/stop-container.sh

# Get container status
./scripts/containerManagement/get-container-status.sh
```

### Python Development (Nutritional Data Importer)

**Python Version**: Requires Python 3.8+

```bash
# Setup virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install Python dependencies
pip install -r python/requirements.txt

# Import nutritional data directly with Python
python3 python/nutritional_data_importer/nutritional_data_importer.py \
  --csv-file /path/to/openfoodfacts.csv \
  --batch-size 1000 \
  --verbose

# Code formatting and linting (run these before committing)
cd python/nutritional_data_importer
black .
isort .
flake8 .
mypy .
```

**Python Modules in nutritional_data_importer**:

- `nutritional_data_importer.py` - Main entry point
- `csv_validation.py` - CSV file validation
- `data_cleaning.py` - Data cleaning and normalization
- `data_processing.py` - Data transformation
- `allergen_mapping.py` - Allergen data mapping
- `food_groups_mapping.py` - Food group categorization
- `duplicate_handling.py` - Duplicate detection and resolution
- `database.py` - Database connection and operations
- `import_core.py` - Core import logic

## Database Schema Structure

### Schema Files Location

Database schema files are organized in `db/init/schema/` with numbered prefixes
for ordered execution:

- `001_create_schema.sql` - Main schema creation
- `002_create_enums.sql` - Enum definitions
- `003-032_*.sql` - Table creation scripts (executed in numerical order)

**Execution Order**: Files are executed alphabetically by name, so the numbering
ensures proper dependency order (e.g., tables before foreign keys, enums before
tables that use them).

### Key Database Components

- **Functions**: Stored procedures in `db/init/functions/`
  - `create_recipe.sql` - Recipe creation with ingredients
  - `get_average_rating.sql` - Rating calculations
  - `get_user_meal_plans.sql` - Meal plan queries
  - `update_timestamp.sql` - Automatic timestamp updates
- **Triggers**: Database triggers in `db/init/triggers/`
  - `set_updated_at_trigger.sql` - Auto-update timestamps
  - `prevent_review_self.sql` - Prevent self-reviews
  - `prevent_duplicate_follow_trigger.sql` - Enforce unique follows
  - `enforce_rating_bounds_trigger.sql` - Validate ratings
- **Views**: Database views in `db/init/views/`
  - `vw_recipe_summary.sql` - Recipe overview with ratings
  - `vw_top_rated_recipes.sql` - Highest rated recipes
  - `vw_user_favorite_recipes.sql` - User favorites
  - `vw_recipe_full_details.sql` - Complete recipe details
- **Users**: Database role templates in `db/init/users/`
  - Service-specific database users with minimal required permissions
  - Templates use envsubst for credential substitution
- **Fixtures**: Test data in `db/fixtures/` (numbered 001-025 for ordered
  loading)

## Kubernetes Deployment

The system is designed for Kubernetes deployment with:

- **ConfigMaps and Secrets**: Configuration and credentials management
- **Deployment**: PostgreSQL database with postgres_exporter sidecar
- **Service**: Internal service exposure (ports 5432, 9187)
- **PVC**: Persistent volume for database storage
- **Jobs**: One-time tasks for initialization and data import
- **Monitoring Resources**: ServiceMonitor and PrometheusRule for observability

### Kubernetes Resources

All manifests are in the `k8s/` directory:

- `deployment.yaml` - Main PostgreSQL deployment
- `service.yaml` - Service definition
- `pvc.yaml` - Persistent volume claim
- `configmap-template.yaml` - Database configuration (requires envsubst)
- `secret-template.yaml` - Credentials (requires envsubst)
- `postgres-exporter-deployment.yaml` - Metrics exporter
- `postgres-exporter-service.yaml` - Exporter service
- `postgres-exporter-configmap.yaml` - Exporter configuration
- `servicemonitor.yaml` - Prometheus service discovery
- `prometheusrule.yaml` - Alerting rules

### Kubernetes Jobs

Jobs are located in `k8s/jobs/` and used for one-time operations:

- `db-load-schema-job.yaml` - Initialize database schema
- `db-load-test-fixtures-job.yaml` - Load test data
- `db-import-nutritional-data-job.yaml` - Import OpenFoodFacts data
- `db-restore-nutritional-data-job.yaml` - Restore nutritional data from backup

Jobs use helper scripts from `scripts/jobHelpers/` which are mounted into the
job containers.

## Data Import Pipeline

The Python-based nutritional data importer (`python/nutritional_data_importer/`)
handles:

- CSV validation and cleaning
- Allergen and food group mapping
- Duplicate detection and handling
- Database insertion with proper error handling

## Working with the Database

### Schema Migrations and Modifications

When modifying the database schema, follow this workflow:

1. **Backup first**: Always backup before schema changes

   ```bash
   ./scripts/dbManagement/backup-db.sh
   ```

2. **Add new schema files**: Create files with appropriate numbering in
   `db/init/schema/`
   - Use next available number (e.g., `027_create_new_table.sql`)
   - Follow naming convention: `NNN_action_object.sql`
   - Ensure proper dependencies (reference existing tables/types)

3. **Update related components**:
   - Add functions if needed in `db/init/functions/`
   - Add triggers if needed in `db/init/triggers/`
   - Update or add views in `db/init/views/`
   - Add fixture data in `db/fixtures/` with matching number

4. **Test the changes**:

   ```bash
   # Reload schema (destructive - use dev environment only)
   ./scripts/dbManagement/load-schema.sh

   # Load test data
   ./scripts/dbManagement/load-test-fixtures.sh

   # Connect and verify
   ./scripts/dbManagement/db-connect.sh
   ```

5. **For production migrations**:
   - Write separate migration scripts (ALTER TABLE, not DROP/CREATE)
   - Test on staging environment first
   - Plan rollback strategy
   - Consider downtime requirements

### Database User Roles

The system uses multiple database users with specific permissions:

- **POSTGRES_USER** (admin_user): Full database ownership and administration
- **DB_MAINT_USER**: Schema management and maintenance operations
- **MONITORING_USER**: Read-only access for postgres_exporter metrics
- **Service Users**: Application-specific users (recipe_management_user,
  user_management_user, etc.) with minimal required permissions

Templates for creating service users are in `db/init/users/` and use environment
variable substitution.

## Development Environment

### Prerequisites

The system expects:

- **Kubernetes cluster**: minikube for local development
- **kubectl**: configured for your cluster
- **Docker**: for container building
- **PostgreSQL client tools**: psql for direct database access
- **Python 3.8+**: for nutritional data processing
- **jq**: for JSON processing in scripts
- **envsubst**: for template processing

### Environment Setup

1. **Copy and customize environment variables**:

   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

   **Key environment variables** (see `.env.example` for complete list):
   - **Database credentials**: `POSTGRES_USER`, `POSTGRES_PASSWORD`,
     `POSTGRES_DB`
   - **Service users**: `DB_MAINT_USER`, `MONITORING_USER`, etc.
   - **Kubernetes config**: `K8S_NAMESPACE`, storage settings
   - **Resource limits**: CPU/memory requests and limits
   - **Monitoring**: `MONITORING_USER`, `MONITORING_PASSWORD`
   - **Data processing**: `OPENFOODS_CSV_PATH`, `IMPORT_BATCH_SIZE`

   **Note**: Template files (`*-template.yaml`) use `envsubst` to substitute
   environment variables. The deployment scripts handle this automatically.

2. **Ensure kubectl is configured** for the `recipe-database` namespace:

   ```bash
   kubectl config set-context --current --namespace=recipe-database
   ```

3. **For Minikube users**, the deploy script will automatically:
   - Start Minikube if not running
   - Enable ingress addon
   - Set up Docker environment
   - Mount local directory for persistent data at `/data`

## Monitoring and Observability

The system includes comprehensive PostgreSQL monitoring using Prometheus and
Grafana:

### Monitoring Components

- **postgres_exporter**: Separate deployment for metrics collection (port 9187)
- **ServiceMonitor**: Automatic Prometheus service discovery
- **PrometheusRule**: Alerting rules for critical database conditions
- **Custom metrics**: Recipe-specific business metrics and performance data
- **Grafana dashboards**: Pre-configured visualization dashboards

### Monitoring Setup Workflow

1. Deploy main database: `./scripts/containerManagement/deploy-container.sh`
2. Load database schema: `./scripts/dbManagement/load-schema.sh`
3. Setup monitoring user: `./scripts/dbManagement/setup-monitoring-user.sh`
4. Deploy monitoring services:
   `./scripts/containerManagement/deploy-supporting-services.sh`
5. Check status:
   `./scripts/containerManagement/get-supporting-services-status.sh`
6. Import Grafana dashboard from
   `monitoring/grafana-dashboards/postgresql-overview.json`

### Available Metrics

- Standard PostgreSQL metrics (connections, queries, performance)
- Recipe-specific business metrics (creation rates, user engagement)
- Custom query performance tracking
- Database health and diagnostic information

See `monitoring/README.md` for detailed setup instructions and troubleshooting.

## CI/CD and Automation

The repository includes comprehensive GitHub Actions workflows in
`.github/workflows/`:

### Continuous Integration

- **ci.yml**: Main CI pipeline
  - Validates SQL syntax
  - Checks shell scripts with shellcheck
  - Runs Python linting (black, isort, flake8, mypy)
  - Validates Kubernetes manifests

- **docker-ci.yml**: Docker image building and testing
  - Builds PostgreSQL container image
  - Tests container initialization
  - Validates schema loading

- **codeql.yml**: Security scanning with CodeQL
  - Analyzes code for security vulnerabilities
  - Runs on pull requests and scheduled

### Release and Deployment

- **release.yml**: Automated release process
  - Creates tagged releases
  - Generates changelog
  - Builds and publishes container images

### Quality and Maintenance

- **security.yml**: Security scanning and vulnerability checks
- **pr-labeler.yml**: Automatic PR labeling
- **pr-size.yml**: PR size tracking
- **stale.yml**: Stale issue and PR management
- **links.yml**: Documentation link validation
- **dependabot.yml**: Automated dependency updates

### Pre-commit Checks

Before committing, ensure code quality:

```bash
# Python formatting and linting
cd python/nutritional_data_importer
black . && isort . && flake8 . && mypy .

# Shell script validation (if modified)
shellcheck scripts/**/*.sh

# Kubernetes manifest validation (if modified)
kubectl apply --dry-run=client -f k8s/
```

## Testing

### Test Fixtures

The project uses comprehensive test fixtures for development and testing:

```bash
# Load all test fixtures (requires database to be running)
./scripts/dbManagement/load-test-fixtures.sh
```

**Fixture categories** (in `db/fixtures/`):

- User data: `001_users.sql`, `002_user_follows.sql`
- Preferences: `015-023_user_*_preferences.sql` (9 preference categories)
- Recipes: `005_recipes.sql`, `006_recipe_ingredients.sql`,
  `007_recipe_steps.sql`
- Social features: `009_recipe_reviews.sql`, `010_recipe_favorites.sql`
- Meal planning: `013_meal_plans.sql`, `014_meal_plan_recipes.sql`
- Nutritional data: `024_nutritional_info.sql`

### Manual Testing

```bash
# 1. Deploy and initialize database
./scripts/containerManagement/deploy-container.sh
./scripts/dbManagement/load-schema.sh
./scripts/dbManagement/load-test-fixtures.sh

# 2. Connect and run test queries
./scripts/dbManagement/db-connect.sh

# 3. Example test queries
# SELECT * FROM recipe_manager.vw_recipe_summary LIMIT 10;
# SELECT * FROM recipe_manager.vw_top_rated_recipes;
# SELECT recipe_manager.get_average_rating(1);
```

## Troubleshooting and Operations

### Common Operations

```bash
# Check system health
./scripts/containerManagement/get-container-status.sh
./scripts/containerManagement/get-supporting-services-status.sh

# View logs
kubectl logs -n recipe-database deployment/recipe-database -c recipe-database --tail=100

# Port forward for external access
kubectl port-forward -n recipe-database svc/recipe-database-service 5432:5432

# Access metrics endpoint
kubectl port-forward -n recipe-database svc/postgres-exporter-service 9187:9187
curl http://localhost:9187/metrics
```

### Key Documentation

- `docs/setup.md` - Detailed installation instructions
- `docs/operations.md` - Day-to-day management procedures
- `docs/troubleshooting.md` - Common issues and solutions
- `monitoring/README.md` - Comprehensive monitoring setup

### Database Access Patterns

- **Namespace**: All resources are in `recipe-database` namespace
- **Database Service**: `recipe-database-service`
- **Monitoring Service**: `postgres-exporter-service`
- **Database Port**: 5432 (PostgreSQL)
- **Metrics Port**: 9187 (postgres_exporter)
- **Schema**: All tables use the `recipe_manager` schema
- **Main Database**: Specified by `POSTGRES_DB` environment variable

## Important Notes

### When Working with SQL Files

- Always use schema-qualified names: `recipe_manager.table_name`
- Include proper `IF EXISTS` checks for idempotent operations
- Use `CREATE OR REPLACE` for functions and views
- Follow the numbered naming convention for execution order
- Include comments explaining complex logic or business rules

### When Working with Scripts

- All scripts use bash and include error handling (`set -e`)
- Scripts check for required tools (`kubectl`, `psql`, etc.)
- Helper scripts in `scripts/utils/` provide common functionality
- Job helper scripts (`scripts/jobHelpers/`) are designed to run in Kubernetes
  pods
- Container management scripts handle environment detection (minikube vs
  production)

### When Working with Kubernetes Manifests

- Always use templates (`*-template.yaml`) for files with secrets/credentials
- Run `envsubst` before applying to substitute environment variables
- The deployment scripts handle this automatically
- Test with `kubectl apply --dry-run=client -f <file>`
- Use labels consistently: `app=recipe-database` for all related resources

### Security Considerations

- Never commit actual credentials to the repository
- Use Kubernetes secrets for sensitive data
- Service users have minimal required permissions only
- Connection strings should use cluster-internal DNS names
- SSL/TLS is recommended for production (configure via `POSTGRES_SSL_MODE`)

### Performance Considerations

- Database has indexes on foreign keys and frequently queried columns
- Views are not materialized - consider materialized views for heavy queries
- Connection pooling recommended for application services
- Monitor cache hit ratio via Prometheus metrics
- Use EXPLAIN ANALYZE for query optimization

### Data Retention

Per `.env.example` configuration:

- User notifications: 90 days default retention
- Recipe revisions: 365 days default retention
- Activity logs: 180 days default retention

Implement cleanup jobs as needed for production environments.
