-- db/queries/monitoring/health_checks.sql
-- Database health check queries for alerting and monitoring

-- Check for long-running queries
SELECT
  pid,
  state,
  query,
  EXTRACT(EPOCH FROM (NOW() - query_start)) AS duration_seconds
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start < NOW() - INTERVAL '30 seconds'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duration_seconds DESC;

-- Check for blocked queries
SELECT
  blocked_locks.pid AS blocked_pid,
  blocked_activity.query AS blocked_query,
  blocking_locks.pid AS blocking_pid,
  blocking_activity.query AS blocking_query,
  EXTRACT(EPOCH FROM (NOW() - blocked_activity.query_start)) AS blocked_duration_seconds
FROM pg_catalog.pg_locks AS blocked_locks
INNER JOIN pg_catalog.pg_stat_activity AS blocked_activity ON blocked_locks.pid = blocked_activity.pid
INNER JOIN pg_catalog.pg_locks AS blocking_locks ON blocked_locks.locktype = blocking_locks.locktype
  AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
  AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
  AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
  AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
  AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
  AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
  AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
  AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
  AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
  AND blocked_locks.pid != blocking_locks.pid
INNER JOIN pg_catalog.pg_stat_activity AS blocking_activity ON blocking_locks.pid = blocking_activity.pid
WHERE NOT blocked_locks.granted;

-- Check replication lag (if applicable)
SELECT
  client_addr,
  state,
  EXTRACT(EPOCH FROM (NOW() - backend_start)) AS connection_duration_seconds,
  CASE
    WHEN PG_IS_IN_RECOVERY() THEN NULL
    ELSE EXTRACT(EPOCH FROM (NOW() - PG_STAT_GET_BACKEND_ACTIVITY_START(pid)))
  END AS lag_seconds
FROM pg_stat_replication;

-- Check for table bloat estimates
SELECT
  schemaname,
  tablename,
  n_dead_tup,
  n_live_tup,
  CASE
    WHEN n_live_tup > 0 THEN ROUND((n_dead_tup * 100.0) / (n_live_tup + n_dead_tup), 2)
    ELSE 0
  END AS dead_tuple_percent
FROM pg_stat_user_tables
WHERE schemaname = 'recipe_manager'
  AND n_live_tup > 0
ORDER BY dead_tuple_percent DESC;

-- Check for unused indexes
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  PG_SIZE_PRETTY(PG_RELATION_SIZE(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'recipe_manager'
  AND idx_scan = 0
  AND PG_RELATION_SIZE(indexrelid) > 1024 * 1024  -- Larger than 1MB
ORDER BY PG_RELATION_SIZE(indexrelid) DESC;

-- Database connectivity test
SELECT
  'database_accessible' AS health_check,
  CASE
    WHEN COUNT(*) >= 0 THEN 'OK'
    ELSE 'ERROR'
  END AS status
FROM recipe_manager.recipes
LIMIT 1;

-- Check for critical errors in pg_stat_database
SELECT
  'deadlocks_detected' AS health_check,
  deadlocks AS deadlock_count,
  CASE
    WHEN deadlocks > 10 THEN 'WARNING'
    WHEN deadlocks > 50 THEN 'CRITICAL'
    ELSE 'OK'
  END AS status
FROM pg_stat_database
WHERE datname = CURRENT_DATABASE();

-- Check disk space usage (requires additional setup)
-- This would typically be monitored at the OS level
SELECT
  'database_size' AS health_check,
  'INFO' AS status,
  PG_SIZE_PRETTY(PG_DATABASE_SIZE(CURRENT_DATABASE())) AS size,
  PG_DATABASE_SIZE(CURRENT_DATABASE()) AS size_bytes;
