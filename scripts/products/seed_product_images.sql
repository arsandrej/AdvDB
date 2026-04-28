-- =============================================================================
-- SCRIPT 4 OF 4  FOR PRODUCT STRUCTURE
-- Populates: PRODUCT_IMAGES
--
-- Depends on: seed_product_variants.sql  (PRODUCT_VARIANTS must already exist)
--
-- No CSV needed — image URLs are generated deterministically from the variant
-- and product data already in the database.
--
-- Each variant receives 1–3 images:
--   position 1 → every variant           (hero / front shot)
--   position 2 → ~75 % of variants       (alternate angle)
--   position 3 → ~40 % of variants       (lifestyle / detail shot)
--
-- URL format:
--   https://cdn.wims-store.com/products/<product_id>/<variant_id>/<pos>_<slug>.jpg
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. URL-SAFE SLUG HELPER
--    Strips non-alphanumeric characters and replaces spaces with hyphens.
-- ---------------------------------------------------------------------------

CREATE
OR REPLACE FUNCTION fn_slug(txt TEXT)
RETURNS TEXT
LANGUAGE SQL IMMUTABLE STRICT AS $fn$
SELECT LOWER(
               REGEXP_REPLACE(
                       REGEXP_REPLACE(TRIM(txt), '[^a-zA-Z0-9\s\-]', '', 'g'),
                       '\s+', '-', 'g'
               )
       );
$fn$;

-- ---------------------------------------------------------------------------
-- 2. PRODUCT_IMAGES
--    Generate 3 candidate positions per variant via a VALUES cross join,
--    then filter by position rules to get the right coverage per variant.
-- ---------------------------------------------------------------------------

INSERT INTO PRODUCT_IMAGES (url, position, product_variants_id)
WITH

    -- Attach brand name and product name to every variant for slug building
    variant_info AS (SELECT pv.id  AS variant_id,
                            pv.product_id,
                            pv.brand_id,
                            b.name AS brand_name,
                            p.name AS product_name
                     FROM PRODUCT_VARIANTS pv
                              JOIN PRODUCTS p ON p.id = pv.product_id
                              JOIN BRANDS b ON b.id = pv.brand_id),

    -- Cross join with positions 1, 2, 3
    candidates AS (SELECT vi.variant_id,
                          vi.product_id,
                          pos.n AS position, 'https://cdn.wims-store.com/products/'
    || vi.product_id::TEXT || '/'
    || vi.variant_id::TEXT || '/'
    || pos.n::TEXT || '_'
    || fn_slug(LEFT (vi.brand_name, 10)) || '-'
    || fn_slug(LEFT (vi.product_name, 30))
    || '.jpg' AS url
FROM variant_info vi
    CROSS JOIN (VALUES (1), (2), (3)) AS pos(n)
    )

SELECT url,
       position,
       variant_id AS product_variants_id
FROM candidates
WHERE
   -- Position 1: always include
    position = 1

   -- Position 2: ~75 % of variants (skip when variant_id % 4 = 0)
   OR (position = 2 AND variant_id % 4 <> 0)

   -- Position 3: ~40 % of variants
   OR (position = 3 AND variant_id % 5 IN (0, 1)) ON CONFLICT (product_variants_id, position) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. CLEANUP
-- ---------------------------------------------------------------------------

DROP FUNCTION fn_slug(TEXT);

COMMIT;

-- ---------------------------------------------------------------------------
-- SANITY CHECK  (full summary across all seeded tables)
-- ---------------------------------------------------------------------------

SELECT 'BRANDS' AS tbl, COUNT(*) AS rows
FROM BRANDS
UNION ALL
SELECT 'CATEGORIES', COUNT(*)
FROM CATEGORIES
UNION ALL
SELECT 'ATTRIBUTES', COUNT(*)
FROM ATTRIBUTES
UNION ALL
SELECT 'ATTRIBUTE_VALUES', COUNT(*)
FROM ATTRIBUTE_VALUES
UNION ALL
SELECT 'PRODUCTS', COUNT(*)
FROM PRODUCTS
UNION ALL
SELECT 'PRODUCT_CATEGORIES', COUNT(*)
FROM PRODUCT_CATEGORIES
UNION ALL
SELECT 'PRODUCT_VARIANTS', COUNT(*)
FROM PRODUCT_VARIANTS
UNION ALL
SELECT 'VARIANT_ATTRIBUTES', COUNT(*)
FROM VARIANT_ATTRIBUTES
UNION ALL
SELECT 'PRODUCT_IMAGES', COUNT(*)
FROM PRODUCT_IMAGES
ORDER BY tbl;