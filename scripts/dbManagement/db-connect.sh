#!/bin/bash
# scripts/dbManagement/db-connect.sh
# Interactive psql session via direct NodePort connection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment from .env file
ENV_FILE="$PROJECT_ROOT/.env.local"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
else
  echo "Error: .env file not found at $ENV_FILE"
  exit 1
fi

# Check for psql
if ! command -v psql &>/dev/null; then
  echo "Error: psql is required but not installed"
  exit 1
fi

echo "═══════════════════════════════════════════════════════"
echo "Connecting to PostgreSQL"
echo "───────────────────────────────────────────────────────"
echo "  Host:     $POSTGRES_HOST:$NODEPORT_POSTGRES"
echo "  Database: $POSTGRES_DB"
echo "  Schema:   $POSTGRES_SCHEMA"
echo "  User:     $DB_MAINT_USER"
echo "───────────────────────────────────────────────────────"

# Interactive psql session with search_path set to schema
PGOPTIONS="-c search_path=$POSTGRES_SCHEMA" \
  PGPASSWORD="$DB_MAINT_PASSWORD" psql \
  -h "$POSTGRES_HOST" \
  -p "$NODEPORT_POSTGRES" \
  -U "$DB_MAINT_USER" \
  -d "$POSTGRES_DB"

echo "───────────────────────────────────────────────────────"
echo "Session ended."
echo "═══════════════════════════════════════════════════════"
