#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Set up PostgreSQL monitoring user.

This script creates a monitoring user for postgres_exporter and updates
the Kubernetes secret with the connection credentials.

Usage:
    python -m db_tools.setup_monitoring
    python -m db_tools.setup_monitoring --user my_exporter --skip-k8s
"""

import argparse
import base64
import json
import os
import secrets
import subprocess  # nosec B404
import sys
import time

import psycopg2
from cli_utils.console import (
    console,
    print_done,
    print_error,
    print_header,
    print_success,
    print_warning,
)
from cli_utils.environment import get_project_root, load_env

NAMESPACE = "recipe-database"


def generate_password(length: int = 25) -> str:
    """Generate a secure random password.

    Args:
        length: Password length

    Returns:
        Secure random password
    """
    # Use secrets module for cryptographically secure random strings
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return "".join(secrets.choice(alphabet) for _ in range(length))


def get_admin_connection():
    """Get database connection using admin credentials.

    Returns:
        PostgreSQL connection object

    Raises:
        psycopg2.Error: If connection fails
        ValueError: If required environment variables are missing
    """
    host = os.getenv("POSTGRES_HOST")
    port = os.getenv("POSTGRES_PORT", "5432")
    database = os.getenv("POSTGRES_DB")
    user = os.getenv("POSTGRES_USER")
    password = os.getenv("POSTGRES_PASSWORD")

    missing = []
    if not host:
        missing.append("POSTGRES_HOST")
    if not database:
        missing.append("POSTGRES_DB")
    if not user:
        missing.append("POSTGRES_USER")
    if not password:
        missing.append("POSTGRES_PASSWORD")

    if missing:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing)}"
        )

    conn = psycopg2.connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password,
    )
    conn.autocommit = True

    return conn


def create_monitoring_user(conn, username: str, password: str, database: str) -> bool:
    """Create the monitoring user in PostgreSQL.

    Args:
        conn: Database connection (admin)
        username: Monitoring user name
        password: Monitoring user password
        database: Database name

    Returns:
        True if successful, False otherwise
    """
    cursor = conn.cursor()

    try:
        # Read the SQL template
        project_root = get_project_root()
        sql_file = (
            project_root / "db" / "init" / "users" / "005_create_monitoring_user.sql"
        )

        if not sql_file.exists():
            print_error(f"SQL template not found: {sql_file}")
            return False

        sql_content = sql_file.read_text()

        # Substitute placeholders
        sql_content = sql_content.replace("__MONITORING_USER__", username)
        sql_content = sql_content.replace("__MONITORING_PASSWORD__", password)
        sql_content = sql_content.replace("__POSTGRES_DB__", database)

        # Execute the SQL
        cursor.execute(sql_content)
        return True

    except psycopg2.Error as e:
        print_error(f"Failed to create monitoring user: {e}")
        return False


def test_monitoring_user(
    host: str, port: str, database: str, username: str, password: str
) -> dict[str, bool]:
    """Test the monitoring user permissions.

    Args:
        host: Database host
        port: Database port
        database: Database name
        username: Monitoring user name
        password: Monitoring user password

    Returns:
        Dict of test_name -> passed
    """
    results = {}

    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            database=database,
            user=username,
            password=password,
        )
        cursor = conn.cursor()
        results["authentication"] = True

        # Test system tables
        try:
            cursor.execute("SELECT count(*) FROM pg_stat_database;")
            cursor.fetchone()
            results["system_tables"] = True
        except psycopg2.Error:
            results["system_tables"] = False

        # Test recipe_manager tables
        try:
            cursor.execute("SELECT count(*) FROM recipe_manager.recipes;")
            cursor.fetchone()
            results["schema_tables"] = True
        except psycopg2.Error:
            results["schema_tables"] = False

        conn.close()

    except psycopg2.Error:
        results["authentication"] = False

    return results


def update_k8s_secret(
    namespace: str, username: str, password: str, database: str
) -> bool:
    """Update Kubernetes secret with monitoring credentials.

    Args:
        namespace: Kubernetes namespace
        username: Monitoring user name
        password: Monitoring user password
        database: Database name

    Returns:
        True if successful, False otherwise
    """
    dsn = (
        f"postgresql://{username}:{password}@localhost:5432/{database}?sslmode=disable"
    )

    try:
        # Get current secret
        result = subprocess.run(  # nosec B603 B607
            [
                "kubectl",
                "get",
                "secret",
                "recipe-database-secret",
                "-n",
                namespace,
                "-o",
                "json",
            ],
            capture_output=True,
            text=True,
        )

        secret_data: dict[str, dict[str, str]]
        if result.returncode != 0:
            # Secret doesn't exist, create new one
            secret_data = {"data": {}}
        else:
            secret_data = json.loads(result.stdout)

        # Add the DSN to the secret
        dsn_b64 = base64.b64encode(dsn.encode()).decode()
        secret_data["data"]["POSTGRES_EXPORTER_DATA_SOURCE_NAME"] = dsn_b64

        # Apply the updated secret
        apply_result = subprocess.run(  # nosec B603 B607
            ["kubectl", "apply", "-f", "-"],
            input=json.dumps(secret_data),
            capture_output=True,
            text=True,
        )

        if apply_result.returncode != 0:
            print_error(f"Failed to update secret: {apply_result.stderr}")
            return False

        return True

    except Exception as e:
        print_error(f"Kubernetes error: {e}")
        return False


def restart_deployment(namespace: str) -> bool:
    """Restart the deployment to pick up new credentials.

    Args:
        namespace: Kubernetes namespace

    Returns:
        True if successful, False otherwise
    """
    try:
        # Restart the deployment
        result = subprocess.run(  # nosec B603 B607
            [
                "kubectl",
                "rollout",
                "restart",
                "deployment/recipe-database",
                "-n",
                namespace,
            ],
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            print_error(f"Failed to restart deployment: {result.stderr}")
            return False

        # Wait for rollout
        console.print("  [dim]Waiting for rollout to complete...[/]")
        wait_result = subprocess.run(  # nosec B603 B607
            [
                "kubectl",
                "rollout",
                "status",
                "deployment/recipe-database",
                "-n",
                namespace,
                "--timeout=120s",
            ],
            capture_output=True,
            text=True,
        )

        return wait_result.returncode == 0

    except Exception as e:
        print_error(f"Kubernetes error: {e}")
        return False


def main() -> int:
    """Execute monitoring user setup workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Set up PostgreSQL monitoring user",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                          # Create with default settings
  %(prog)s --user my_exporter       # Use custom username
  %(prog)s --skip-k8s               # Skip Kubernetes secret update
  %(prog)s --skip-restart           # Don't restart deployment

This script:
1. Creates a monitoring user in PostgreSQL
2. Grants required permissions for postgres_exporter
3. Updates Kubernetes secret with connection string
4. Optionally restarts the deployment
        """,
    )

    parser.add_argument(
        "--user",
        "-u",
        default="postgres_exporter",
        help="Monitoring user name (default: postgres_exporter)",
    )
    parser.add_argument(
        "--password",
        "-p",
        help="Monitoring user password (default: auto-generated)",
    )
    parser.add_argument(
        "--skip-k8s",
        action="store_true",
        help="Skip Kubernetes secret update",
    )
    parser.add_argument(
        "--skip-restart",
        action="store_true",
        help="Don't restart the deployment",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )

    args = parser.parse_args()

    # Print header
    print_header(
        "📊 Monitoring User Setup",
        "Configure PostgreSQL monitoring for prometheus/grafana",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    # Get or generate password
    monitoring_user = args.user
    monitoring_password = args.password or generate_password()

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    console.print(f"  [bold]Username[/]   [cyan]{monitoring_user}[/]")
    console.print("  [bold]Password[/]   [cyan][auto-generated][/]")
    console.print(f"  [bold]Namespace[/]  [cyan]{NAMESPACE}[/]")
    console.print()

    # Connect to database
    try:
        conn = get_admin_connection()
        host = os.getenv("POSTGRES_HOST", "localhost")
        port = os.getenv("POSTGRES_PORT", "5432")
        database = os.getenv("POSTGRES_DB", "recipe_database")

        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    # Create monitoring user
    console.rule("[bold blue]👤 Creating Monitoring User")
    console.print()

    with console.status("[bold green]Creating user and granting permissions..."):
        if not create_monitoring_user(
            conn, monitoring_user, monitoring_password, database
        ):
            return 1

    print_success(f"Monitoring user '{monitoring_user}' created")
    console.print()

    # Test the monitoring user
    console.rule("[bold blue]🧪 Testing Permissions")
    console.print()

    with console.status("[bold green]Testing monitoring user permissions..."):
        test_results = test_monitoring_user(
            host, port, database, monitoring_user, monitoring_password
        )

    for test_name, passed in test_results.items():
        if passed:
            print_success(f"{test_name.replace('_', ' ').title()}")
        else:
            print_warning(f"{test_name.replace('_', ' ').title()}")
    console.print()

    if not test_results.get("authentication", False):
        print_error("Monitoring user authentication failed")
        return 1

    # Update Kubernetes secret
    if not args.skip_k8s:
        console.rule("[bold blue]☸️  Updating Kubernetes Secret")
        console.print()

        with console.status("[bold green]Updating secret..."):
            if not update_k8s_secret(
                NAMESPACE, monitoring_user, monitoring_password, database
            ):
                print_warning("Failed to update Kubernetes secret")
            else:
                print_success("Kubernetes secret updated")
        console.print()

        # Restart deployment
        if not args.skip_restart:
            console.rule("[bold blue]🔄 Restarting Deployment")
            console.print()

            with console.status("[bold green]Restarting deployment..."):
                if restart_deployment(NAMESPACE):
                    print_success("Deployment restarted")

                    # Wait a bit for exporter to start
                    console.print("  [dim]Waiting for exporter to initialize...[/]")
                    time.sleep(10)
                else:
                    print_warning("Failed to restart deployment")
            console.print()

    # Print summary
    console.rule("[bold blue]📋 Summary")
    console.print()

    print_success(f"Monitoring user created: {monitoring_user}")
    console.print()
    console.print("[bold]Connection Information:[/]")
    console.print(
        f"  [dim]DSN: postgresql://{monitoring_user}:[password]@localhost:5432/{database}?sslmode=disable[/]"
    )
    console.print()
    console.print("[bold]Next Steps:[/]")
    console.print("  1. Check monitoring status:")
    console.print(
        "     [dim]./scripts/containerManagement/get-supporting-services-status.sh[/]"
    )
    console.print("  2. Access metrics:")
    console.print(
        f"     [dim]kubectl port-forward -n {NAMESPACE} svc/postgres-exporter-service 9187:9187[/]"
    )
    console.print("     [dim]curl http://localhost:9187/metrics[/]")
    console.print()

    print_done("Monitoring user setup complete!")

    return 0


if __name__ == "__main__":
    sys.exit(main())
