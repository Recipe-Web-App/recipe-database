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


def print_stacked_bar_chart(
    data: dict[str, dict[str, int | float]],
    title: str,
    width: int = 60,
) -> None:
    """Print a stacked bar chart.

    Args:
        data: Dict of category -> {label: value}
        title: Chart title
        width: Chart width in characters
    """
    if not data:
        return

    categories = list(data.keys())
    # Get all unique labels across categories
    all_labels: set[str] = set()
    for cat_data in data.values():
        all_labels.update(cat_data.keys())
    labels = sorted(all_labels)

    # Build value lists for each label
    values_per_label = []
    for label in labels:
        values_per_label.append([data[cat].get(label, 0) for cat in categories])

    plt.clear_figure()
    plt.simple_stacked_bar(categories, values_per_label, labels=labels, width=width)
    plt.title(title)
    plt.show()
    console.print()


def print_horizontal_bar_chart(
    data: Mapping[str, int | float],
    title: str,
    max_items: int = 15,
    width: int = 60,
) -> None:
    """Print a horizontal bar chart (good for long labels).

    Args:
        data: Dict of label -> value
        title: Chart title
        max_items: Maximum items to show
        width: Chart width in characters
    """
    if not data:
        return

    sorted_items = sorted(data.items(), key=lambda x: x[1], reverse=True)[:max_items]
    labels = [item[0][:30] for item in sorted_items]  # Truncate long labels
    values = [item[1] for item in sorted_items]

    plt.clear_figure()
    plt.bar(labels, values, orientation="horizontal", width=width)
    plt.title(title)
    plt.show()
    console.print()


def print_multiple_bar_chart(
    labels: list[str],
    datasets: list[tuple[str, list[int | float]]],
    title: str,
    width: int = 60,
) -> None:
    """Print a grouped bar chart comparing multiple datasets.

    Args:
        labels: X-axis labels
        datasets: List of (name, values) tuples
        title: Chart title
        width: Chart width in characters
    """
    if not labels or not datasets:
        return

    plt.clear_figure()
    plt.simple_multiple_bar(
        labels,
        [d[1] for d in datasets],
        labels=[d[0] for d in datasets],
        width=width,
    )
    plt.title(title)
    plt.show()
    console.print()


def print_schema_stats_chart(
    tables: int,
    functions: int,
    triggers: int,
    views: int,
) -> None:
    """Print bar chart of schema objects created."""
    labels = ["Tables", "Functions", "Triggers", "Views"]
    values = [tables, functions, triggers, views]

    plt.clear_figure()
    plt.simple_bar(labels, values, title="Schema Objects", width=50)
    plt.show()
    console.print()


def print_table_rows_chart(
    table_counts: dict[str, int],
    title: str = "Table Row Counts",
    max_tables: int = 15,
) -> None:
    """Print horizontal bar chart of table row counts.

    Args:
        table_counts: Dict of table_name -> row_count
        title: Chart title
        max_tables: Maximum tables to show
    """
    if not table_counts:
        return

    # Filter out empty tables and sort by count
    non_empty = {k: v for k, v in table_counts.items() if v > 0}
    if not non_empty:
        console.print("[dim]No data in tables[/]")
        return

    sorted_items = sorted(non_empty.items(), key=lambda x: x[1], reverse=True)[
        :max_tables
    ]
    labels = [item[0] for item in sorted_items]
    values = [item[1] for item in sorted_items]

    plt.clear_figure()
    plt.bar(labels, values, orientation="horizontal", width=60)
    plt.title(title)
    plt.show()
    console.print()


def print_backup_size_chart(
    table_sizes: dict[str, float],
    title: str = "Table Sizes (MB)",
    max_tables: int = 10,
) -> None:
    """Print bar chart of table sizes for backup.

    Args:
        table_sizes: Dict of table_name -> size_mb
        title: Chart title
        max_tables: Maximum tables to show
    """
    if not table_sizes:
        return

    sorted_items = sorted(table_sizes.items(), key=lambda x: x[1], reverse=True)[
        :max_tables
    ]
    labels = [item[0] for item in sorted_items]
    values = [item[1] for item in sorted_items]

    plt.clear_figure()
    plt.bar(labels, values, orientation="horizontal", width=60)
    plt.title(title)
    plt.show()
    console.print()


def get_all_table_stats(cursor: Any, schema: str = "recipe_manager") -> dict[str, int]:
    """Get row counts for all tables in schema.

    Args:
        cursor: Database cursor
        schema: Schema name

    Returns:
        Dict of table_name -> row_count
    """
    cursor.execute(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = %s
          AND table_type = 'BASE TABLE'
        ORDER BY table_name
        """,
        (schema,),
    )
    table_names = [row[0] for row in cursor.fetchall()]

    stats = {}
    for table in table_names:
        cursor.execute(f"SELECT COUNT(*) FROM {schema}.{table}")  # nosec B608
        stats[table] = cursor.fetchone()[0]

    return stats


def get_table_sizes(cursor: Any, schema: str = "recipe_manager") -> dict[str, float]:
    """Get table sizes in MB.

    Args:
        cursor: Database cursor
        schema: Schema name

    Returns:
        Dict of table_name -> size_mb
    """
    cursor.execute(
        """
        SELECT
            tablename,
            pg_total_relation_size(schemaname || '.' || tablename) / 1024.0 / 1024.0 as size_mb
        FROM pg_tables
        WHERE schemaname = %s
        ORDER BY size_mb DESC
        """,
        (schema,),
    )
    return {row[0]: float(row[1]) for row in cursor.fetchall()}


# =============================================================================
# Nutrition-specific helpers (for backward compatibility)
# =============================================================================


def print_import_summary(
    foods_imported: int,
    foods_skipped: int,
    portions_imported: int,
    portions_skipped: int,
    duration: float,
    allergen_profiles: int = 0,
    food_groups: int = 0,
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

    if allergen_profiles > 0:
        summary_lines.append(
            f"  [bold]Allergen profiles[/]    [cyan]{allergen_profiles:,}[/]"
        )

    if food_groups > 0:
        summary_lines.append(
            f"  [bold]Food groups[/]          [cyan]{food_groups:,}[/]"
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


def print_allergen_chart(
    allergen_counts: dict[str, int],
    total_profiles: int,
    total_allergens: int,
) -> None:
    """Print bar chart of allergen distribution.

    Args:
        allergen_counts: Dict mapping allergen type to count
        total_profiles: Total number of allergen profiles
        total_allergens: Total number of ingredient allergen entries
    """
    if not allergen_counts:
        return

    # Take top 10 allergens
    top_allergens = dict(list(allergen_counts.items())[:10])

    plt.clear_figure()
    plt.simple_bar(
        list(top_allergens.keys()),
        list(top_allergens.values()),
        title=f"Allergens Detected ({total_profiles:,} profiles, {total_allergens:,} entries)",
        width=60,
    )
    plt.show()
    console.print()


def print_food_group_chart(
    food_group_counts: dict[str, int],
    total_with_groups: int,
) -> None:
    """Print bar chart of food group distribution.

    Args:
        food_group_counts: Dict mapping food group to count
        total_with_groups: Total number of foods with assigned food groups
    """
    if not food_group_counts:
        return

    plt.clear_figure()
    plt.simple_bar(
        list(food_group_counts.keys()),
        list(food_group_counts.values()),
        title=f"Food Groups ({total_with_groups:,} assigned)",
        width=60,
    )
    plt.show()
    console.print()


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

    # Get allergen statistics
    cursor.execute("""
        SELECT ia.allergen_type, COUNT(*) as count
        FROM recipe_manager.ingredient_allergens ia
        GROUP BY ia.allergen_type
        ORDER BY count DESC
    """)
    stats["allergen_counts"] = {row[0]: row[1] for row in cursor.fetchall()}

    cursor.execute("SELECT COUNT(*) FROM recipe_manager.allergen_profiles")
    stats["total_allergen_profiles"] = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM recipe_manager.ingredient_allergens")
    stats["total_ingredient_allergens"] = cursor.fetchone()[0]

    # Get food group statistics
    cursor.execute("""
        SELECT food_group::text, COUNT(*) as count
        FROM recipe_manager.nutrition_profiles
        WHERE food_group IS NOT NULL
        GROUP BY food_group
        ORDER BY count DESC
    """)
    stats["food_group_counts"] = {row[0]: row[1] for row in cursor.fetchall()}

    cursor.execute("""
        SELECT COUNT(*)
        FROM recipe_manager.nutrition_profiles
        WHERE food_group IS NOT NULL AND food_group != 'UNKNOWN'
    """)
    stats["total_with_food_groups"] = cursor.fetchone()[0]

    return stats


def print_pricing_import_summary(
    food_groups_seeded: int,
    ingredients_imported: int,
    ingredients_skipped: int,
    duration: float,
    errors: list[str] | None = None,
) -> None:
    """Print pricing import summary panel.

    Args:
        food_groups_seeded: Number of food group prices seeded
        ingredients_imported: Number of ingredient prices imported
        ingredients_skipped: Number of items skipped (no match)
        duration: Import duration in seconds
        errors: Optional list of error messages
    """
    success = errors is None or len(errors) == 0

    print_summary_panel(
        {
            "Food groups seeded": food_groups_seeded,
            "Ingredients priced": ingredients_imported,
            "Skipped (no match)": ingredients_skipped,
            "Duration": f"{duration:.1f}s",
        },
        title="Pricing Import Summary",
        success=success,
    )

    if errors:
        console.print()
        console.print("[bold yellow]Errors:[/]")
        for error in errors[:10]:
            console.print(f"  [dim]• {error}[/]")
        if len(errors) > 10:
            console.print(f"  [dim]... and {len(errors) - 10} more[/]")


def print_pricing_coverage_chart(
    by_source: dict[str, int],
    total_ingredients: int,
) -> None:
    """Print bar chart showing pricing coverage by data source.

    Args:
        by_source: Dict mapping data source to count
        total_ingredients: Total number of ingredients in database
    """
    if not by_source:
        return

    total_priced = sum(by_source.values())
    coverage_pct = (
        (total_priced / total_ingredients * 100) if total_ingredients > 0 else 0
    )

    plt.clear_figure()
    plt.simple_bar(
        list(by_source.keys()),
        list(by_source.values()),
        title=f"Pricing by Source ({total_priced:,} priced, {coverage_pct:.1f}% coverage)",
        width=60,
    )
    plt.show()
    console.print()


def print_price_distribution_chart(
    price_buckets: dict[str, int],
) -> None:
    """Print histogram showing price distribution across ingredients.

    Args:
        price_buckets: Dict mapping price range labels to counts
                       e.g., {"$0-0.50": 45, "$0.50-1": 30, ...}
    """
    if not price_buckets:
        return

    total = sum(price_buckets.values())

    plt.clear_figure()
    plt.simple_bar(
        list(price_buckets.keys()),
        list(price_buckets.values()),
        title=f"Price Distribution per 100g ({total:,} ingredients)",
        width=60,
    )
    plt.show()
    console.print()


def print_food_group_price_chart(
    by_food_group: dict[str, float],
) -> None:
    """Print bar chart showing average price by food group.

    Args:
        by_food_group: Dict mapping food group to average price per 100g
    """
    if not by_food_group:
        return

    # Sort by price for visual clarity
    sorted_groups = dict(
        sorted(by_food_group.items(), key=lambda x: x[1], reverse=True)
    )

    plt.clear_figure()
    plt.simple_bar(
        list(sorted_groups.keys()),
        list(sorted_groups.values()),
        title="Average Price per 100g by Food Group",
        width=60,
    )
    plt.show()
    console.print()


def get_pricing_stats_from_db(cursor: Any) -> dict[str, Any]:
    """Query database for pricing statistics to display in charts.

    Args:
        cursor: Database cursor

    Returns:
        Dict with pricing coverage, distribution, and food group stats
    """
    stats: dict[str, Any] = {}

    # Get total ingredients
    cursor.execute("SELECT COUNT(*) FROM recipe_manager.ingredients")
    stats["total_ingredients"] = cursor.fetchone()[0]

    # Get pricing counts by source
    cursor.execute("""
        SELECT data_source, COUNT(*) as count
        FROM recipe_manager.ingredient_pricing
        GROUP BY data_source
        ORDER BY count DESC
    """)
    stats["by_source"] = {row[0]: row[1] for row in cursor.fetchall()}

    # Get price distribution (buckets)
    cursor.execute("""
        SELECT
            CASE
                WHEN price_per_100g < 0.25 THEN '$0-0.25'
                WHEN price_per_100g < 0.50 THEN '$0.25-0.50'
                WHEN price_per_100g < 1.00 THEN '$0.50-1.00'
                WHEN price_per_100g < 2.00 THEN '$1.00-2.00'
                WHEN price_per_100g < 5.00 THEN '$2.00-5.00'
                ELSE '$5.00+'
            END as bucket,
            COUNT(*) as count
        FROM recipe_manager.ingredient_pricing
        GROUP BY bucket
        ORDER BY MIN(price_per_100g)
    """)
    stats["price_distribution"] = {row[0]: row[1] for row in cursor.fetchall()}

    # Get average price by food group (from the lookup view)
    cursor.execute("""
        SELECT
            COALESCE(food_group::text, 'UNKNOWN') as fg,
            AVG(price_per_100g) as avg_price
        FROM recipe_manager.vw_ingredient_pricing_lookup
        WHERE price_per_100g IS NOT NULL
        GROUP BY food_group
        ORDER BY avg_price DESC
    """)
    stats["by_food_group"] = {row[0]: float(row[1]) for row in cursor.fetchall()}

    # Get food group pricing counts
    cursor.execute("SELECT COUNT(*) FROM recipe_manager.food_group_pricing")
    stats["food_group_count"] = cursor.fetchone()[0]

    return stats
