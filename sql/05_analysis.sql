-- ============================================================
-- 05_analysis.sql
-- Top 10 neighborhoods by price per m².
-- Read-only: uses the star schema, creates no tables.
-- ============================================================

SELECT
  dim.neighborhood_name,
  COUNT(*) AS listings,
  -- total price / total area, so small listings don't dominate
  -- (AVG(price / size) let one 11,111,111 typo double a neighborhood's value)
  ROUND(SUM(fact.price) / SUM(fact.size)) AS price_per_sqm
FROM `riyadh.fact_listings` AS fact
INNER JOIN `riyadh.dim_neighborhood` AS dim
  ON dim.neighborhood_id = fact.neighborhood_id
GROUP BY dim.neighborhood_name
-- at least 10 listings, so one unusual listing can't decide a neighborhood's rank
HAVING COUNT(*) >= 10
ORDER BY price_per_sqm DESC
LIMIT 10;
