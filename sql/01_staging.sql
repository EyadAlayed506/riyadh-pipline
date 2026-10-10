-- ============================================================
-- 01_staging.sql
-- Builds stg_listings: the cleaned version of raw_listings.
-- Run order: 1 of 4 (staging -> dim -> fact -> checks)
-- ============================================================

CREATE OR REPLACE TABLE `riyadh.stg_listings` AS

-- Step 1: drop listings with no description text
WITH non_null AS (
  SELECT *
  FROM `riyadh.raw_listings`
  WHERE details IS NOT NULL
),

-- Step 2: fix known entry errors and derive the neighborhood
fixed AS (
  SELECT
    -- listing 8054 had size 450,000; the listing text confirms 450
    * REPLACE (CASE WHEN listing_id = 8054 THEN 450 ELSE size END AS size),
    -- "حي الرمال - الرياض" -> "حي الرمال"
    TRIM(REGEXP_EXTRACT(location, r'(.*)-.*')) AS neighborhood
  FROM non_null
  -- invalid listings found during exploration
  WHERE listing_id NOT IN (217, 7436)
)

-- Step 3: remove price typos, then deduplicate
SELECT *
FROM fixed
WHERE price >= 200000            -- missing-zero typos (e.g. 85,000 where the text says 850,000)
  AND price / size <= 20000      -- extra-zero typos (e.g. 13,000,000 for an ordinary 225 m² villa)
-- keep one row per identical listing; the lowest listing_id wins
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY neighborhood, size, price, bedrooms, bathrooms, details
  ORDER BY listing_id
) = 1;
