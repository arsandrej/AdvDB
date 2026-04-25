-- =============================================================================
-- SCRIPT 1 OF 4  FOR PRODUCT STRUCTURE
-- Loads: BRANDS
-- Will load: CATEGORIES, ATTRIBUTES, ATTRIBUTE_VALUES
--
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. STAGING TABLE
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE stg_brands (
    name VARCHAR(255)
);

-- ---------------------------------------------------------------------------
-- 2. LOAD CSV INTO STAGING TABLE
-- ---------------------------------------------------------------------------

COPY stg_brands (name)
    FROM '/csv/brands.csv'
    CSV HEADER;

-- Deduplicate any repeated rows
DELETE FROM stg_brands
WHERE ctid NOT IN (
    SELECT MIN(ctid) FROM stg_brands GROUP BY name
);

-- ---------------------------------------------------------------------------
-- 3. BRANDS
-- ---------------------------------------------------------------------------

INSERT INTO BRANDS (name)
SELECT TRIM(name)
FROM   stg_brands
WHERE  TRIM(name) <> ''
ON CONFLICT (name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. CLEANUP
-- ---------------------------------------------------------------------------

DROP TABLE stg_brands;

COMMIT;

-- ---------------------------------------------------------------------------
-- SANITY CHECK
-- ---------------------------------------------------------------------------

SELECT 'BRANDS' AS tbl, COUNT(*) AS rows FROM BRANDS;