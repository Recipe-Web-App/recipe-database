-- db/init/schema/017_create_nutritional_info_table.sql
-- OpenFoodFacts nutritional information table (simplified for API schema)

-- Set the schema
SET search_path TO recipe_manager;

-- Create the nutritional_info table for OpenFoodFacts data
CREATE TABLE IF NOT EXISTS nutritional_info (
  -- Primary key and identifiers
  nutritional_info_id BIGSERIAL PRIMARY KEY,
  code VARCHAR(255) NOT NULL UNIQUE, -- OpenFoodFacts barcode/code

  -- Basic product information
  product_name TEXT,
  generic_name TEXT,
  brands TEXT,
  categories TEXT,
  serving_quantity DECIMAL(8, 3),
  serving_measurement recipe_manager.INGREDIENT_UNIT_ENUM,

  -- Allergens and classification (for classification)
  allergens recipe_manager.ALLERGEN_ENUM [],
  food_groups recipe_manager.FOOD_GROUP_ENUM,

  -- Classification scores
  nutriscore_score INTEGER,
  nutriscore_grade VARCHAR(5),

  -- MacroNutrients (per 100g from CSV)
  energy_kcal_100g DECIMAL(8, 3),
  carbohydrates_100g DECIMAL(8, 3),
  cholesterol_100g DECIMAL(8, 3),
  proteins_100g DECIMAL(8, 3),

  -- Sugars
  sugars_100g DECIMAL(8, 3),
  added_sugars_100g DECIMAL(8, 3),

  -- Fats  
  fat_100g DECIMAL(8, 3),
  saturated_fat_100g DECIMAL(8, 3),
  monounsaturated_fat_100g DECIMAL(8, 3),
  polyunsaturated_fat_100g DECIMAL(8, 3),
  omega_3_fat_100g DECIMAL(8, 3),
  omega_6_fat_100g DECIMAL(8, 3),
  omega_9_fat_100g DECIMAL(8, 3),
  trans_fat_100g DECIMAL(8, 3),

  -- Fibers
  fiber_100g DECIMAL(8, 3),
  soluble_fiber_100g DECIMAL(8, 3),
  insoluble_fiber_100g DECIMAL(8, 3),

  -- Vitamins (from CSV names)
  vitamin_a_100g DECIMAL(10, 6),
  vitamin_b6_100g DECIMAL(10, 6),
  vitamin_b12_100g DECIMAL(10, 6),
  vitamin_c_100g DECIMAL(10, 6),
  vitamin_d_100g DECIMAL(10, 6),
  vitamin_e_100g DECIMAL(10, 6),
  vitamin_k_100g DECIMAL(10, 6),

  -- Minerals (from CSV names)
  calcium_100g DECIMAL(10, 6),
  iron_100g DECIMAL(10, 6),
  magnesium_100g DECIMAL(10, 6),
  potassium_100g DECIMAL(10, 6),
  sodium_100g DECIMAL(10, 6),
  zinc_100g DECIMAL(10, 6),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add trigger for updated_at timestamp
CREATE TRIGGER nutritional_info_updated_at
BEFORE UPDATE ON nutritional_info
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Add comments for documentation
COMMENT ON TABLE nutritional_info
IS 'Nutritional information from OpenFoodFacts database, '
'structured to match CSV column names for direct import';

-- Primary identifiers
COMMENT ON COLUMN nutritional_info.nutritional_info_id
IS 'Auto-generated primary key';
COMMENT ON COLUMN nutritional_info.code
IS 'OpenFoodFacts barcode/product code (unique identifier from CSV)';

-- Basic product information
COMMENT ON COLUMN nutritional_info.product_name
IS 'Product name from OpenFoodFacts CSV';
COMMENT ON COLUMN nutritional_info.generic_name
IS 'Generic product name from OpenFoodFacts CSV '
' (more standardized than product_name)';
COMMENT ON COLUMN nutritional_info.brands
IS 'Comma-separated brand names from CSV';
COMMENT ON COLUMN nutritional_info.categories
IS 'Comma-separated product categories from CSV';
COMMENT ON COLUMN nutritional_info.serving_quantity
IS 'Serving quantity (amount) parsed from serving_size CSV field';
COMMENT ON COLUMN nutritional_info.serving_measurement
IS 'Standardized serving unit enum, parsed from serving_size CSV field';

-- Classification data
COMMENT ON COLUMN nutritional_info.allergens
IS 'Array of standardized allergen enum values (parsed from CSV)';
COMMENT ON COLUMN nutritional_info.food_groups
IS 'Standardized food group enum (mapped from OpenFoodFacts CSV taxonomy)';
COMMENT ON COLUMN nutritional_info.nutriscore_score
IS 'Nutri-Score numeric value from CSV (typically 1-5)';
COMMENT ON COLUMN nutritional_info.nutriscore_grade
IS 'Nutri-Score letter grade from CSV (A, B, C, D, or E)';

-- Macronutrients (per 100g)
COMMENT ON COLUMN nutritional_info.energy_kcal_100g
IS 'Energy content in kcal per 100g from CSV';
COMMENT ON COLUMN nutritional_info.carbohydrates_100g
IS 'Carbohydrate content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.cholesterol_100g
IS 'Cholesterol content in mg per 100g from CSV';
COMMENT ON COLUMN nutritional_info.proteins_100g
IS 'Protein content in grams per 100g from CSV';

-- Sugars
COMMENT ON COLUMN nutritional_info.sugars_100g
IS 'Total sugar content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.added_sugars_100g
IS 'Added sugar content in grams per 100g from CSV';

-- Fats
COMMENT ON COLUMN nutritional_info.fat_100g
IS 'Total fat content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.saturated_fat_100g
IS 'Saturated fat content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.monounsaturated_fat_100g
IS 'Monounsaturated fat content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.polyunsaturated_fat_100g
IS 'Polyunsaturated fat content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.omega_3_fat_100g
IS 'Omega-3 fat content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.omega_6_fat_100g
IS 'Omega-6 fat content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.omega_9_fat_100g
IS 'Omega-9 fat content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.trans_fat_100g
IS 'Trans fat content in grams per 100g from CSV';

-- Fibers
COMMENT ON COLUMN nutritional_info.fiber_100g
IS 'Total fiber content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.soluble_fiber_100g
IS 'Soluble fiber content in grams per 100g from CSV';
COMMENT ON COLUMN nutritional_info.insoluble_fiber_100g
IS 'Insoluble fiber content in grams per 100g from CSV';

-- Vitamins (per 100g, units from CSV)
COMMENT ON COLUMN nutritional_info.vitamin_a_100g
IS 'Vitamin A content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.vitamin_b6_100g
IS 'Vitamin B6 content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.vitamin_b12_100g
IS 'Vitamin B12 content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.vitamin_c_100g
IS 'Vitamin C content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.vitamin_d_100g
IS 'Vitamin D content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.vitamin_e_100g
IS 'Vitamin E content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.vitamin_k_100g
IS 'Vitamin K content per 100g from CSV (units vary)';

-- Minerals (per 100g, units from CSV)
COMMENT ON COLUMN nutritional_info.calcium_100g
IS 'Calcium content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.iron_100g
IS 'Iron content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.magnesium_100g
IS 'Magnesium content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.potassium_100g
IS 'Potassium content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.sodium_100g
IS 'Sodium content per 100g from CSV (units vary)';
COMMENT ON COLUMN nutritional_info.zinc_100g
IS 'Zinc content per 100g from CSV (units vary)';

-- Metadata
COMMENT ON COLUMN nutritional_info.created_at
IS 'Timestamp when record was created in our database';
COMMENT ON COLUMN nutritional_info.updated_at
IS 'Timestamp when record was last updated in our database';
