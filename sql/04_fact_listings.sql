-- ============================================================
-- 04_fact_listings.sql
-- Builds fact_listings: one row per listing, with measurements
-- and a neighborhood_id pointing to dim_neighborhood.
-- Run order: 3 of 4 (after the dimension)
-- ============================================================

CREATE OR REPLACE TABLE `riyadh.fact_listings` AS
SELECT
    stg.listing_id,
    dim.neighborhood_id,
    stg.size,
    stg.price,
    stg.bedrooms,
    stg.bathrooms
FROM `riyadh.stg_listings` AS stg
-- LEFT JOIN keeps every listing: an unmatched name shows up as a
-- NULL neighborhood_id (caught by check 12) instead of being dropped
LEFT JOIN `riyadh.dim_neighborhood` AS dim
    ON dim.neighborhood_name = stg.neighborhood;
