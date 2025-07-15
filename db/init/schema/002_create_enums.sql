-- db/init/schema/002_create_enums.sql
-- Enum for ingredient units
DO $$ BEGIN CREATE TYPE recipe_manager.ingredient_unit_enum AS ENUM (
  'G', 'KG', 'OZ', 'LB', 'ML', 'L', 'CUP', 'TBSP', 'TSP', 'PIECE',
  'CLOVE', 'SLICE', 'PINCH', 'CAN', 'BOTTLE', 'PACKET', 'UNIT'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for meal types
DO $$ BEGIN CREATE TYPE recipe_manager.meal_type_enum
  AS ENUM ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'DESSERT');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for recipe revision categories
DO $$ BEGIN CREATE TYPE recipe_manager.revision_category_enum
  as ENUM ('INGREDIENT', 'STEP');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for recipe revision types
DO $$ BEGIN CREATE TYPE recipe_manager.revision_type_enum
  AS ENUM ('ADD', 'UPDATE', 'DELETE');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for recipe difficulty levels
DO $$ BEGIN CREATE TYPE recipe_manager.difficulty_level_enum
  AS ENUM ('BEGINNER', 'EASY', 'MEDIUM', 'HARD', 'EXPERT');
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for allergens
DO $$ BEGIN CREATE TYPE recipe_manager.allergen_enum AS ENUM (
  -- FDA Major Allergens (Top 9)
  'MILK', 'EGGS', 'FISH', 'SHELLFISH', 'TREE_NUTS', 'PEANUTS',
  'WHEAT', 'SOYBEANS', 'SESAME',
  -- Additional EU Major Allergens
  'CELERY', 'MUSTARD', 'LUPIN', 'SULPHITES',
  -- Tree Nut Specifics
  'ALMONDS', 'CASHEWS', 'HAZELNUTS', 'WALNUTS',
  -- Common Additional Allergens
  'GLUTEN', 'COCONUT', 'CORN', 'YEAST', 'GELATIN', 'KIWI',
  -- Reiligious/Dietary
  'PORK', 'BEEF', 'ALCOHOL',
  -- Additives/Chemicals
  'SULFUR_DIOXIDE', 'PHENYLALANINE',
  -- Other
  'NONE', 'UNKNOWN'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
-- Enum for food groups (based on OpenFoodFacts taxonomy)
DO $$ BEGIN CREATE TYPE recipe_manager.food_group_enum AS ENUM (
  -- Plant-based whole foods
  'VEGETABLES', 'FRUITS', 'GRAINS', 'LEGUMES', 'NUTS_SEEDS',
  -- Animal products
  'MEAT', 'POULTRY', 'SEAFOOD', 'DAIRY',
  -- Processed and manufactured foods
  'BEVERAGES', 'PROCESSED_FOODS',
  -- Fallback
  'UNKNOWN'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;

-- Font size enum
DO $$ BEGIN CREATE TYPE recipe_manager.font_size_enum AS ENUM (
  'SMALL', 'MEDIUM', 'LARGE', 'EXTRA_LARGE'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;

-- Color scheme enum
DO $$ BEGIN CREATE TYPE recipe_manager.color_scheme_enum AS ENUM (
  'LIGHT', 'DARK', 'AUTO', 'HIGH_CONTRAST'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;

-- Layout density enum
DO $$ BEGIN CREATE TYPE recipe_manager.layout_density_enum AS ENUM (
  'COMPACT', 'COMFORTABLE', 'SPACIOUS'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;

-- Profile visibility enum
DO $$ BEGIN CREATE TYPE recipe_manager.profile_visibility_enum AS ENUM (
  'PUBLIC', 'FRIENDS_ONLY', 'PRIVATE'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;

-- Language enum
DO $$ BEGIN CREATE TYPE recipe_manager.language_enum AS ENUM (
  'EN', 'ES', 'FR', 'DE', 'IT', 'PT', 'ZH', 'JA', 'KO', 'RU'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;

-- Theme enum
DO $$ BEGIN CREATE TYPE recipe_manager.theme_enum AS ENUM (
  'LIGHT', 'DARK', 'AUTO', 'CUSTOM'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;

-- Volume level enum
DO $$ BEGIN CREATE TYPE recipe_manager.volume_level_enum AS ENUM (
  'MUTED', 'LOW', 'MEDIUM', 'HIGH'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;

-- Password strength enum
DO $$ BEGIN CREATE TYPE recipe_manager.password_strength_enum AS ENUM (
  'WEAK', 'MEDIUM', 'STRONG', 'VERY_STRONG'
);
EXCEPTION
WHEN duplicate_object THEN null;
END $$;
