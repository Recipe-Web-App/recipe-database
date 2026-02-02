# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Database utilities for CLI tools.

Provides database connections, SQL file execution, and pg_dump wrappers.
"""

import gzip
import os
import subprocess  # nosec B404
from pathlib import Path
from typing import Any

import psycopg2
from cli_utils.console import console, print_error
from cli_utils.environment import get_config
from psycopg2.extensions import connection as PgConnection


def get_database_connection(admin: bool = False) -> PgConnection:
    """Get a database connection using environment configuration.

    Args:
        admin: If True, use admin credentials (POSTGRES_USER/PASSWORD).
               If False, use maintenance credentials (DB_MAINT_USER/PASSWORD).

    Returns:
        PostgreSQL connection object

    Raises:
        psycopg2.Error: If connection fails
        ValueError: If required environment variables are missing
    """
    config = get_config(admin=admin)

    conn = psycopg2.connect(
        host=config.host,
        port=config.port,
        database=config.database,
        user=config.user,
        password=config.password,
    )
    conn.autocommit = False

    # Set search path to schema (include public for extensions like pg_trgm)
    with conn.cursor() as cursor:
        cursor.execute(f"SET search_path TO {config.schema}, public;")
    conn.commit()

    return conn


def execute_sql_file(
    cursor: Any,
    sql_file: Path,
    verbose: bool = False,
    use_envsubst: bool = True,
) -> None:
    """Execute a SQL file.

    Args:
        cursor: Database cursor
        sql_file: Path to SQL file
        verbose: Whether to print file name before execution
        use_envsubst: Whether to process environment variable substitution

    Raises:
        Exception: If SQL execution fails
    """
    if verbose:
        console.print(f"  [dim]Executing {sql_file.name}...[/]")

    content = sql_file.read_text()

    # Process environment variable substitution if needed
    # Check for $VAR or ${VAR} patterns
    if use_envsubst and ("${" in content or "$" in content):
        # Use envsubst for variable substitution
        result = subprocess.run(  # nosec B603 B607
            ["envsubst"],
            input=content,
            capture_output=True,
            text=True,
            check=True,
        )
        content = result.stdout

    cursor.execute(content)


def get_table_stats(
    cursor: Any,
    schema: str = "recipe_manager",
    tables: list[str] | None = None,
) -> dict[str, int]:
    """Get row counts for tables in schema.

    Args:
        cursor: Database cursor
        schema: Schema name
        tables: Specific tables to count (None = all tables)

    Returns:
        Dict of table_name -> row_count
    """
    if tables:
        table_filter = "AND table_name = ANY(%s)"
        params: tuple[str, ...] | tuple[str, list[str]] = (schema, tables)
    else:
        table_filter = ""
        params = (schema,)

    cursor.execute(
        f"""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = %s
          AND table_type = 'BASE TABLE'
          {table_filter}
        ORDER BY table_name
        """,  # nosec B608
        params,
    )
    table_names = [row[0] for row in cursor.fetchall()]

    stats = {}
    for table in table_names:
        cursor.execute(f"SELECT COUNT(*) FROM {schema}.{table}")  # nosec B608
        stats[table] = cursor.fetchone()[0]

    return stats


def pg_dump(
    output_file: Path,
    schema_only: bool = False,
    data_only: bool = False,
    tables: list[str] | None = None,
    schema: str = "recipe_manager",
    compress: bool = False,
) -> bool:
    """Run pg_dump with environment-based connection.

    Args:
        output_file: Path to output file
        schema_only: Export schema only (no data)
        data_only: Export data only (no schema)
        tables: Specific tables to dump (None = all tables in schema)
        schema: Schema to dump
        compress: Whether to gzip the output

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
        "-n",
        schema,
    ]

    if schema_only:
        cmd.append("--schema-only")
    if data_only:
        cmd.append("--data-only")

    if tables:
        for table in tables:
            cmd.extend(["-t", f"{schema}.{table}"])

    env = os.environ.copy()
    env["PGPASSWORD"] = config.password

    try:
        if compress:
            # Pipe through gzip
            result = subprocess.run(  # nosec B603
                cmd,
                capture_output=True,
                env=env,
                check=True,
            )
            with gzip.open(output_file, "wb") as f:
                f.write(result.stdout)
        else:
            with open(output_file, "w") as f:
                subprocess.run(cmd, stdout=f, env=env, check=True)  # nosec B603

        return True

    except subprocess.CalledProcessError as e:
        print_error(f"pg_dump failed: {e.stderr.decode() if e.stderr else str(e)}")
        return False


def pg_restore(
    input_file: Path,
    schema: str = "recipe_manager",
    data_only: bool = False,
    clean: bool = False,
) -> bool:
    """Restore from a pg_dump file.

    Args:
        input_file: Path to dump file (supports .gz)
        schema: Target schema
        data_only: Restore data only
        clean: Drop objects before restoring

    Returns:
        True if successful, False otherwise
    """
    config = get_config()

    # Determine if file is gzipped
    is_gzipped = input_file.suffix == ".gz"

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
            with gzip.open(input_file, "rt") as f:
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
            cmd.extend(["-f", str(input_file)])
            subprocess.run(cmd, env=env, check=True, capture_output=True)  # nosec B603

        return True

    except subprocess.CalledProcessError as e:
        print_error(f"Restore failed: {e.stderr.decode() if e.stderr else str(e)}")
        return False


def truncate_tables(
    cursor: Any, tables: list[str], schema: str = "recipe_manager"
) -> None:
    """Truncate tables with CASCADE.

    Args:
        cursor: Database cursor
        tables: List of table names
        schema: Schema name
    """
    for table in tables:
        cursor.execute(f"TRUNCATE TABLE {schema}.{table} CASCADE")  # nosec B608
