-- db/queries/monitoring/performance_metrics.sql
-- Database performance monitoring queries

-- Table sizes and growth tracking
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS size,
  pg_total_relation_size(schemaname || '.' || tablename) AS size_bytes,
  pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS table_size,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename) - pg_relation_size(schemaname || '.' || tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'recipe_manager'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;

-- Index usage statistics
SELECT
  schemaname,
  tablename,
  indexname,
  idx_tup_read,
  idx_tup_fetch,
  idx_scan,
  CASE
    WHEN idx_scan = 0 THEN 'Unused'
    WHEN idx_scan < 10 THEN 'Low Usage'
    WHEN idx_scan < 100 THEN 'Medium Usage'
    ELSE 'High Usage'
  END AS usage_category
FROM pg_stat_user_indexes
WHERE schemaname = 'recipe_manager'
ORDER BY idx_scan DESC;

-- Connection and activity statistics
SELECT
  state,
  count(*) AS connection_count,
  max(extract(EPOCH FROM (now() - state_change))) AS max_duration_seconds
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state
ORDER BY connection_count DESC;

-- Lock information
SELECT
  mode,
  locktype,
  count(*) AS lock_count
FROM pg_locks
WHERE database = (SELECT pg_database.oid FROM pg_database
WHERE pg_database.datname = current_database())
GROUP BY mode, locktype
ORDER BY lock_count DESC;

-- Database-wide statistics
SELECT
  'connections' AS metric_name,
  numbackends AS metric_value
FROM pg_stat_database
WHERE datname = current_database()

UNION ALL

SELECT
  'transactions_committed' AS metric_name,
  xact_commit AS metric_value
FROM pg_stat_database
WHERE datname = current_database()

UNION ALL

SELECT
  'transactions_rolled_back' AS metric_name,
  xact_rollback AS metric_value
FROM pg_stat_database
WHERE datname = current_database()

UNION ALL

SELECT
  'blocks_read' AS metric_name,
  blks_read AS metric_value
FROM pg_stat_database
WHERE datname = current_database()

UNION ALL

SELECT
  'blocks_hit' AS metric_name,
  blks_hit AS metric_value
FROM pg_stat_database
WHERE datname = current_database();

-- Buffer cache hit ratio
SELECT
  'cache_hit_ratio' AS metric_name,
  round(
    (blks_hit * 100.0) / nullif(blks_hit + blks_read, 0), 2
  ) AS metric_value
FROM pg_stat_database
WHERE datname = current_database();
