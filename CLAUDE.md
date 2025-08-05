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
- **User Preferences**: Comprehensive preference system covering notifications,
  display, privacy, accessibility, language, security, social, sound, and theme
  settings

### Key Features

- User follows and social interactions
- Recipe versioning and revisions
- Rating and review system
- Tag-based recipe categorization
- Nutritional data integration
- Advanced user preference management

## Development Commands

### Database Schema Management

```bash
# Load database schema (requires Kubernetes)
./scripts/dbManagement/load-schema.sh

# Load test fixtures
./scripts/dbManagement/load-test-fixtures.sh

# Import nutritional data
./scripts/dbManagement/import-nutritional-data.sh

# Setup monitoring user for postgres_exporter
./scripts/dbManagement/setup-monitoring-user.sh

# Backup database
./scripts/dbManagement/backup-db.sh
```

### Container Management

```bash
# Deploy main database container
./scripts/containerManagement/deploy-container.sh

# Deploy monitoring and supporting services
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

```bash
# Install Python dependencies
cd python && pip install -r requirements.txt

# Code formatting and linting
black nutritional_data_importer/
isort nutritional_data_importer/
flake8 nutritional_data_importer/
mypy nutritional_data_importer/
```

## Database Schema Structure

### Schema Files Location

Database schema files are organized in `db/init/schema/` with numbered prefixes
for ordered execution:

- `001_create_schema.sql` - Main schema creation
- `002_create_enums.sql` - Enum definitions
- `003-026_*.sql` - Table creation scripts

### Key Database Components

- **Functions**: Stored procedures in `db/init/functions/`
- **Triggers**: Database triggers in `db/init/triggers/`
- **Views**: Database views in `db/init/views/`
- **Users**: Database role templates in `db/init/users/`
- **Fixtures**: Test data in `db/fixtures/`

## Kubernetes Deployment

The system is designed for Kubernetes deployment with:

- ConfigMaps and Secrets for configuration
- Jobs for database initialization and data import
- PVC for persistent storage
- Service exposure

Kubernetes manifests are in the `k8s/` directory.

## Data Import Pipeline

The Python-based nutritional data importer (`python/nutritional_data_importer/`)
handles:

- CSV validation and cleaning
- Allergen and food group mapping
- Duplicate detection and handling
- Database insertion with proper error handling

## Working with the Database

When modifying the database schema:

1. Create new schema files with appropriate numbering in `db/init/schema/`
2. Update triggers, functions, or views as needed
3. Test with fixtures using `load-test-fixtures.sh`
4. Use the backup scripts before major changes

## Development Environment

The system expects:

- Kubernetes cluster access for database operations
- PostgreSQL client tools for direct database access
- Python 3.x for nutritional data processing
- Proper kubectl configuration for the `recipe-database` namespace

## Monitoring and Observability

The system includes comprehensive PostgreSQL monitoring using Prometheus and
Grafana:

### Monitoring Components

- **postgres_exporter**: Sidecar container for metrics collection (port 9187)
- **ServiceMonitor**: Automatic Prometheus service discovery
- **PrometheusRule**: Alerting rules for critical database conditions
- **Custom metrics**: Recipe-specific business metrics and performance data
- **Grafana dashboards**: Pre-configured visualization dashboards

### Monitoring Setup Workflow

1. Deploy main database: `./scripts/containerManagement/deploy-container.sh`
2. Setup monitoring user: `./scripts/dbManagement/setup-monitoring-user.sh`
3. Deploy monitoring services:
   `./scripts/containerManagement/deploy-supporting-services.sh`
4. Check status:
   `./scripts/containerManagement/get-supporting-services-status.sh`
5. Import Grafana dashboard from
   `monitoring/grafana-dashboards/postgresql-overview.json`

### Available Metrics

- Standard PostgreSQL metrics (connections, queries, performance)
- Recipe-specific business metrics (creation rates, user engagement)
- Custom query performance tracking
- Database health and diagnostic information

See `monitoring/README.md` for detailed setup instructions and troubleshooting.
