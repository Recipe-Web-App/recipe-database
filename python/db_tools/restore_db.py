#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Restore database from backup.

This script restores the database from a pg_dump backup file.

The restore process:
1. Creates required database roles (runs user setup SQL)
2. Drops existing schema if present
3. Restores from backup file

Usage:
    python -m db_tools.restore_db
    python -m db_tools.restore_db --list
    python -m db_tools.restore_db 2026-01-29_18-57-31
"""

import argparse
import gzip
import os
import subprocess  # nosec B404
import sys
from pathlib import Path

from cli_utils.console import (
    console,
    print_done,
    print_error,
    print_header,
    print_info,
    print_success,
    print_warning,
)
from cli_utils.database import execute_sql_file, get_database_connection
from cli_utils.environment import get_backup_dir, get_config, get_project_root, load_env
from rich.markup import escape


def get_available_backups(backup_dir: Path) -> list[str]:
    """Get list of available backup dates.

    Args:
        backup_dir: Directory containing backups

    Returns:
        List of backup dates (sorted, newest first)
    """
    pattern = "recipe_backup_*.sql.gz"
    backups = list(backup_dir.glob(pattern))

    # Also check for uncompressed backups
    backups.extend(backup_dir.glob("recipe_backup_*.sql"))

    # Extract dates from filenames
    dates = set()
    for backup in backups:
        # Format: recipe_backup_YYYY-MM-DD_HH-MM-SS.sql[.gz]
        name = backup.stem
        if name.endswith(".sql"):
            name = name[:-4]  # Remove .sql from .sql.gz case
        date = name.replace("recipe_backup_", "")
        dates.add(date)

    return sorted(dates, reverse=True)


def find_backup_file(backup_dir: Path, date: str) -> Path | None:
    """Find backup file for a given date.

    Args:
        backup_dir: Directory containing backups
        date: Backup date string

    Returns:
        Path to backup file, or None if not found
    """
    # Try compressed first
    gz_file = backup_dir / f"recipe_backup_{date}.sql.gz"
    if gz_file.exists():
        return gz_file

    # Try uncompressed
    sql_file = backup_dir / f"recipe_backup_{date}.sql"
    if sql_file.exists():
        return sql_file

    return None


def prepare_for_restore(admin: bool = False, verbose: bool = False) -> bool:
    """Prepare database for restore by creating roles and dropping schema.

    Args:
        admin: Use admin credentials
        verbose: Print verbose output

    Returns:
        True if successful, False otherwise
    """
    try:
        conn = get_database_connection(admin=admin)
        cursor = conn.cursor()

        # Step 1: Create required roles by running user setup SQL files
        project_root = get_project_root()
        users_dir = project_root / "db" / "init" / "users"

        if users_dir.exists():
            sql_files = sorted(users_dir.glob("*.sql"))
            for sql_file in sql_files:
                try:
                    execute_sql_file(cursor, sql_file, verbose=verbose)
                except Exception as e:
                    # Role may already exist, that's OK
                    if "already exists" not in str(e) and verbose:
                        console.print(f"  [dim]Note: {sql_file.name}: {e}[/]")
                    conn.rollback()
                else:
                    conn.commit()

        # Step 2: Drop existing schema if present
        cursor.execute("DROP SCHEMA IF EXISTS recipe_manager CASCADE;")
        conn.commit()

        conn.close()
        return True

    except Exception as e:
        print_error(f"Failed to prepare database: {e}")
        return False


def restore_backup(backup_file: Path, admin: bool = False) -> bool:
    """Restore database from backup file.

    Args:
        backup_file: Path to backup file (.sql or .sql.gz)
        admin: Use admin credentials

    Returns:
        True if successful, False otherwise
    """
    config = get_config(admin=admin)
    is_gzipped = backup_file.suffix == ".gz"

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
        if is_gzipped:
            with gzip.open(backup_file, "rt") as f:
                content = f.read()
            subprocess.run(  # nosec B603
                cmd,
                input=content,
                text=True,
                env=env,
                check=True,
                capture_output=True,
            )
        else:
            cmd.extend(["-f", str(backup_file)])
            subprocess.run(cmd, env=env, check=True, capture_output=True)  # nosec B603

        return True

    except subprocess.CalledProcessError as e:
        error_msg = e.stderr if isinstance(e.stderr, str) else e.stderr.decode()
        print_error(f"Restore failed: {error_msg}")
        return False


def main() -> int:
    """Execute database restore workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Restore database from backup",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                              # Restore latest backup
  %(prog)s --list                       # List available backups
  %(prog)s 2026-01-29_18-57-31          # Restore specific backup

Backup files are stored in: backups/
        """,
    )

    parser.add_argument(
        "backup_date",
        nargs="?",
        help="Backup date to restore (e.g., 2026-01-29_18-57-31)",
    )
    parser.add_argument(
        "--admin",
        action="store_true",
        help="Use admin credentials (required for full restore)",
    )
    parser.add_argument(
        "--list",
        "-l",
        action="store_true",
        help="List available backups and exit",
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
        "🔄 Database Restore",
        "Restore database from backup",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    # Get backup directory
    backup_dir = get_backup_dir()

    # List available backups
    available = get_available_backups(backup_dir)

    if args.list:
        console.print()
        if not available:
            print_warning(f"No backups found in {backup_dir}")
        else:
            console.print(f"[bold]Available backups in {backup_dir}:[/]")
            console.print()
            for date in available:
                backup_file = find_backup_file(backup_dir, date)
                if backup_file:
                    size_mb = backup_file.stat().st_size / (1024 * 1024)
                    console.print(f"  {escape(date)}  [dim]({size_mb:.2f} MB)[/]")
        return 0

    # Determine which backup to restore
    if args.backup_date:
        backup_date = args.backup_date
        if backup_date not in available:
            print_error(f"Backup not found: {backup_date}")
            console.print()
            console.print("Available backups:")
            for date in available[:5]:
                console.print(f"  {date}")
            return 1
    else:
        if not available:
            print_error(f"No backups found in {backup_dir}")
            return 1
        backup_date = available[0]
        print_info(f"Using latest backup: {backup_date}")

    backup_file = find_backup_file(backup_dir, backup_date)
    if not backup_file:
        print_error(f"Backup file not found for date: {backup_date}")
        return 1

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    try:
        conn = get_database_connection(admin=args.admin)
        host = conn.info.host or "localhost"
        port = conn.info.port or 5432

        console.print(f"  [bold]Host[/]        [cyan]{host}:{port}[/]")
        console.print(f"  [bold]Database[/]    [cyan]{conn.info.dbname}[/]")
        console.print(f"  [bold]Backup[/]      [cyan]{escape(backup_file.name)}[/]")
        console.print()

        conn.close()
        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    # Prepare database for restore
    console.rule("[bold blue]🔧 Preparing Database")
    console.print()

    with console.status("[bold green]Creating roles and clearing schema..."):
        if not prepare_for_restore(admin=args.admin, verbose=args.verbose):
            return 1

    print_success("Database prepared for restore")
    console.print()

    # Restore backup
    console.rule("[bold blue]💾 Restoring Backup")
    console.print()

    size_mb = backup_file.stat().st_size / (1024 * 1024)
    console.print(f"  Backup size [cyan]{size_mb:.2f} MB[/]")
    console.print()

    with console.status("[bold green]Restoring database..."):
        success = restore_backup(backup_file, admin=args.admin)

    if success:
        console.print()
        print_done("Database restored successfully!")
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
