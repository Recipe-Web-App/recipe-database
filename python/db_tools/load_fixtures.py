#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Load test fixtures into database.

This script executes SQL fixture files from db/fixtures/ directory
to populate the database with test data.

Usage:
    python -m db_tools.load_fixtures
    python -m db_tools.load_fixtures --verbose
    python -m db_tools.load_fixtures --pattern "001_*"
"""

import argparse
import fnmatch
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


def load_fixtures(
    cursor,
    fixtures_dir: Path,
    pattern: str | None = None,
    verbose: bool = False,
) -> tuple[int, int, list[str]]:
    """Load fixture files from directory.

    Args:
        cursor: Database cursor
        fixtures_dir: Path to fixtures directory
        pattern: Optional glob pattern to filter files
        verbose: Whether to print each file name

    Returns:
        Tuple of (success_count, failure_count, error_messages)
    """
    if not fixtures_dir.exists():
        print_warning(f"Fixtures directory not found: {fixtures_dir}")
        return 0, 0, []

    sql_files = sorted(fixtures_dir.glob("*.sql"))

    # Filter by pattern if specified
    if pattern:
        sql_files = [f for f in sql_files if fnmatch.fnmatch(f.name, pattern)]

    if not sql_files:
        msg = "No fixture files found"
        if pattern:
            msg += f" matching '{pattern}'"
        print_warning(msg)
        return 0, 0, []

    success = 0
    failure = 0
    errors = []

    console.print(f"[bold blue]📁[/] Loading {len(sql_files)} fixture files...")
    console.print()

    with create_progress() as progress:
        task = progress.add_task("[cyan]Loading fixtures", total=len(sql_files))

        for sql_file in sql_files:
            try:
                execute_sql_file(cursor, sql_file, verbose=verbose)
                success += 1
                if verbose:
                    console.print(f"  [green]✓[/] {sql_file.name}")
            except Exception as e:
                failure += 1
                error_msg = f"{sql_file.name}: {e}"
                errors.append(error_msg)
                console.print(f"  [red]✗[/] {sql_file.name}")
                if verbose:
                    console.print(f"    [dim]{e}[/]")
            finally:
                progress.advance(task)

    return success, failure, errors


def main() -> int:
    """Execute fixture loading workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Load test fixtures into database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                         # Load all fixtures
  %(prog)s --verbose               # Show each file being loaded
  %(prog)s --pattern "001_*"       # Load only files matching pattern
  %(prog)s --pattern "*users*"     # Load only user-related fixtures

Fixtures are loaded from: db/fixtures/
Files are processed in alphabetical order (numeric prefixes recommended).
        """,
    )

    parser.add_argument(
        "--pattern",
        "-p",
        help="Glob pattern to filter fixture files (e.g., '001_*', '*users*')",
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
        "🧪 Test Fixture Loader",
        "Seed database with test data",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    # Get fixtures directory
    project_root = get_project_root()
    fixtures_dir = project_root / "db" / "fixtures"

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    try:
        conn = get_database_connection()
        host = conn.info.host or "localhost"
        port = conn.info.port or 5432

        console.print(f"  [bold]Host[/]       [cyan]{host}:{port}[/]")
        console.print(f"  [bold]Database[/]   [cyan]{conn.info.dbname}[/]")
        console.print(f"  [bold]Fixtures[/]   [cyan]{fixtures_dir}[/]")
        if args.pattern:
            console.print(f"  [bold]Pattern[/]    [cyan]{args.pattern}[/]")
        console.print()

        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    # Load fixtures
    console.rule("[bold blue]📄 Loading Fixtures")
    console.print()

    try:
        cursor = conn.cursor()

        success, failure, errors = load_fixtures(
            cursor,
            fixtures_dir,
            pattern=args.pattern,
            verbose=args.verbose,
        )

        if success > 0:
            conn.commit()
        console.print()

    except Exception as e:
        conn.rollback()
        print_error(f"Fixture loading failed: {e}")
        if args.verbose:
            console.print_exception()
        return 1
    finally:
        conn.close()

    # Print summary
    if success == 0 and failure == 0:
        print_warning("No fixtures were loaded")
        return 0

    if failure == 0:
        print_done(f"Fixtures loaded successfully! {success} files executed.")
        return 0
    else:
        print_warning(f"Fixtures loaded with errors: {success} OK, {failure} failed")
        if errors:
            console.print()
            console.print("[bold yellow]Errors:[/]")
            for error in errors[:10]:
                console.print(f"  [dim]• {error}[/]")
            if len(errors) > 10:
                console.print(f"  [dim]... and {len(errors) - 10} more[/]")
        return 1


if __name__ == "__main__":
    sys.exit(main())
