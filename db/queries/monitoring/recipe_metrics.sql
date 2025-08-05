-- db/queries/monitoring/recipe_metrics.sql
-- Comprehensive recipe database metrics for monitoring dashboards

-- Recipe creation trends
SELECT
  DATE_TRUNC('hour', created_at) AS time_bucket,
  COUNT(*) AS recipes_created,
  COUNT(DISTINCT user_id) AS unique_creators
FROM recipe_manager.recipes
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY time_bucket;

-- Most popular recipes by favorites
SELECT
  r.recipe_id,
  r.title,
  u.username AS creator,
  COUNT(f.user_id) AS favorites_count,
  COALESCE(AVG(rv.rating), 0) AS avg_rating,
  COUNT(rv.rating) AS review_count
FROM recipe_manager.recipes AS r
INNER JOIN recipe_manager.users AS u ON r.user_id = u.user_id
LEFT JOIN recipe_manager.recipe_favorites AS f ON r.recipe_id = f.recipe_id
LEFT JOIN recipe_manager.reviews AS rv ON r.recipe_id = rv.recipe_id
GROUP BY r.recipe_id, r.title, u.username
HAVING COUNT(f.user_id) > 0
ORDER BY favorites_count DESC, avg_rating DESC
LIMIT 20;

-- User engagement statistics
SELECT
  'recipes_created_today' AS metric_name,
  COUNT(*) AS metric_value
FROM recipe_manager.recipes
WHERE created_at >= CURRENT_DATE

UNION ALL

SELECT
  'reviews_created_today' AS metric_name,
  COUNT(*) AS metric_value
FROM recipe_manager.reviews
WHERE created_at >= CURRENT_DATE

UNION ALL

SELECT
  'favorites_added_today' AS metric_name,
  COUNT(*) AS metric_value
FROM recipe_manager.recipe_favorites
WHERE created_at >= CURRENT_DATE

UNION ALL

SELECT
  'active_users_today' AS metric_name,
  COUNT(DISTINCT user_id) AS metric_value
FROM (
  SELECT user_id FROM recipe_manager.recipes
WHERE created_at >= CURRENT_DATE
  UNION
  SELECT user_id FROM recipe_manager.reviews
WHERE created_at >= CURRENT_DATE
  UNION
  SELECT user_id FROM recipe_manager.recipe_favorites
WHERE created_at >= CURRENT_DATE
) AS active_users;

-- Recipe difficulty distribution
SELECT
  difficulty,
  COUNT(*) AS recipe_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM recipe_manager.recipes
WHERE difficulty IS NOT NULL
GROUP BY difficulty
ORDER BY recipe_count DESC;

-- Top ingredients by usage
SELECT
  i.name AS ingredient_name,
  COUNT(ri.recipe_id) AS usage_count,
  COUNT(DISTINCT ri.recipe_id) AS unique_recipes
FROM recipe_manager.ingredients AS i
INNER JOIN recipe_manager.recipe_ingredients AS ri ON i.ingredient_id = ri.ingredient_id
GROUP BY i.ingredient_id, i.name
ORDER BY usage_count DESC
LIMIT 25;
