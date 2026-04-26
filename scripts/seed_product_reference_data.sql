-- =============================================================================
-- SCRIPT 1 OF 4  FOR PRODUCT STRUCTURE
-- Loads: BRANDS, CATEGORIES, ATTRIBUTES, ATTRIBUTE_VALUES
-- Run before seed_products_electronics and seed_product_variants
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. STAGING TABLE
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE stg_brands (
    name VARCHAR(255)
);

CREATE TEMP TABLE stg_categories (
    name        VARCHAR(255),
    parent_name VARCHAR(255)
);

CREATE TEMP TABLE stg_attributes (
    name                 VARCHAR(255),
    data_type            VARCHAR(50),
    unit                 VARCHAR(50),
    is_variant_attribute BOOLEAN
);

CREATE TEMP TABLE stg_attribute_values (
    attribute_name VARCHAR(255),
    value          VARCHAR(255)
);

-- ---------------------------------------------------------------------------
-- 2. LOAD CSV INTO STAGING TABLE
-- ---------------------------------------------------------------------------

COPY stg_brands (name) FROM '/csv/brands.csv' CSV HEADER;
COPY stg_categories    FROM '/csv/categories.csv' CSV HEADER;
COPY stg_attributes       FROM '/csv/attributes.csv'       CSV HEADER;
COPY stg_attribute_values FROM '/csv/attribute_values.csv' CSV HEADER;

-- Deduplicate any repeated rows
DELETE FROM stg_brands
WHERE ctid NOT IN (
    SELECT MIN(ctid) FROM stg_brands GROUP BY name
);

DELETE FROM stg_categories
WHERE ctid NOT IN (
    SELECT MIN(ctid) FROM stg_categories GROUP BY name, parent_name
);

DELETE FROM stg_attributes
WHERE ctid NOT IN (
    SELECT MIN(ctid) FROM stg_attributes GROUP BY name
);

DELETE FROM stg_attribute_values
WHERE ctid NOT IN (
    SELECT MIN(ctid) FROM stg_attribute_values GROUP BY attribute_name, value
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
-- 4. CATEGORIES  (multi-pass to resolve parent → child dependencies)
--
--    Pass 1: root categories (parent_name is blank)
--    Pass 2+: children whose parent was inserted in the previous pass.
--    The DO $$ loop repeats until no new rows can be inserted,
--    which handles any depth of nesting without hardcoding pass counts.
-- ---------------------------------------------------------------------------

-- Pass 1 — roots
INSERT INTO CATEGORIES (name, parent_id)
SELECT TRIM(name), NULL
FROM   stg_categories
WHERE  TRIM(COALESCE(parent_name, '')) = ''
ON CONFLICT (parent_id, name) DO NOTHING;

-- Pass 2+ — children, resolved iteratively
DO $$
DECLARE
    inserted INT := 1;
BEGIN
    WHILE inserted > 0 LOOP
        WITH ins AS (
            INSERT INTO CATEGORIES (name, parent_id)
            SELECT TRIM(s.name), p.id
            FROM   stg_categories s
            JOIN   CATEGORIES p ON p.name = TRIM(s.parent_name)
            WHERE  TRIM(COALESCE(s.parent_name, '')) <> ''
            ON CONFLICT (parent_id, name) DO NOTHING
            RETURNING 1
        )
        SELECT COUNT(*) INTO inserted FROM ins;
    END LOOP;
END;
$$;


-- ---------------------------------------------------------------------------
-- 5. ATTRIBUTES
-- ---------------------------------------------------------------------------

INSERT INTO ATTRIBUTES (name, data_type, unit, is_variant_attribute)
SELECT
    TRIM(name),
    TRIM(data_type),
    NULLIF(TRIM(COALESCE(unit, '')), ''),
    is_variant_attribute
FROM stg_attributes
WHERE TRIM(name) <> ''
ON CONFLICT (name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. ATTRIBUTE_VALUES
-- ---------------------------------------------------------------------------

INSERT INTO ATTRIBUTE_VALUES (attribute_id, value)
SELECT a.id, TRIM(s.value)
FROM   stg_attribute_values s
JOIN   ATTRIBUTES a ON a.name = TRIM(s.attribute_name)
WHERE  TRIM(s.value) <> ''
ON CONFLICT (attribute_id, value) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. CLEANUP
-- ---------------------------------------------------------------------------

DROP TABLE stg_brands;
DROP TABLE stg_categories;
DROP TABLE stg_attributes;
DROP TABLE stg_attribute_values;

COMMIT;

-- ---------------------------------------------------------------------------
-- SANITY CHECK
-- ---------------------------------------------------------------------------

SELECT 'BRANDS' AS tbl, COUNT(*) AS rows FROM BRANDS
UNION ALL
SELECT 'CATEGORIES',    COUNT(*)      FROM CATEGORIES
UNION ALL
SELECT 'ATTRIBUTES',               COUNT(*)         FROM ATTRIBUTES
UNION ALL
SELECT 'ATTRIBUTE_VALUES',         COUNT(*)         FROM ATTRIBUTE_VALUES
ORDER BY tbl;