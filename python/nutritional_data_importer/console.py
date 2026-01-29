# Recipe Database - PostgreSQL database for recipe management
# Copyright (c) 2024 Your Name <your.email@example.com>
#
# Licensed under the MIT License. See LICENSE file for details.

"""Rich console utilities for enhanced terminal output.

Provides styled output, progress bars, tables, and charts for the
USDA FoodData Central importer.
"""

from typing import Any

import plotext as plt
from rich.console import Console
from rich.panel import Panel
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TaskProgressColumn,
    TextColumn,
    TimeElapsedColumn,
)
from rich.table import Table

# Shared console instance
console = Console()


def print_header() -> None:
    """Print the application header."""
    console.print()
    console.print(
        Panel.fit(
            "[bold cyan]🍎 USDA FoodData Central Importer[/]\n"
            "[dim]Nutritional data import from USDA FoodData Central[/]",
            border_style="cyan",
        )
    )
    console.print()


def print_config(
    data_dir: str,
    host: str,
    port: str,
    database: str,
    schema: str,
) -> None:
    """Print configuration panel."""
    console.rule("[bold blue]⚙️  Configuration")
    console.print()

    config_text = (
        f"  [bold]Dataset[/]     [cyan]{data_dir}[/]\n"
        f"  [bold]Database[/]    [cyan]{host}:{port}[/]\n"
        f"  [bold]Schema[/]      [cyan]{schema}[/]\n"
        f"  [bold]DB Name[/]     [cyan]{database}[/]"
    )

    console.print(Panel(config_text, title="Config", border_style="blue"))
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


def print_skip_message(count: int, reason: str) -> None:
    """Print a dimmed skip message."""
    console.print(f"  [dim]↳ Skipped {count:,} ({reason})[/]")


def print_summary(
    foods_imported: int,
    foods_skipped: int,
    portions_imported: int,
    portions_skipped: int,
    duration: float,
    errors: list[str] | None = None,
) -> None:
    """Print import summary panel."""
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
    if not unit_counts:
        return

    # Sort by count descending, take top 10
    sorted_units = sorted(unit_counts.items(), key=lambda x: x[1], reverse=True)[:10]
    labels = [u[0] for u in sorted_units]
    values = [u[1] for u in sorted_units]

    plt.clear_figure()
    plt.simple_bar(labels, values, title="Portions by Unit", width=60)
    plt.show()
    console.print()


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
    if not ingredients:
        return

    table = Table(title="Top Ingredients by Portions", show_header=True)
    table.add_column("Ingredient", style="white")
    table.add_column("Portions", justify="right", style="cyan")

    for name, count in ingredients[:10]:
        table.add_row(name, str(count))

    console.print(table)
    console.print()


def print_done(schema: str) -> None:
    """Print completion message."""
    console.rule(style="dim")
    console.print(f"[bold green]✓[/] All done! Data ready in [cyan]{schema}[/] schema.")
    console.print()


def print_error(message: str) -> None:
    """Print an error message."""
    console.print(f"[bold red]✗[/] {message}")


def print_warning(message: str) -> None:
    """Print a warning message."""
    console.print(f"[bold yellow]![/] {message}")


def print_info(message: str) -> None:
    """Print an info message."""
    console.print(f"[bold blue]ℹ[/] {message}")


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
