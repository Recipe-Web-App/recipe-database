# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Backward compatibility re-exports from cli_utils.console.

This module is deprecated. Import from cli_utils.console instead.
"""

# Re-export everything from cli_utils.console for backward compatibility
from cli_utils.console import (  # noqa: F401
    console,
    create_download_progress,
    create_progress,
    get_import_stats_from_db,
    print_bar_chart,
    print_config,
    print_db_connected,
    print_done,
    print_error,
    print_header,
    print_import_summary,
    print_info,
    print_nutrient_coverage,
    print_skip_message,
    print_success,
    print_summary_panel,
    print_table,
    print_top_ingredients_table,
    print_unit_chart,
    print_warning,
)

# Legacy alias for print_import_summary
print_summary = print_import_summary

__all__ = [
    "console",
    "create_download_progress",
    "create_progress",
    "get_import_stats_from_db",
    "print_bar_chart",
    "print_config",
    "print_db_connected",
    "print_done",
    "print_error",
    "print_header",
    "print_import_summary",
    "print_info",
    "print_nutrient_coverage",
    "print_skip_message",
    "print_success",
    "print_summary",
    "print_summary_panel",
    "print_table",
    "print_top_ingredients_table",
    "print_unit_chart",
    "print_warning",
]
