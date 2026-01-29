#!/bin/bash
# scripts/dbManagement/_db-common.sh
# Shared functions for database management scripts
# Uses direct NodePort connection to PostgreSQL

# Prevent multiple sourcing
if [[ -n "${_DB_COMMON_LOADED:-}" ]]; then
  return 0
fi
_DB_COMMON_LOADED=1

# Terminal width for formatting
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# =============================================================================
# Output Formatting
# =============================================================================

function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

function log_info() {
  echo "$1"
}

function log_success() {
  echo "$1"
}

function log_warning() {
  echo "Warning: $1"
}

function log_error() {
  echo "Error: $1" >&2
}

# =============================================================================
# Environment Loading
# =============================================================================

function load_env() {
  local env_file="${1:-.env}"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  local project_root
  project_root="$(cd "$script_dir/../.." && pwd)"

  # Try project root first, then current directory
  if [[ -f "$project_root/$env_file" ]]; then
    env_file="$project_root/$env_file"
  elif [[ ! -f "$env_file" ]]; then
    log_warning "No $env_file file found. Using environment variables or defaults."
    _set_defaults
    return 0
  fi

  log_info "Loading environment from $env_file..."
  set -o allexport
  # shellcheck source=../../.env
  source "$env_file"

  # Source .env.local if it exists (overrides .env values)
  local env_local="$project_root/.env.local"
  if [[ -f "$env_local" ]]; then
    log_info "Loading local overrides from $env_local..."
    # shellcheck source=../../.env.local
    source "$env_local"
  fi
  set +o allexport
  _set_defaults
  log_success "Environment loaded."
}

function _set_defaults() {
  # Connection defaults for NodePort access
  export POSTGRES_HOST="${POSTGRES_HOST:-recipe-database.local}"
  export POSTGRES_PORT="${NODEPORT_POSTGRES:-30382}"
  export POSTGRES_DB="${POSTGRES_DB:-recipe_database}"
  export POSTGRES_SCHEMA="${POSTGRES_SCHEMA:-recipe_manager}"

  # User defaults
  export POSTGRES_USER="${POSTGRES_USER:-admin_user}"
  export DB_MAINT_USER="${DB_MAINT_USER:-db_maint_user}"

  # Paths
  export LOCAL_PATH="${LOCAL_PATH:-$(cd "$(dirname "${BASH_SOURCE[1]}")/../.." && pwd)}"
}

# =============================================================================
# Database Connection Functions
# =============================================================================

# Get psql connection arguments for maintenance user
function get_psql_args() {
  echo "-h $POSTGRES_HOST -p $POSTGRES_PORT -d $POSTGRES_DB"
}

# Get psql connection arguments for admin user
function get_psql_admin_args() {
  echo "-h $POSTGRES_HOST -p $POSTGRES_PORT -d $POSTGRES_DB"
}

# Check database connectivity
function check_db_connection() {
  local user="${1:-$DB_MAINT_USER}"
  local password_var="${2:-DB_MAINT_PASSWORD}"
  local password="${!password_var}"

  log_info "Testing database connection to $POSTGRES_HOST:$POSTGRES_PORT..."

  if PGPASSWORD="$password" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$user" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; then
    log_success "Database connection successful."
    return 0
  else
    log_error "Cannot connect to database at $POSTGRES_HOST:$POSTGRES_PORT"
    log_error "Ensure the database is running and accessible via NodePort."
    log_error "Check that /etc/hosts has entry: <MINIKUBE_IP> recipe-database.local"
    return 1
  fi
}

# =============================================================================
# SQL Execution Functions
# =============================================================================

# Execute SQL command with maintenance user
function execute_sql() {
  local sql="$1"
  local description="${2:-Executing SQL}"

  log_info "$description..."

  if PGPASSWORD="$DB_MAINT_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$DB_MAINT_USER" -d "$POSTGRES_DB" -c "$sql" >/dev/null 2>&1; then
    log_success "$description completed."
    return 0
  else
    log_error "$description failed."
    return 1
  fi
}

# Execute SQL command with admin user (for schema/user operations)
function execute_sql_admin() {
  local sql="$1"
  local description="${2:-Executing SQL}"

  log_info "$description..."

  if PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$sql" >/dev/null 2>&1; then
    log_success "$description completed."
    return 0
  else
    log_error "$description failed."
    return 1
  fi
}

# Execute SQL file with envsubst for variable substitution
function execute_sql_file() {
  local file="$1"
  local description="${2:-Executing $file}"
  local user="${3:-$DB_MAINT_USER}"
  local password_var="${4:-DB_MAINT_PASSWORD}"
  local password="${!password_var}"

  if [[ ! -f "$file" ]]; then
    log_error "SQL file not found: $file"
    return 1
  fi

  log_info "$description..."

  # Use envsubst for variable substitution, then execute
  if envsubst <"$file" | PGPASSWORD="$password" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$user" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 >/dev/null 2>&1; then
    log_success "$description completed."
    return 0
  else
    log_error "$description failed."
    return 1
  fi
}

# Execute SQL file with verbose output (shows errors)
function execute_sql_file_verbose() {
  local file="$1"
  local description="${2:-Executing $file}"
  local user="${3:-$DB_MAINT_USER}"
  local password_var="${4:-DB_MAINT_PASSWORD}"
  local password="${!password_var}"

  if [[ ! -f "$file" ]]; then
    log_error "SQL file not found: $file"
    return 1
  fi

  log_info "$description..."

  # Use envsubst for variable substitution, show output
  if envsubst <"$file" | PGPASSWORD="$password" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
    -U "$user" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1; then
    log_success "$description completed."
    return 0
  else
    log_error "$description failed."
    return 1
  fi
}

# =============================================================================
# Backup/Dump Functions
# =============================================================================

# Run pg_dump with common options
function run_pg_dump() {
  local output_file="$1"
  local tables="${2:-}" # Optional: specific tables
  local schema_only="${3:-false}"
  local user="${4:-$DB_MAINT_USER}"
  local password_var="${5:-DB_MAINT_PASSWORD}"
  local password="${!password_var}"

  local dump_args="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $user -d $POSTGRES_DB"
  dump_args+=" --no-owner --no-acl"

  if [[ "$schema_only" == "true" ]]; then
    dump_args+=" --schema-only"
  fi

  # Add schema filter
  dump_args+=" -n $POSTGRES_SCHEMA"

  # Add specific tables if provided
  if [[ -n "$tables" ]]; then
    for table in $tables; do
      dump_args+=" -t $POSTGRES_SCHEMA.$table"
    done
  fi

  log_info "Running pg_dump..."

  # shellcheck disable=SC2086
  if PGPASSWORD="$password" pg_dump $dump_args | gzip >"$output_file"; then
    log_success "Dump completed: $output_file"
    return 0
  else
    log_error "pg_dump failed"
    return 1
  fi
}

# =============================================================================
# Utility Functions
# =============================================================================

# Get project root directory
function get_project_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  cd "$script_dir/../.." && pwd
}

# Ensure required commands are available
function require_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    log_error "Install with: apt install postgresql-client"
    return 1
  fi
  return 0
}
