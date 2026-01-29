# Ingredient Portions Database Schema

This document describes the database schema for storing ingredient portion
weights and the process for importing data from USDA FoodData Central.

## Overview

The `ingredient_portions` table stores portion weight data that enables
conversion from volume and count units to grams. This data is sourced from the
USDA FoodData Central Food Weights dataset.

## Database Schema

### Table: `ingredient_portions`

```sql
CREATE TABLE ingredient_portions (
    id BIGSERIAL PRIMARY KEY,
    ingredient_id BIGINT NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
    portion_description VARCHAR(255) NOT NULL,  -- e.g., "1 cup, chopped", "1 medium"
    unit VARCHAR(50) NOT NULL,                   -- e.g., "CUP", "PIECE", "TBSP"
    modifier VARCHAR(100),                       -- e.g., "chopped", "sliced", "medium"
    gram_weight DECIMAL(10,3) NOT NULL,          -- Weight in grams
    sequence_number INT,                         -- USDA sequence for ordering
    data_source VARCHAR(50) DEFAULT 'USDA',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(ingredient_id, portion_description)
);

-- Indexes for efficient lookups
CREATE INDEX idx_ingredient_portions_ingredient_id ON ingredient_portions(ingredient_id);
CREATE INDEX idx_ingredient_portions_unit ON ingredient_portions(unit);
CREATE INDEX idx_ingredient_portions_ingredient_unit ON ingredient_portions(ingredient_id, unit);
```

### Column Descriptions

| Column                | Type          | Description                                                              |
| --------------------- | ------------- | ------------------------------------------------------------------------ |
| `id`                  | BIGSERIAL     | Primary key                                                              |
| `ingredient_id`       | BIGINT        | Foreign key to `ingredients` table                                       |
| `portion_description` | VARCHAR(255)  | Full USDA portion description (e.g., "1 cup, chopped")                   |
| `unit`                | VARCHAR(50)   | Normalized unit type matching `IngredientUnit` enum values               |
| `modifier`            | VARCHAR(100)  | Optional modifier extracted from description (e.g., "chopped", "medium") |
| `gram_weight`         | DECIMAL(10,3) | Weight in grams for one unit of this portion                             |
| `sequence_number`     | INT           | USDA sequence number for ordering multiple portions                      |
| `data_source`         | VARCHAR(50)   | Data source identifier (default: "USDA")                                 |
| `created_at`          | TIMESTAMP     | Record creation timestamp                                                |
| `updated_at`          | TIMESTAMP     | Record update timestamp                                                  |

## Data Source: USDA FoodData Central

### Download Links

The primary data source is the USDA FoodData Central **Foundation Foods**
dataset:

- **Main Page**: <https://fdc.nal.usda.gov/download-datasets/>
- **Foundation Foods (Recommended)**: Contains ~2,800 foods with detailed
  portion weights
- **SR Legacy**: Contains ~7,000 foods (older dataset, still useful)

### Files Required

Download the CSV version of the dataset. You'll need these files:

1. **`food.csv`** - Food descriptions and FDC IDs
2. **`food_portion.csv`** - Portion weights (this is the key file)
3. **`measure_unit.csv`** - Unit descriptions

### File Format: `food_portion.csv`

| Column                | Description               | Example          |
| --------------------- | ------------------------- | ---------------- |
| `id`                  | Portion ID                | 123456           |
| `fdc_id`              | Food Data Central ID      | 171705           |
| `seq_num`             | Sequence number           | 1                |
| `amount`              | Amount of units           | 1                |
| `measure_unit_id`     | Reference to measure_unit | 1001             |
| `portion_description` | Description               | "1 cup, chopped" |
| `modifier`            | Modifier text             | "chopped"        |
| `gram_weight`         | Weight in grams           | 160.0            |

## Import Process

### Step 1: Map FDC IDs to Ingredients

The `ingredients` table should have an `fdc_id` column that matches USDA FDC
IDs:

```sql
-- Verify ingredients have fdc_id populated
SELECT COUNT(*) FROM ingredients WHERE fdc_id IS NOT NULL;
```

### Step 2: Parse and Transform Portion Data

Create an import script that:

1. Reads `food_portion.csv`
2. Filters to portions where `fdc_id` matches an ingredient in your database
3. Normalizes the `unit` field to match `IngredientUnit` enum values
4. Inserts into `ingredient_portions`

### Step 3: Unit Normalization

Map USDA portion descriptions to your `IngredientUnit` enum:

| USDA Pattern                                 | IngredientUnit |
| -------------------------------------------- | -------------- |
| "cup" (in description)                       | CUP            |
| "tablespoon", "tbsp"                         | TBSP           |
| "teaspoon", "tsp"                            | TSP            |
| "ml", "milliliter"                           | ML             |
| "liter", "l"                                 | L              |
| "g", "gram"                                  | G              |
| "kg", "kilogram"                             | KG             |
| "oz", "ounce"                                | OZ             |
| "lb", "pound"                                | LB             |
| "slice"                                      | SLICE          |
| "clove"                                      | CLOVE          |
| "piece", "whole", "medium", "large", "small" | PIECE          |

### Example Import Query

```sql
-- Example: Import portions for a specific ingredient
INSERT INTO ingredient_portions (
    ingredient_id,
    portion_description,
    unit,
    modifier,
    gram_weight,
    sequence_number,
    data_source
)
SELECT
    i.id,
    fp.portion_description,
    -- Map to IngredientUnit (simplified example)
    CASE
        WHEN fp.portion_description ILIKE '%cup%' THEN 'CUP'
        WHEN fp.portion_description ILIKE '%tablespoon%' OR fp.portion_description ILIKE '%tbsp%' THEN 'TBSP'
        WHEN fp.portion_description ILIKE '%teaspoon%' OR fp.portion_description ILIKE '%tsp%' THEN 'TSP'
        WHEN fp.portion_description ILIKE '%slice%' THEN 'SLICE'
        WHEN fp.portion_description ILIKE '%clove%' THEN 'CLOVE'
        ELSE 'PIECE'
    END,
    fp.modifier,
    fp.gram_weight,
    fp.seq_num,
    'USDA'
FROM usda_food_portion fp  -- Staging table with raw USDA data
JOIN ingredients i ON i.fdc_id = fp.fdc_id
ON CONFLICT (ingredient_id, portion_description)
DO UPDATE SET
    gram_weight = EXCLUDED.gram_weight,
    updated_at = NOW();
```

## Example Data

After import, the table should contain data like:

| ingredient_id | portion_description | unit  | modifier | gram_weight |
| ------------- | ------------------- | ----- | -------- | ----------- |
| 1 (apple)     | 1 medium (3" dia)   | PIECE | medium   | 182.0       |
| 1 (apple)     | 1 cup, sliced       | CUP   | sliced   | 109.0       |
| 2 (flour)     | 1 cup               | CUP   | NULL     | 125.0       |
| 3 (egg)       | 1 large             | PIECE | large    | 50.0        |
| 4 (onion)     | 1 cup, chopped      | CUP   | chopped  | 160.0       |
| 4 (onion)     | 1 medium            | PIECE | medium   | 110.0       |
| 5 (garlic)    | 1 clove             | CLOVE | NULL     | 3.0         |

## Usage in NutritionService

The `NutritionRepository.get_portion_weight()` method queries this table:

```python
async def get_portion_weight(
    self,
    ingredient_name: str,
    unit: str,
    modifier: str | None = None,
) -> Decimal | None:
    """Look up gram weight for a portion measurement."""
```

The `UnitConverter` uses this for:

- **Volume-to-grams**: "1 cup flour" -> looks up CUP for flour -> 125g
- **Count-to-grams**: "1 medium apple" -> looks up PIECE for apple -> 182g

## Fallback Behavior

When a portion weight is not found in the database:

1. **Volume units**: Converts to milliliters using Pint, then applies 1 g/ml
   (water density)
2. **Count units**: Uses 100g per unit as a safe default

Both fallbacks are logged as warnings to identify missing data for future
imports.

## Additional Data Sources

For more comprehensive coverage, consider these supplementary sources:

### FAO/INFOODS Density Database

- **URL**: <https://www.fao.org/infoods/infoods/tables-and-databases/>
- **Use case**: Ingredient densities (g/ml) for volume-to-weight conversions
- **Format**: Excel spreadsheets

### Aquaculture Feed Database (AFCD)

- **URL**: <https://www.fao.org/fishery/en/collection/afcd>
- **Use case**: Additional food composition data

## Maintenance

### Adding New Portions

When new ingredients are added without USDA coverage:

1. Look up the ingredient in USDA FoodData Central web interface
2. If found, note the FDC ID and update the ingredient record
3. Re-run the portion import for that FDC ID

### Manual Additions

For ingredients not in USDA, add manual entries:

```sql
INSERT INTO ingredient_portions (
    ingredient_id,
    portion_description,
    unit,
    modifier,
    gram_weight,
    data_source
)
SELECT
    id,
    '1 cup',
    'CUP',
    NULL,
    <measured_weight>,
    'MANUAL'
FROM ingredients
WHERE name = '<ingredient_name>';
```
