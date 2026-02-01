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
    """Find .env.local or .env file by searching up from current directory.

    Prefers .env.local over .env for local development overrides.

    Returns:
        Path to env file, or None if not found
    """
    # Base directories to search
    base_dirs = [
        Path.cwd(),
        Path(__file__).parents[2],  # python/../
        Path(__file__).parents[3],  # python/cli_utils/../../../
    ]

    # Try .env.local first, then .env
    for base in base_dirs:
        env_local = base / ".env.local"
        if env_local.exists():
            return env_local
        env_file = base / ".env"
        if env_file.exists():
            return env_file

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


def get_config(admin: bool = False) -> DatabaseConfig:
    """Get database configuration from environment variables.

    Args:
        admin: If True, use POSTGRES_USER/PASSWORD (admin credentials).
               If False, use DB_MAINT_USER/PASSWORD (maintenance credentials).

    Returns:
        DatabaseConfig with values from environment

    Raises:
        ValueError: If required environment variables are missing
    """
    user_var = "POSTGRES_USER" if admin else "DB_MAINT_USER"
    pass_var = "POSTGRES_PASSWORD" if admin else "DB_MAINT_PASSWORD"

    host = os.getenv("POSTGRES_HOST")
    database = os.getenv("POSTGRES_DB")
    user = os.getenv(user_var)
    password = os.getenv(pass_var)

    missing = []
    if not host:
        missing.append("POSTGRES_HOST")
    if not database:
        missing.append("POSTGRES_DB")
    if not user:
        missing.append(user_var)
    if not password:
        missing.append(pass_var)

    if missing:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing)}"
        )

    assert host is not None
    assert database is not None
    assert user is not None
    assert password is not None

    port = os.getenv("NODEPORT_POSTGRES", "") or os.getenv("POSTGRES_PORT", "5432")

    return DatabaseConfig(
        host=host,
        port=port,
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
    data_dir = get_project_root() / "db" / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    return data_dir


def get_backup_dir() -> Path:
    """Get the backup directory.

    Returns:
        Path to backup directory (created if needed)
    """
    backup_dir = get_project_root() / "db" / "data" / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    return backup_dir
