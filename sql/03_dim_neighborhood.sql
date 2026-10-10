-- ============================================================
-- 03_dim_neighborhood.sql
-- Builds dim_neighborhood: one row per neighborhood with a numeric ID.
-- Run order: 2 of 4 (after staging, before the fact table)
-- ============================================================

CREATE OR REPLACE TABLE `riyadh.dim_neighborhood` AS
SELECT
    -- ordering by name keeps IDs stable across reruns
    ROW_NUMBER() OVER (ORDER BY neighborhood_name) AS neighborhood_id,
    neighborhood_name
FROM (
    -- deduplicate first: ROW_NUMBER() runs before DISTINCT,
    -- so both in one SELECT would give every row its own ID
    SELECT DISTINCT neighborhood AS neighborhood_name
    FROM `riyadh.stg_listings`
);
