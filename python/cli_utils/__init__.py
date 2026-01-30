# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Shared CLI utilities for database and Kubernetes tools.

This package provides common functionality used across CLI tools:
- console: Rich terminal output (progress bars, panels, tables)
- database: Database connections, SQL execution, pg_dump wrappers
- environment: .env loading and configuration management
"""

from cli_utils.console import console, create_progress, print_error, print_header
from cli_utils.database import execute_sql_file, get_database_connection, pg_dump
from cli_utils.environment import get_config, load_env

__all__ = [
    # Console
    "console",
    "create_progress",
    "print_error",
    "print_header",
    # Database
    "execute_sql_file",
    "get_database_connection",
    "pg_dump",
    # Environment
    "get_config",
    "load_env",
]
