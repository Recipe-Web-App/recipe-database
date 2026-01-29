# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Environment and configuration loading utilities.

Provides standardized .env loading and configuration management for CLI tools.
"""

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


@dataclass
class DatabaseConfig:
    """Database connection configuration."""

    host: str
    port: str
    database: str
    user: str
    password: str
    schema: str = "recipe_manager"

    @property
    def connection_string(self) -> str:
        """Return psycopg2-style connection string."""
        return (
            f"host={self.host} port={self.port} dbname={self.database} "
            f"user={self.user} password={self.password}"
        )

    @property
    def dsn(self) -> str:
        """Return DSN-style connection string."""
        return (
            f"postgresql://{self.user}:{self.password}@"
            f"{self.host}:{self.port}/{self.database}"
        )


def find_env_file() -> Path | None:
    """Find .env file by searching up from current directory.

    Returns:
        Path to .env file, or None if not found
    """
    # Try common locations
    search_paths = [
        Path.cwd() / ".env",
        Path(__file__).parents[2] / ".env",  # python/../.env
        Path(__file__).parents[3] / ".env",  # python/cli_utils/../../../.env
    ]

    for path in search_paths:
        if path.exists():
            return path

    return None


def load_env(env_file: Path | None = None) -> bool:
    """Load environment variables from .env file.

    Args:
        env_file: Path to .env file. If None, searches automatically.

    Returns:
        True if .env file was loaded, False otherwise
    """
    if env_file is None:
        env_file = find_env_file()

    if env_file and env_file.exists():
        load_dotenv(env_file)
        return True

    return False


def get_config() -> DatabaseConfig:
    """Get database configuration from environment variables.

    Returns:
        DatabaseConfig with values from environment

    Raises:
        ValueError: If required environment variables are missing
    """
    missing = []

    host = os.getenv("POSTGRES_HOST")
    if not host:
        missing.append("POSTGRES_HOST")

    database = os.getenv("POSTGRES_DB")
    if not database:
        missing.append("POSTGRES_DB")

    user = os.getenv("DB_MAINT_USER")
    if not user:
        missing.append("DB_MAINT_USER")

    password = os.getenv("DB_MAINT_PASSWORD")
    if not password:
        missing.append("DB_MAINT_PASSWORD")

    if missing:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing)}"
        )

    # Type assertions after validation (mypy doesn't narrow from the if-check)
    assert host is not None
    assert database is not None
    assert user is not None
    assert password is not None

    return DatabaseConfig(
        host=host,
        port=os.getenv("POSTGRES_PORT", "5432"),
        database=database,
        user=user,
        password=password,
        schema=os.getenv("POSTGRES_SCHEMA", "recipe_manager"),
    )


def get_project_root() -> Path:
    """Get the project root directory.

    Returns:
        Path to project root (directory containing .env or python/)
    """
    # Try to find .env as marker
    env_file = find_env_file()
    if env_file:
        return env_file.parent

    # Fall back to parent of python directory
    return Path(__file__).parents[2]


def get_data_dir() -> Path:
    """Get the data directory for temporary files.

    Returns:
        Path to data directory (created if needed)
    """
    data_dir = get_project_root() / "data"
    data_dir.mkdir(exist_ok=True)
    return data_dir


def get_backup_dir() -> Path:
    """Get the backup directory.

    Returns:
        Path to backup directory (created if needed)
    """
    backup_dir = get_project_root() / "backups"
    backup_dir.mkdir(exist_ok=True)
    return backup_dir
