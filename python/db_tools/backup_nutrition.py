#!/usr/bin/env python3
# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Backup USDA nutrition data tables.

This script creates backups of nutrition-related tables with automatic
rotation (keeps last N backups).

Usage:
    python -m db_tools.backup_nutrition
    python -m db_tools.backup_nutrition --keep 10
"""

import argparse
import os
import subprocess  # nosec B404
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
from cli_utils.database import get_database_connection, get_table_stats
from cli_utils.environment import get_config, get_project_root, load_env

# Nutrition tables to backup
NUTRITION_TABLES = [
    "nutrition_profiles",
    "macronutrients",
    "vitamins",
    "minerals",
]


def pg_dump_tables(
    output_file: Path,
    tables: list[str],
    schema: str,
    data_only: bool = False,
    schema_only: bool = False,
) -> bool:
    """Run pg_dump for specific tables.

    Args:
        output_file: Path to output file
        tables: List of table names
        schema: Schema name
        data_only: Export data only
        schema_only: Export schema only

    Returns:
        True if successful, False otherwise
    """
    config = get_config()

    cmd = [
        "pg_dump",
        "-h",
        config.host,
        "-p",
        config.port,
        "-U",
        config.user,
        "-d",
        config.database,
    ]

    for table in tables:
        cmd.extend(["-t", f"{schema}.{table}"])

    if data_only:
        cmd.append("--data-only")
        cmd.append("--column-inserts")
    if schema_only:
        cmd.append("--schema-only")

    env = os.environ.copy()
    env["PGPASSWORD"] = config.password

    try:
        with open(output_file, "w") as f:
            subprocess.run(cmd, stdout=f, env=env, check=True)  # nosec B603
        return True
    except subprocess.CalledProcessError as e:
        print_error(f"pg_dump failed: {e}")
        return False


def compress_file(file_path: Path) -> Path | None:
    """Compress a file with gzip.

    Args:
        file_path: Path to file to compress

    Returns:
        Path to compressed file, or None on failure
    """
    import gzip
    import shutil

    gz_path = file_path.with_suffix(file_path.suffix + ".gz")
    try:
        with open(file_path, "rb") as f_in, gzip.open(gz_path, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)
        file_path.unlink()  # Remove original
        return gz_path
    except Exception as e:
        print_warning(f"Compression failed: {e}")
        return None


def rotate_backups(directory: Path, pattern: str, keep: int) -> int:
    """Delete old backup files, keeping the most recent N.

    Args:
        directory: Directory containing backups
        pattern: Glob pattern for backup files
        keep: Number of backups to keep

    Returns:
        Number of files deleted
    """
    files = sorted(
        directory.glob(pattern), key=lambda f: f.stat().st_mtime, reverse=True
    )
    to_delete = files[keep:]

    for old_file in to_delete:
        old_file.unlink()

    return len(to_delete)


def main() -> int:
    """Execute nutrition backup workflow.

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = argparse.ArgumentParser(
        description="Backup USDA nutrition data tables",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                    # Backup with default rotation (keep 5)
  %(prog)s --keep 10          # Keep last 10 backups
  %(prog)s --no-compress      # Skip compression

Tables backed up:
  - nutrition_profiles
  - macronutrients
  - vitamins
  - minerals
        """,
    )

    parser.add_argument(
        "--keep",
        "-k",
        type=int,
        default=5,
        help="Number of backups to keep (default: 5)",
    )
    parser.add_argument(
        "--no-compress",
        action="store_true",
        help="Skip gzip compression",
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
        "🍎 Nutrition Data Backup",
        "Backup USDA nutrition tables",
    )

    # Load environment
    if not load_env():
        print_warning("No .env file found, using environment variables")

    # Setup paths
    project_root = get_project_root()
    backup_dir = project_root / "db" / "data" / "backups"
    export_dir = project_root / "db" / "data" / "exports"
    backup_dir.mkdir(parents=True, exist_ok=True)
    export_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

    # Print configuration
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    try:
        conn = get_database_connection()
        host = conn.info.host or "localhost"
        port = conn.info.port or 5432

        console.print(f"  [bold]Host[/]        [cyan]{host}:{port}[/]")
        console.print(f"  [bold]Database[/]    [cyan]{conn.info.dbname}[/]")
        console.print(f"  [bold]Backup dir[/]  [cyan]{backup_dir}[/]")
        console.print(f"  [bold]Keep[/]        [cyan]{args.keep} backups[/]")
        console.print()

        print_success(f"Connected to database at {host}:{port}")
        console.print()

    except Exception as e:
        print_error(f"Database connection failed: {e}")
        return 1

    # Get table statistics
    console.rule("[bold blue]📊 Table Statistics")
    console.print()

    try:
        cursor = conn.cursor()
        stats = get_table_stats(cursor, tables=NUTRITION_TABLES)

        for table, count in stats.items():
            console.print(f"  [bold]{table}[/]  [cyan]{count:,}[/] rows")

        # Count ingredients with nutrition data
        cursor.execute("""
            SELECT COUNT(*)
            FROM recipe_manager.ingredients
            WHERE fdc_id IS NOT NULL
        """)
        fdc_count = cursor.fetchone()[0]
        console.print(f"\n  [bold]Ingredients with FDC ID[/]  [cyan]{fdc_count:,}[/]")
        console.print()

        conn.close()

    except Exception as e:
        print_warning(f"Could not get table stats: {e}")
        console.print()

    # Create data backup
    console.rule("[bold blue]💾 Creating Backups")
    console.print()

    config = get_config()
    data_file = backup_dir / f"nutrition_data_backup_{timestamp}.sql"
    schema_file = export_dir / f"nutrition_schema_{timestamp}.sql"

    with console.status("[bold green]Backing up nutrition data..."):
        if not pg_dump_tables(
            data_file, NUTRITION_TABLES, config.schema, data_only=True
        ):
            return 1

    print_success(f"Data backup: {data_file.name}")

    with console.status("[bold green]Exporting nutrition schema..."):
        if not pg_dump_tables(
            schema_file, NUTRITION_TABLES, config.schema, schema_only=True
        ):
            return 1

    print_success(f"Schema export: {schema_file.name}")

    # Compress files
    if not args.no_compress:
        console.print()
        with console.status("[bold green]Compressing files..."):
            data_gz = compress_file(data_file)
            schema_gz = compress_file(schema_file)

        if data_gz:
            size_kb = data_gz.stat().st_size / 1024
            print_success(f"Compressed: {data_gz.name} ({size_kb:.1f} KB)")
        if schema_gz:
            size_kb = schema_gz.stat().st_size / 1024
            print_success(f"Compressed: {schema_gz.name} ({size_kb:.1f} KB)")

    # Rotate old backups
    console.print()
    with console.status(f"[bold green]Rotating backups (keeping {args.keep})..."):
        data_deleted = rotate_backups(
            backup_dir, "nutrition_data_backup_*.sql.gz", args.keep
        )
        schema_deleted = rotate_backups(
            export_dir, "nutrition_schema_*.sql.gz", args.keep
        )

        # Clean up legacy files
        rotate_backups(backup_dir, "nutritional_info_backup_*.sql.gz", 0)
        rotate_backups(export_dir, "nutritional_info_schema_*.sql.gz", 0)

    if data_deleted > 0 or schema_deleted > 0:
        console.print(
            f"  [dim]Removed {data_deleted} old backups, {schema_deleted} old exports[/]"
        )

    # Count remaining
    remaining_backups = len(list(backup_dir.glob("nutrition_data_backup_*.sql.gz")))
    remaining_exports = len(list(export_dir.glob("nutrition_schema_*.sql.gz")))

    console.print()
    print_done(
        f"Backup complete! {remaining_backups} data backups, "
        f"{remaining_exports} schema exports"
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
