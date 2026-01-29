#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Create full database backup.

This script creates a compressed backup of the entire recipe_manager schema
using pg_dump.

Usage:
    python -m db_tools.backup_db
    python -m db_tools.backup_db --output /path/to/backup.sql.gz
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path

from cli_utils.console import (
    console,
    print_done,
    print_error,
    print_header,
    print_success,
    print_warning,
)
from cli_utils.database import get_database_connection, pg_dump
from cli_utils.environment import get_backup_dir, load_env


def main() -> int:
    """Execute database backup workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Create full database backup",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                                    # Backup to default location
  %(prog)s --output /path/to/backup.sql.gz   # Specify output file

Default output: backups/recipe_backup_YYYY-MM-DD_HH-MM-SS.sql.gz
        """,
    )

    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="Output file path (default: auto-generated in backups/)",
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
        "💾 Database Backup",
        "Full database backup with compression",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    # Determine output path
    if args.output:
        backup_file = args.output
        backup_file.parent.mkdir(parents=True, exist_ok=True)
    else:
        backup_dir = get_backup_dir()
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        backup_file = backup_dir / f"recipe_backup_{timestamp}.sql.gz"

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    try:
        conn = get_database_connection()
        host = conn.info.host or "localhost"
        port = conn.info.port or 5432

        console.print(f"  [bold]Host[/]      [cyan]{host}:{port}[/]")
        console.print(f"  [bold]Database[/]  [cyan]{conn.info.dbname}[/]")
        console.print(f"  [bold]Output[/]    [cyan]{backup_file}[/]")
        console.print()

        conn.close()
        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    # Create backup
    console.rule("[bold blue]📦 Creating Backup")
    console.print()

    with console.status("[bold green]Running pg_dump..."):
        success = pg_dump(
            output_file=backup_file,
            compress=True,
        )

    if success:
        size_mb = backup_file.stat().st_size / (1024 * 1024)
        print_success(f"Backup created: {backup_file.name} ({size_mb:.2f} MB)")
        console.print()
        print_done("Database backup completed successfully!")
        return 0
    else:
        print_error("Backup failed")
        if backup_file.exists():
            backup_file.unlink()
        return 1


if __name__ == "__main__":
    sys.exit(main())
