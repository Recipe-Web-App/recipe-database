#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Load database schema from SQL files.

This script executes SQL files from the db/init directories in order:
1. Schema definitions (tables, types, extensions)
2. Functions
3. Triggers
4. Views
5. Users and permissions

Usage:
    python -m db_tools.load_schema
    python -m db_tools.load_schema --verbose
    python -m db_tools.load_schema --admin  # Use admin credentials
"""

import argparse
import os
import sys
from pathlib import Path

from cli_utils.console import (
    console,
    create_progress,
    print_done,
    print_error,
    print_header,
    print_success,
    print_warning,
)
from cli_utils.database import execute_sql_file, get_database_connection
from cli_utils.environment import get_project_root, load_env


def get_admin_connection():
    """Get database connection using admin credentials.

    Returns:
        PostgreSQL connection object

    Raises:
        psycopg2.Error: If connection fails
        ValueError: If required environment variables are missing
    """
    import psycopg2

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
    conn.autocommit = False

    return conn


def execute_sql_directory(
    cursor,
    directory: Path,
    label: str,
    verbose: bool = False,
) -> tuple[int, int, list[str]]:
    """Execute all SQL files in a directory.

    Args:
        cursor: Database cursor
        directory: Path to directory containing SQL files
        label: Label for progress display
        verbose: Whether to print each file name

    Returns:
        Tuple of (success_count, failure_count, error_messages)
    """
    if not directory.exists():
        if verbose:
            console.print(f"  [dim]Directory not found: {directory}[/]")
        return 0, 0, []

    sql_files = sorted(directory.glob("*.sql"))

    if not sql_files:
        if verbose:
            console.print(f"  [dim]No SQL files in {directory.name}/[/]")
        return 0, 0, []

    success = 0
    failure = 0
    errors = []

    with create_progress() as progress:
        task = progress.add_task(f"[cyan]{label}", total=len(sql_files))

        for sql_file in sql_files:
            try:
                execute_sql_file(cursor, sql_file, verbose=verbose)
                success += 1
            except Exception as e:
                failure += 1
                error_msg = f"{sql_file.name}: {e}"
                errors.append(error_msg)
                if verbose:
                    console.print(f"  [red]✗[/] {sql_file.name}: {e}")
            finally:
                progress.advance(task)

    return success, failure, errors


def main() -> int:
    """Execute schema loading workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Load database schema from SQL files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                    # Load schema using maintenance user
  %(prog)s --admin            # Load schema using admin user
  %(prog)s --verbose          # Show each file being executed

SQL directories processed (in order):
  db/init/schema/     - Table definitions
  db/init/functions/  - Stored functions
  db/init/triggers/   - Trigger definitions
  db/init/views/      - View definitions
  db/init/users/      - User and permission setup
        """,
    )

    parser.add_argument(
        "--admin",
        action="store_true",
        help="Use admin credentials (POSTGRES_USER) instead of maintenance user",
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
        "📦 Database Schema Loader",
        "Execute SQL initialization files",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    # Define SQL directories
    project_root = get_project_root()
    sql_base = project_root / "db" / "init"

    directories = [
        (sql_base / "schema", "Loading schema"),
        (sql_base / "functions", "Loading functions"),
        (sql_base / "triggers", "Creating triggers"),
        (sql_base / "views", "Creating views"),
        (sql_base / "users", "Setting up users"),
    ]

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    try:
        if args.admin:
            conn = get_admin_connection()
            user = os.getenv("POSTGRES_USER", "admin")
        else:
            conn = get_database_connection()
            user = os.getenv("DB_MAINT_USER", "maintenance")

        host = conn.info.host or "localhost"
        port = conn.info.port or 5432

        console.print(f"  [bold]Host[/]      [cyan]{host}:{port}[/]")
        console.print(f"  [bold]Database[/]  [cyan]{conn.info.dbname}[/]")
        console.print(f"  [bold]User[/]      [cyan]{user}[/]")
        console.print()

        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    # Execute SQL directories
    console.rule("[bold blue]📄 Executing SQL Files")
    console.print()

    total_success = 0
    total_failure = 0
    all_errors = []

    try:
        cursor = conn.cursor()

        for directory, label in directories:
            success, failure, errors = execute_sql_directory(
                cursor, directory, label, verbose=args.verbose
            )
            total_success += success
            total_failure += failure
            all_errors.extend(errors)

            if failure == 0 and success > 0:
                print_success(f"{label}: {success} files")
            elif failure > 0:
                print_warning(f"{label}: {success} OK, {failure} failed")

        # Commit all changes
        conn.commit()
        console.print()

    except Exception as e:
        conn.rollback()
        print_error(f"Schema loading failed: {e}")
        if args.verbose:
            console.print_exception()
        return 1
    finally:
        conn.close()

    # Print summary
    console.rule("[bold blue]📊 Summary")
    console.print()

    if total_failure == 0:
        print_done(f"Schema loaded successfully! {total_success} files executed.")
        return 0
    else:
        print_warning(
            f"Schema loaded with errors: {total_success} OK, {total_failure} failed"
        )
        if all_errors:
            console.print()
            console.print("[bold yellow]Errors:[/]")
            for error in all_errors[:10]:
                console.print(f"  [dim]• {error}[/]")
            if len(all_errors) > 10:
                console.print(f"  [dim]... and {len(all_errors) - 10} more[/]")
        return 1


if __name__ == "__main__":
    sys.exit(main())
