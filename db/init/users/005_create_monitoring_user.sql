-- db/init/users/005_create_monitoring_user.sql
-- Create dedicated monitoring user for postgres_exporter with minimal
-- permissions.
-- This file uses placeholders that get replaced by the setup script

DO $$
DECLARE
    monitoring_user_name TEXT := '__MONITORING_USER__';
    monitoring_password TEXT := '__MONITORING_PASSWORD__';
    target_database TEXT := '__POSTGRES_DB__';
BEGIN
    -- Create monitoring user with limited privileges
    EXECUTE format('CREATE USER %I WITH PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT LOGIN',
                   monitoring_user_name, monitoring_password);

    -- Grant connection to database
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO %I', target_database, monitoring_user_name);

    -- Grant usage on recipe_manager schema
    EXECUTE format('GRANT USAGE ON SCHEMA recipe_manager TO %I', monitoring_user_name);

    -- Grant select on specific tables needed for monitoring
    EXECUTE format('GRANT SELECT ON recipe_manager.recipes TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON recipe_manager.users TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON recipe_manager.reviews TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON recipe_manager.recipe_favorites TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON recipe_manager.ingredients TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON recipe_manager.recipe_ingredients TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON recipe_manager.meal_plans TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON recipe_manager.meal_plan_recipes TO %I', monitoring_user_name);

    -- Grant access to PostgreSQL system tables and views for standard metrics
    EXECUTE format('GRANT SELECT ON pg_stat_database TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_stat_user_tables TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_stat_user_indexes TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_statio_user_tables TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_statio_user_indexes TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_stat_activity TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_stat_replication TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_stat_bgwriter TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_stat_archiver TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_settings TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON pg_locks TO %I', monitoring_user_name);

    -- Grant access to table/schema size information
    EXECUTE format('GRANT SELECT ON information_schema.tables TO %I', monitoring_user_name);
    EXECUTE format('GRANT SELECT ON information_schema.schemata TO %I', monitoring_user_name);

    -- Grant access to pg_stat_statements if available
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') THEN
        EXECUTE format('GRANT SELECT ON pg_stat_statements TO %I', monitoring_user_name);
    END IF;

    -- Create a comment for documentation
    EXECUTE format('COMMENT ON ROLE %I IS %L', monitoring_user_name,
                   'Monitoring user for postgres_exporter with read-only access to metrics tables');
END $$;
