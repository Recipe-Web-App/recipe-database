# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Rich console utilities for enhanced terminal output.

Provides styled output, progress bars, tables, and charts for CLI tools.
"""

from collections.abc import Mapping
from typing import Any

import plotext as plt
from rich.console import Console
from rich.panel import Panel
from rich.progress import (
    BarColumn,
    DownloadColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TaskProgressColumn,
    TextColumn,
    TimeElapsedColumn,
    TransferSpeedColumn,
)
from rich.table import Table

# Shared console instance
console = Console()


def print_header(title: str, subtitle: str | None = None) -> None:
    """Print a styled application header.

    Args:
        title: Main header title
        subtitle: Optional subtitle text (dimmed)
    """
    console.print()
    content = f"[bold cyan]{title}[/]"
    if subtitle:
        content += f"\n[dim]{subtitle}[/]"
    console.print(Panel.fit(content, border_style="cyan"))
    console.print()


def print_config(items: dict[str, str], title: str = "Config") -> None:
    """Print a configuration panel.

    Args:
        items: Dict of label -> value pairs
        title: Panel title
    """
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    max_label_len = max(len(k) for k in items.keys())
    config_lines = [
        f"  [bold]{label.ljust(max_label_len)}[/]  [cyan]{value}[/]"
        for label, value in items.items()
    ]

    console.print(Panel("\n".join(config_lines), title=title, border_style="blue"))
    console.print()


def print_db_connected(host: str, port: str) -> None:
    """Print database connection success."""
    console.print(f"[bold green]✓[/] Connected to [cyan]{host}:{port}[/]")
    console.print()


def create_progress() -> Progress:
    """Create a configured progress bar context."""
    return Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        MofNCompleteColumn(),
        TimeElapsedColumn(),
        console=console,
        expand=False,
    )


def create_download_progress() -> Progress:
    """Create a progress bar configured for downloads."""
    return Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        DownloadColumn(),
        TransferSpeedColumn(),
        TimeElapsedColumn(),
        console=console,
        expand=False,
    )


def print_skip_message(count: int, reason: str) -> None:
    """Print a dimmed skip message."""
    console.print(f"  [dim]↳ Skipped {count:,} ({reason})[/]")


def print_success(message: str) -> None:
    """Print a success message with checkmark."""
    console.print(f"[bold green]✓[/] {message}")


def print_error(message: str) -> None:
    """Print an error message with X."""
    console.print(f"[bold red]✗[/] {message}")


def print_warning(message: str) -> None:
    """Print a warning message."""
    console.print(f"[bold yellow]![/] {message}")


def print_info(message: str) -> None:
    """Print an info message."""
    console.print(f"[bold blue]ℹ[/] {message}")


def print_done(message: str) -> None:
    """Print completion message with rule."""
    console.rule(style="dim")
    console.print(f"[bold green]✓[/] {message}")
    console.print()


def print_summary_panel(
    items: dict[str, str | int],
    title: str = "Summary",
    success: bool = True,
) -> None:
    """Print a summary panel with key-value pairs.

    Args:
        items: Dict of label -> value pairs
        title: Panel title
        success: Whether to show success (green) or warning (yellow) styling
    """
    console.print()
    console.rule("[bold blue]📊 Summary")
    console.print()

    max_label_len = max(len(k) for k in items.keys())
    summary_lines = [""]
    for label, value in items.items():
        if isinstance(value, int):
            value_str = f"[cyan]{value:,}[/]"
        else:
            value_str = f"[cyan]{value}[/]"
        summary_lines.append(f"  [bold]{label.ljust(max_label_len)}[/]  {value_str}")
    summary_lines.append("")

    border_style = "green" if success else "yellow"
    icon = "✅" if success else "⚠️"
    full_title = f"[bold {'green' if success else 'yellow'}]{icon} {title}[/]"

    console.print(
        Panel("\n".join(summary_lines), title=full_title, border_style=border_style)
    )
    console.print()


def print_table(
    rows: list[tuple[Any, ...]],
    columns: list[tuple[str, str]],
    title: str | None = None,
) -> None:
    """Print a formatted table.

    Args:
        rows: List of row tuples
        columns: List of (header, style) tuples
        title: Optional table title
    """
    if not rows:
        return

    table = Table(title=title, show_header=True)
    for header, style in columns:
        table.add_column(header, style=style)

    for row in rows:
        table.add_row(*[str(v) for v in row])

    console.print(table)
    console.print()


def print_bar_chart(
    data: Mapping[str, int | float],
    title: str,
    max_items: int = 10,
    width: int = 60,
) -> None:
    """Print a terminal bar chart.

    Args:
        data: Dict of label -> value
        title: Chart title
        max_items: Maximum items to show
        width: Chart width in characters
    """
    if not data:
        return

    sorted_items = sorted(data.items(), key=lambda x: x[1], reverse=True)[:max_items]
    labels = [item[0] for item in sorted_items]
    values = [item[1] for item in sorted_items]

    plt.clear_figure()
    plt.simple_bar(labels, values, title=title, width=width)
    plt.show()
    console.print()


# =============================================================================
# Nutrition-specific helpers (for backward compatibility)
# =============================================================================


def print_import_summary(
    foods_imported: int,
    foods_skipped: int,
    portions_imported: int,
    portions_skipped: int,
    duration: float,
    errors: list[str] | None = None,
) -> None:
    """Print nutrition import summary panel."""
    console.print()
    console.rule("[bold blue]📊 Summary")
    console.print()

    summary_lines = [
        "",
        f"  [bold]Foods imported[/]       [cyan]{foods_imported:,}[/]",
    ]

    if foods_skipped > 0:
        summary_lines.append(
            f"  [bold]Foods skipped[/]        [dim]{foods_skipped:,}[/] "
            "[dim](incomplete data)[/]"
        )

    summary_lines.append(
        f"  [bold]Portions imported[/]    [cyan]{portions_imported:,}[/]"
    )

    if portions_skipped > 0:
        summary_lines.append(
            f"  [bold]Portions skipped[/]     [dim]{portions_skipped:,}[/]"
        )

    summary_lines.append(f"  [bold]Duration[/]             [cyan]{duration:.1f}s[/]")
    summary_lines.append("")

    border_style = "green" if not errors else "yellow"
    title = (
        "[bold green]✅ Import Complete"
        if not errors
        else "[bold yellow]⚠️ Import Complete with Warnings"
    )

    console.print(
        Panel("\n".join(summary_lines), title=title, border_style=border_style)
    )

    if errors and len(errors) > 0:
        console.print()
        console.print(f"[bold yellow]Warnings ({len(errors)}):[/]")
        for error in errors[:5]:
            console.print(f"  [dim]• {error}[/]")
        if len(errors) > 5:
            console.print(f"  [dim]... and {len(errors) - 5} more[/]")

    console.print()


def print_unit_chart(unit_counts: dict[str, int]) -> None:
    """Print bar chart of portions by unit type."""
    print_bar_chart(unit_counts, "Portions by Unit")


def print_nutrient_coverage(
    total_foods: int,
    with_macros: int,
    with_vitamins: int,
    with_minerals: int,
) -> None:
    """Print bar chart of nutrient coverage."""
    labels = ["Macros", "Vitamins", "Minerals"]
    values = [with_macros, with_vitamins, with_minerals]
    percentages = [
        f"{(v / total_foods * 100):.0f}%" if total_foods > 0 else "0%" for v in values
    ]

    plt.clear_figure()
    plt.simple_bar(
        [f"{label} ({pct})" for label, pct in zip(labels, percentages)],
        values,
        title="Nutrient Coverage",
        width=60,
    )
    plt.show()
    console.print()


def print_top_ingredients_table(ingredients: list[tuple[str, int]]) -> None:
    """Print table of top ingredients by portion count."""
    print_table(
        rows=ingredients[:10],
        columns=[("Ingredient", "white"), ("Portions", "cyan")],
        title="Top Ingredients by Portions",
    )


def get_import_stats_from_db(cursor: Any) -> dict[str, Any]:
    """Query database for import statistics to display in charts.

    Args:
        cursor: Database cursor

    Returns:
        Dict with unit_counts, nutrient_coverage, top_ingredients
    """
    stats: dict[str, Any] = {}

    # Get portion counts by unit
    cursor.execute("""
        SELECT unit, COUNT(*) as count
        FROM recipe_manager.ingredient_portions
        GROUP BY unit
        ORDER BY count DESC
    """)
    stats["unit_counts"] = {row[0]: row[1] for row in cursor.fetchall()}

    # Get total foods
    cursor.execute("SELECT COUNT(*) FROM recipe_manager.ingredients")
    total = cursor.fetchone()[0]
    stats["total_foods"] = total

    # Get nutrient coverage (foods with non-null macros/vitamins/minerals)
    cursor.execute("""
        SELECT COUNT(DISTINCT np.ingredient_id)
        FROM recipe_manager.nutrition_profiles np
        JOIN recipe_manager.macronutrients m ON m.nutrition_profile_id = np.nutrition_profile_id
        WHERE m.calories_kcal IS NOT NULL
    """)
    stats["with_macros"] = cursor.fetchone()[0]

    cursor.execute("""
        SELECT COUNT(DISTINCT np.ingredient_id)
        FROM recipe_manager.nutrition_profiles np
        JOIN recipe_manager.vitamins v ON v.nutrition_profile_id = np.nutrition_profile_id
        WHERE v.vitamin_a_mcg IS NOT NULL OR v.vitamin_c_mcg IS NOT NULL
    """)
    stats["with_vitamins"] = cursor.fetchone()[0]

    cursor.execute("""
        SELECT COUNT(DISTINCT np.ingredient_id)
        FROM recipe_manager.nutrition_profiles np
        JOIN recipe_manager.minerals m ON m.nutrition_profile_id = np.nutrition_profile_id
        WHERE m.calcium_mg IS NOT NULL OR m.iron_mg IS NOT NULL
    """)
    stats["with_minerals"] = cursor.fetchone()[0]

    # Get top ingredients by portion count
    cursor.execute("""
        SELECT i.name, COUNT(ip.id) as portion_count
        FROM recipe_manager.ingredients i
        JOIN recipe_manager.ingredient_portions ip ON ip.ingredient_id = i.ingredient_id
        GROUP BY i.ingredient_id, i.name
        ORDER BY portion_count DESC
        LIMIT 10
    """)
    stats["top_ingredients"] = [(row[0], row[1]) for row in cursor.fetchall()]

    return stats
