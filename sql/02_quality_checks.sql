-- ============================================================
-- 02_quality_checks.sql
-- Tests for the staging table and the star schema.
-- Run after 01, 03 and 04. Every check should match its Expected value.
-- ============================================================


-- ------------------------------------------------------------
-- Staging checks (stg_listings)
-- ------------------------------------------------------------

-- Check 1: Staging row count
-- Expected: 9597
SELECT COUNT(*) AS stg_rows
FROM `riyadh.stg_listings`;

-- Check 2: Every listing has a neighborhood
-- Expected: 0
SELECT COUNT(*) AS null_neighborhoods
FROM `riyadh.stg_listings`
WHERE neighborhood IS NULL;

-- Check 3: The size fix for listing 8054 was applied
-- Expected: 450
SELECT size
FROM `riyadh.stg_listings`
WHERE listing_id = 8054;

-- Check 4: Listing IDs are unique
-- Expected: 0
SELECT COUNT(*) - COUNT(DISTINCT listing_id) AS duplicate_ids
FROM `riyadh.stg_listings`;

-- Check 5: No NULLs in key columns
-- Expected: 0
SELECT COUNT(*) AS null_key_values
FROM `riyadh.stg_listings`
WHERE size IS NULL
   OR price IS NULL
   OR details IS NULL;

-- Check 6: Sizes are in a believable range (50 to 10,000 m²)
-- Expected: 0
SELECT COUNT(*) AS bad_sizes
FROM `riyadh.stg_listings`
WHERE size > 10000
   OR size < 50;

-- Check 7: Rows removed by cleaning (raw minus staging)
-- Expected: 377
SELECT
  (SELECT COUNT(*) FROM `riyadh.raw_listings`)
  - (SELECT COUNT(*) FROM `riyadh.stg_listings`) AS rows_removed;

-- Check 8: No duplicate listings survived the dedupe rule
-- Expected: 0
SELECT COUNT(*) AS duplicate_groups
FROM (
  SELECT COUNT(*)
  FROM `riyadh.stg_listings`
  GROUP BY neighborhood, size, price, bedrooms, bathrooms, details
  HAVING COUNT(*) > 1
);

-- Check 9: Price rules hold (no missing-zero or extra-zero typos)
-- Expected: 0
SELECT COUNT(*) AS price_rule_violations
FROM `riyadh.stg_listings`
WHERE price < 200000
   OR price / size > 20000;


-- ------------------------------------------------------------
-- Star schema checks (dim_neighborhood, fact_listings)
-- ------------------------------------------------------------

-- Check 10: Fact table has one row per staging listing
-- Expected: 9597
SELECT COUNT(*) AS fact_rows
FROM `riyadh.fact_listings`;

-- Check 11: Each neighborhood name appears once in the dimension
-- Expected: total_rows = unique_names (124 = 124)
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT neighborhood_name) AS unique_names
FROM `riyadh.dim_neighborhood`;

-- Check 12: Every listing matched a neighborhood in the join
-- Expected: 0
SELECT COUNT(*) AS unmatched_listings
FROM `riyadh.fact_listings`
WHERE neighborhood_id IS NULL;

-- Check 13: Prices are identical in fact and staging, listing by listing
-- Expected: 0
SELECT COUNT(*) AS price_mismatches
FROM `riyadh.fact_listings` AS fact
INNER JOIN `riyadh.stg_listings` AS stg
  ON fact.listing_id = stg.listing_id
WHERE fact.price != stg.price;
