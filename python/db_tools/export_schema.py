#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Export database schema.

This script exports the schema definition (no data) using pg_dump.

Usage:
    python -m db_tools.export_schema
    python -m db_tools.export_schema --output /path/to/schema.sql
"""

import argparse
import sys
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
from cli_utils.environment import get_project_root, load_env


def main() -> int:
    """Execute schema export workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Export database schema",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                            # Export to default location
  %(prog)s --output /path/to/schema.sql

Default output: db/data/exports/schema.sql
        """,
    )

    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="Output file path (default: db/data/exports/schema.sql)",
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
        "📋 Schema Export",
        "Export database schema definition",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    # Determine output path
    if args.output:
        output_file = args.output
    else:
        project_root = get_project_root()
        output_dir = project_root / "db" / "data" / "exports"
        output_dir.mkdir(parents=True, exist_ok=True)
        output_file = output_dir / "schema.sql"

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    try:
        conn = get_database_connection()
        host = conn.info.host or "localhost"
        port = conn.info.port or 5432

        console.print(f"  [bold]Host[/]      [cyan]{host}:{port}[/]")
        console.print(f"  [bold]Database[/]  [cyan]{conn.info.dbname}[/]")
        console.print(f"  [bold]Output[/]    [cyan]{output_file}[/]")
        console.print()

        conn.close()
        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    # Export schema
    console.rule("[bold blue]📄 Exporting Schema")
    console.print()

    with console.status("[bold green]Running pg_dump --schema-only..."):
        success = pg_dump(
            output_file=output_file,
            schema_only=True,
        )

    if success:
        size_kb = output_file.stat().st_size / 1024
        print_success(f"Schema exported: {output_file} ({size_kb:.1f} KB)")
        console.print()
        print_done("Schema export completed successfully!")
        return 0
    else:
        print_error("Schema export failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
