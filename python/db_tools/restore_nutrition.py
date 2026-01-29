#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Restore USDA nutrition data from backup.

This script restores nutrition-related tables from backup files created
by backup_nutrition.py.

Usage:
    python -m db_tools.restore_nutrition
    python -m db_tools.restore_nutrition --list
    python -m db_tools.restore_nutrition --data-only 2025-01-15_10-30-00
"""

import argparse
import gzip
import os
import subprocess  # nosec B404
import sys
import time
from pathlib import Path

from cli_utils.console import (
    console,
    print_done,
    print_error,
    print_header,
    print_success,
    print_warning,
)
from cli_utils.database import get_database_connection, get_table_stats, truncate_tables
from cli_utils.environment import get_config, get_project_root, load_env

# Nutrition tables (order matters for truncation due to FK constraints)
NUTRITION_TABLES = [
    "nutrition_profiles",
    "macronutrients",
    "vitamins",
    "minerals",
]


def get_available_backups(backup_dir: Path) -> list[str]:
    """Get list of available backup dates.

    Args:
        backup_dir: Directory containing backups

    Returns:
        List of backup date strings, sorted newest first
    """
    pattern = "nutrition_data_backup_*.sql.gz"
    files = sorted(
        backup_dir.glob(pattern), key=lambda f: f.stat().st_mtime, reverse=True
    )

    dates = []
    for f in files:
        # Extract date from filename: nutrition_data_backup_YYYY-MM-DD_HH-MM-SS.sql.gz
        name = f.stem.replace(".sql", "")  # Remove .sql (leaving .gz already removed)
        date = name.replace("nutrition_data_backup_", "")
        dates.append(date)

    return dates


def restore_sql_file(sql_file: Path) -> bool:
    """Restore SQL from a gzipped file.

    Args:
        sql_file: Path to .sql.gz file

    Returns:
        True if successful, False otherwise
    """
    config = get_config()

    cmd = [
        "psql",
        "-h",
        config.host,
        "-p",
        config.port,
        "-U",
        config.user,
        "-d",
        config.database,
        "-v",
        "ON_ERROR_STOP=1",
    ]

    env = os.environ.copy()
    env["PGPASSWORD"] = config.password

    try:
        with gzip.open(sql_file, "rt") as f:
            content = f.read()

        subprocess.run(  # nosec B603
            cmd,
            input=content,
            text=True,
            env=env,
            check=True,
            capture_output=True,
        )
        return True

    except subprocess.CalledProcessError as e:
        print_error(f"Restore failed: {e.stderr if e.stderr else e}")
        return False
    except Exception as e:
        print_error(f"Error reading backup file: {e}")
        return False


def main() -> int:
    """Execute nutrition restore workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Restore USDA nutrition data from backup",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                              # Restore latest backup
  %(prog)s --list                       # List available backups
  %(prog)s 2025-01-15_10-30-00          # Restore specific backup
  %(prog)s --data-only                  # Restore data only (tables must exist)
  %(prog)s --schema-only                # Restore schema only (no data)
  %(prog)s --truncate --data-only       # Clear tables before restoring

Tables restored:
  - nutrition_profiles
  - macronutrients
  - vitamins
  - minerals
        """,
    )

    parser.add_argument(
        "backup_date",
        nargs="?",
        help="Backup date to restore (e.g., 2025-01-15_10-30-00)",
    )
    parser.add_argument(
        "--list",
        "-l",
        action="store_true",
        help="List available backups and exit",
    )
    parser.add_argument(
        "--schema-only",
        "-s",
        action="store_true",
        help="Restore only table structure",
    )
    parser.add_argument(
        "--data-only",
        "-d",
        action="store_true",
        help="Restore only data (tables must exist)",
    )
    parser.add_argument(
        "--truncate",
        "-t",
        action="store_true",
        help="Truncate tables before restoring data",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )

    args = parser.parse_args()

    # Validate mutually exclusive options
    if args.schema_only and args.data_only:
        print_error("--schema-only and --data-only cannot be used together")
        return 1

    # Print header
    print_header(
        "🔄 Nutrition Data Restore",
        "Restore USDA nutrition tables from backup",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    # Setup paths
    project_root = get_project_root()
    backup_dir = project_root / "db" / "data" / "backups"
    export_dir = project_root / "db" / "data" / "exports"

    # Handle --list option
    if args.list:
        console.print("[bold]Available backups:[/]")
        console.print()
        backups = get_available_backups(backup_dir)
        if backups:
            for date in backups:
                data_file = backup_dir / f"nutrition_data_backup_{date}.sql.gz"
                size_kb = data_file.stat().st_size / 1024 if data_file.exists() else 0
                console.print(f"  [cyan]{date}[/] ({size_kb:.1f} KB)")
        else:
            console.print("  [dim]No backups found[/]")
        return 0

    # Determine backup date
    backup_date = args.backup_date
    if not backup_date:
        backups = get_available_backups(backup_dir)
        if not backups:
            print_error(f"No backups found in {backup_dir}")
            return 1
        backup_date = backups[0]
        console.print(f"[bold blue]ℹ[/] Using latest backup: [cyan]{backup_date}[/]")
        console.print()

    # Validate backup files exist
    data_file = backup_dir / f"nutrition_data_backup_{backup_date}.sql.gz"
    schema_file = export_dir / f"nutrition_schema_{backup_date}.sql.gz"

    if not args.schema_only and not data_file.exists():
        print_error(f"Data backup file not found: {data_file}")
        console.print()
        console.print("[bold]Available backups:[/]")
        for date in get_available_backups(backup_dir)[:5]:
            console.print(f"  [cyan]{date}[/]")
        return 1

    if not args.data_only and not schema_file.exists():
        print_error(f"Schema backup file not found: {schema_file}")
        return 1

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    try:
        conn = get_database_connection()
        host = conn.info.host or "localhost"
        port = conn.info.port or 5432

        console.print(f"  [bold]Host[/]        [cyan]{host}:{port}[/]")
        console.print(f"  [bold]Database[/]    [cyan]{conn.info.dbname}[/]")
        console.print(f"  [bold]Backup date[/] [cyan]{backup_date}[/]")

        restore_mode = "Schema + Data"
        if args.schema_only:
            restore_mode = "Schema only"
        elif args.data_only:
            restore_mode = "Data only"
        console.print(f"  [bold]Mode[/]        [cyan]{restore_mode}[/]")

        if args.truncate:
            console.print("  [bold]Truncate[/]    [yellow]Yes[/]")
        console.print()

        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    # Start restore
    start_time = time.time()

    try:
        cursor = conn.cursor()

        # Truncate if requested
        if args.truncate:
            console.rule("[bold blue]🗑️  Truncating Tables")
            console.print()

            with console.status("[bold green]Truncating nutrition tables..."):
                # Truncate in reverse order due to FK constraints
                truncate_tables(cursor, list(reversed(NUTRITION_TABLES)))
                conn.commit()

            print_success("Tables truncated")
            console.print()

        # Restore schema if not data-only
        if not args.data_only:
            console.rule("[bold blue]📋 Restoring Schema")
            console.print()

            with console.status("[bold green]Restoring schema..."):
                if not restore_sql_file(schema_file):
                    return 1

            print_success("Schema restored")
            console.print()

        # Restore data if not schema-only
        if not args.schema_only:
            console.rule("[bold blue]💾 Restoring Data")
            console.print()

            size_kb = data_file.stat().st_size / 1024
            console.print(f"  [bold]Backup size[/] [cyan]{size_kb:.1f} KB[/]")
            console.print()

            with console.status("[bold green]Restoring data..."):
                if not restore_sql_file(data_file):
                    return 1

            print_success("Data restored")
            console.print()

        # Show table counts
        console.rule("[bold blue]📊 Verification")
        console.print()

        stats = get_table_stats(cursor, tables=NUTRITION_TABLES)
        for table, count in stats.items():
            console.print(f"  [bold]{table}[/]  [cyan]{count:,}[/] rows")

        conn.close()

    except KeyboardInterrupt:
        console.print()
        print_warning("Restore interrupted by user")
        conn.rollback()
        conn.close()
        return 130

    except Exception as e:
        print_error(f"Restore failed: {e}")
        if args.verbose:
            console.print_exception()
        return 1

    duration = time.time() - start_time
    console.print()
    print_done(f"Restore completed in {duration:.1f}s")

    return 0


if __name__ == "__main__":
    sys.exit(main())
