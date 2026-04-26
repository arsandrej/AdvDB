-- =============================================================================
-- SCRIPT 2 OF 4  |  seed_products_electronics.sql
-- Loads: PRODUCTS, PRODUCT_CATEGORIES
--
-- Depends on: seed_products_reference_data.sql  (CATEGORIES must already exist)
-- Run before: seed_product_variants.sql
--
--
--
-- products.csv columns:  name, description, category
--   "category" is the leaf/mid category name matching a row in CATEGORIES.
--   Each product is automatically linked to its full ancestor chain in
--   PRODUCT_CATEGORIES via a recursive CTE.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. STAGING TABLE
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE stg_products (
    name        TEXT,
    description TEXT,
    category    TEXT
);

-- ---------------------------------------------------------------------------
-- 2. LOAD CSV INTO STAGING TABLE
-- ---------------------------------------------------------------------------

COPY stg_products (name, description, category)
    FROM '/csv/products.csv'
    CSV HEADER;

-- Trim whitespace on all columns
UPDATE stg_products SET
    name        = TRIM(name),
    description = TRIM(description),
    category    = TRIM(category);

-- Remove blank or uncategorised rows
DELETE FROM stg_products
WHERE TRIM(name) = ''
   OR TRIM(category) = '';

-- Deduplicate by product name (keep first occurrence)
DELETE FROM stg_products
WHERE ctid NOT IN (
    SELECT MIN(ctid) FROM stg_products GROUP BY name
);

-- ---------------------------------------------------------------------------
-- 3. PRODUCTS
-- ---------------------------------------------------------------------------

INSERT INTO PRODUCTS (name, description, created_at, updated_at)
SELECT
    s.name,
    s.description,
    -- Spread created_at randomly across the last 2 years
    NOW() - (RANDOM() * INTERVAL '730 days'),
    -- updated_at: created_at + random offset up to 180 days after it
    (NOW() - (RANDOM() * INTERVAL '730 days')) + (RANDOM() * INTERVAL '180 days')
FROM stg_products s
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. PRODUCT_CATEGORIES
--    Link every product to its leaf category AND every ancestor up to root.
--    The recursive CTE walks up the tree so a GPU tagged "GeForce RTX 50 Series"
--    also appears under "NVIDIA GPUs" → "Graphics Cards".
-- ---------------------------------------------------------------------------

INSERT INTO PRODUCT_CATEGORIES (product_id, category_id)
WITH RECURSIVE cat_ancestors AS (

    -- Base: every category maps to itself; carry parent_id as the pointer
    SELECT id AS leaf_id, id AS ancestor_id, parent_id
    FROM   CATEGORIES

    UNION ALL

    -- Recursive: emit the parent as an ancestor, carry its parent_id up next
    SELECT ca.leaf_id, c.id, c.parent_id
    FROM   cat_ancestors ca
    JOIN   CATEGORIES    c  ON c.id = ca.parent_id

)
SELECT DISTINCT p.id, ca.ancestor_id
FROM   PRODUCTS        p
JOIN   stg_products    s   ON s.name      = p.name
JOIN   CATEGORIES      lc  ON lc.name     = s.category
JOIN   cat_ancestors   ca  ON ca.leaf_id  = lc.id
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. CLEANUP
-- ---------------------------------------------------------------------------

DROP TABLE stg_products;

COMMIT;

-- ---------------------------------------------------------------------------
-- SANITY CHECK
-- ---------------------------------------------------------------------------

SELECT 'PRODUCTS'            AS tbl, COUNT(*) AS rows FROM PRODUCTS
UNION ALL
SELECT 'PRODUCT_CATEGORIES',          COUNT(*)         FROM PRODUCT_CATEGORIES
ORDER BY tbl;
