# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Repository Overview

PostgreSQL database system for recipe management, deployed on Kubernetes. Uses a
single `recipe_manager` schema with 43+ tables covering users, recipes,
ingredients, meal planning, collections, and nutritional data.

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
./scripts/dbManagement/import-nutritional-data.sh  # Import USDA FoodData Central
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

The Python importer is run automatically via the shell script:

```bash
# Import USDA FoodData Central nutritional data
./scripts/dbManagement/import-nutritional-data.sh --dataset foundation_food

# Available options:
#   --dataset NAME    foundation_food or sr_legacy_food
#   --date DATE       Dataset release date (e.g., 2024-04-18)
#   --force-download  Force re-download even if files exist
#   --keep-files      Keep downloaded files after completion
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
- Files in `db/init/schema/` numbered for execution order (001-043+)
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

**Functions** (`db/init/functions/`) - 17 functions including:

- `create_recipe.sql` - Recipe creation with ingredients
- `get_average_rating.sql` - Rating calculations
- `get_collection_tags.sql`, `get_meal_plan_tags.sql` - Tag retrieval
- `add_recipe_to_collection.sql`, `check_collection_edit_permission.sql`

**Triggers** (`db/init/triggers/`) - 8 triggers including:

- `set_updated_at_trigger.sql` - Auto-update timestamps
- `prevent_review_self.sql`, `prevent_collaborator_self.sql` - Self-action
  prevention
- `enforce_rating_bounds_trigger.sql` - Validate ratings (1-5)
- `create_default_preferences_trigger.sql` - User preference initialization

**Views** (`db/init/views/`) - 12 views including:

- `vw_recipe_summary.sql`, `vw_recipe_full_details.sql` - Recipe views
- `vw_collection_summary.sql`, `vw_collection_full_details.sql` - Collection
  views
- `vw_user_favorite_*.sql` - User favorites (recipes, collections, meal plans)

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

### Access Patterns

- **Namespace**: `recipe-database`
- **Service**: `recipe-database-service` (port 5432)
- **Metrics**: `postgres-exporter-service` (port 9187, cluster-internal)
- **External**: NodePort via `NODEPORT_POSTGRES` (30000-32767)

All database management scripts use direct NodePort connections via
`recipe-database.local` (requires `/etc/hosts` entry, added by deploy script).

```bash
# Direct connection example
psql -h recipe-database.local -p $NODEPORT_POSTGRES -U $DB_MAINT_USER -d $POSTGRES_DB
```

## Monitoring Setup

```bash
./scripts/dbManagement/setup-monitoring-user.sh
./scripts/containerManagement/deploy-supporting-services.sh
./scripts/containerManagement/get-supporting-services-status.sh
```

Grafana dashboard: `monitoring/grafana-dashboards/postgresql-overview.json`

## Prerequisites

- Kubernetes cluster (minikube for local dev), kubectl, Docker
- PostgreSQL client tools (`psql`, `pg_dump`) - `apt install postgresql-client`
- Python 3.9+ with venv support
- jq, envsubst

## Additional Docs

`docs/setup.md`, `docs/operations.md`, `docs/troubleshooting.md`,
`monitoring/README.md`
