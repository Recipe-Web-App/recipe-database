# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Repository Overview

PostgreSQL-based recipe database system for Kubernetes. Handles user management,
recipes, ingredients, meal planning, and nutritional information with a
`recipe_manager` schema.

## Quick Start

```bash
# 1. Setup environment
cp .env.example .env  # Edit with your configuration

# 2. Deploy and initialize
./scripts/containerManagement/deploy-container.sh
./scripts/dbManagement/load-schema.sh
./scripts/dbManagement/load-test-fixtures.sh  # Optional test data

# 3. Connect to database
./scripts/dbManagement/db-connect.sh
```

## Development Commands

### Database Operations

```bash
./scripts/dbManagement/load-schema.sh           # Load/reload schema
./scripts/dbManagement/load-test-fixtures.sh    # Load test data
./scripts/dbManagement/db-connect.sh            # Interactive psql session
./scripts/dbManagement/backup-db.sh             # Backup database
./scripts/dbManagement/export-schema.sh         # Export schema
./scripts/dbManagement/import-nutritional-data.sh  # Import OpenFoodFacts data
```

### Container Management

```bash
./scripts/containerManagement/deploy-container.sh          # Deploy PostgreSQL
./scripts/containerManagement/deploy-supporting-services.sh # Deploy monitoring
./scripts/containerManagement/get-container-status.sh      # Check status
./scripts/containerManagement/get-supporting-services-status.sh
./scripts/containerManagement/start-container.sh
./scripts/containerManagement/stop-container.sh
./scripts/containerManagement/cleanup-supporting-services.sh
```

### Python (Nutritional Data Importer)

```bash
# Setup
python3 -m venv venv && source venv/bin/activate
pip install -r python/requirements.txt

# Run importer
python3 python/nutritional_data_importer/nutritional_data_importer.py \
  --csv-file /path/to/openfoodfacts.csv --batch-size 1000 --verbose

# Run tests
cd python && pytest --cov=nutritional_data_importer
```

### Linting and Formatting

**Use pre-commit for all checks** (preferred method):

```bash
pre-commit run --all-files  # Run all hooks
pre-commit install          # Install git hooks
```

Individual tools (if needed):

```bash
# Python (from python/ directory)
black . && isort . && flake8 . && mypy .

# SQL
sqlfluff lint db/init/schema/ --dialect postgres
sqlfluff fix db/init/schema/ --dialect postgres

# Shell scripts
shellcheck scripts/**/*.sh
shfmt -w scripts/**/*.sh

# Kubernetes manifests
kubectl apply --dry-run=client -f k8s/
```

## Code Style and Conventions

### Commit Messages

**Conventional commits are required** (enforced by pre-commit hook):

```
feat(schema): add recipe collections table
fix(triggers): correct rating bounds validation
refactor(notifications): restructure notification schema
docs: update setup instructions
chore: update pre-commit hooks
```

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

### SQL Conventions

- Always use schema-qualified names: `recipe_manager.table_name`
- Use `CREATE OR REPLACE` for functions and views
- Include `IF EXISTS` for idempotent operations
- File naming: `NNN_action_object.sql` (e.g., `035_create_tags_table.sql`)

### Python Style

- Black formatter with 88-char line length
- isort with black profile
- Type hints encouraged (mypy strict-optional)
- Files must include license header (auto-added by pre-commit)

## Database Architecture

### Schema Organization

- All tables in `recipe_manager` schema
- Files in `db/init/schema/` numbered for execution order (001-035+)
- Functions in `db/init/functions/`, triggers in `db/init/triggers/`
- Views in `db/init/views/`, fixtures in `db/fixtures/`

### Core Entities

- **Users**: Role-based permissions (admin, recipe_manager, user)
- **Recipes**: With ingredients, steps, reviews, revisions, tags
- **Ingredients**: Catalog with nutritional info and allergens
- **Meal Plans**: User meal planning with calendar integration
- **Recipe Collections**: Collaborative recipe organization
- **User Preferences**: 9 preference categories (notifications, display,
  privacy, etc.)

### Key Database Components

**Functions** (`db/init/functions/`):

- `create_recipe.sql` - Recipe creation with ingredients
- `get_average_rating.sql` - Rating calculations
- `get_user_meal_plans.sql` - Meal plan queries

**Triggers** (`db/init/triggers/`):

- `set_updated_at_trigger.sql` - Auto-update timestamps
- `prevent_review_self.sql` - Prevent self-reviews
- `enforce_rating_bounds_trigger.sql` - Validate ratings (1-5)

**Views** (`db/init/views/`):

- `vw_recipe_summary.sql` - Recipe overview with ratings
- `vw_top_rated_recipes.sql` - Highest rated recipes
- `vw_recipe_full_details.sql` - Complete recipe details

### Database User Roles

- **POSTGRES_USER**: Full admin access
- **DB_MAINT_USER**: Schema management
- **MONITORING_USER**: Read-only for postgres_exporter
- **Service Users**: Minimal permissions per service (recipe_management_user,
  user_management_user, etc.)

## Schema Modifications

1. Backup: `./scripts/dbManagement/backup-db.sh`
2. Create numbered file in `db/init/schema/` (use next available number)
3. Add related functions/triggers/views as needed
4. Add fixture data in `db/fixtures/` with matching number
5. Test: reload schema and verify with `db-connect.sh`

For production: use ALTER TABLE migrations, not DROP/CREATE.

## Kubernetes Deployment

### Resources (in `k8s/`)

- `deployment.yaml` - PostgreSQL deployment
- `*-template.yaml` - Templates requiring envsubst (handled by deploy scripts)
- `postgres-exporter-*.yaml` - Monitoring exporter
- `servicemonitor.yaml`, `prometheusrule.yaml` - Prometheus integration
- Jobs in `k8s/jobs/` for one-time operations

### Access Patterns

- **Namespace**: `recipe-database`
- **Service**: `recipe-database-service` (port 5432)
- **Metrics**: `postgres-exporter-service` (port 9187, cluster-internal)
- **External**: NodePort via `NODEPORT_POSTGRES` (30000-32767)

Port forwarding for local access:

```bash
kubectl port-forward -n recipe-database svc/recipe-database-service 5432:5432
```

## Monitoring Setup

```bash
./scripts/dbManagement/setup-monitoring-user.sh
./scripts/containerManagement/deploy-supporting-services.sh
./scripts/containerManagement/get-supporting-services-status.sh
```

Grafana dashboard: `monitoring/grafana-dashboards/postgresql-overview.json`

## Prerequisites

- Kubernetes cluster (minikube for local dev)
- kubectl, Docker, psql
- Python 3.9+ for data processing
- jq, envsubst for scripts

## Additional Documentation

- `docs/setup.md` - Installation details
- `docs/operations.md` - Day-to-day management
- `docs/troubleshooting.md` - Common issues
- `monitoring/README.md` - Monitoring setup
