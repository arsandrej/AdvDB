-- =============================================================================
-- SCRIPT 3 OF 4  |  seed_product_variants
-- Loads: PRODUCT_VARIANTS, VARIANT_ATTRIBUTES
--
-- Depends on: seed_reference_data.sql, seed_products_electronics.sql
--
-- variant_dimensions.csv defines, per leaf category, up to 3 attribute axes
-- and their pipe-separated allowed values.  This script:
--   1. Loads the CSV into a staging table.
--   2. Explodes each pipe-separated value list into individual rows using
--      regexp_split_to_table, producing a full cross-product of
--      (attr1_val × attr2_val × attr3_val) per category rule.
--   3. Joins those combos to every product that belongs to that category.
--   4. Inserts one PRODUCT_VARIANTS row per (product × combo).
--   5. Explodes the up-to-3 attribute/value pairs into VARIANT_ATTRIBUTES.
--
-- variant_dimensions.csv columns:
--   category_name,
--   attr1_name, attr1_values   (pipe-separated e.g. "Black|White|Silver")
--   attr2_name, attr2_values   (empty string when not used)
--   attr3_name, attr3_values   (empty string when not used)
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- GUARD: abort early if dependencies are missing
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM PRODUCTS) = 0 THEN
        RAISE EXCEPTION 'seed_02 has not been run — PRODUCTS is empty';
    END IF;
    IF (SELECT COUNT(*) FROM CATEGORIES) = 0 THEN
        RAISE EXCEPTION 'seed_01 has not been run — CATEGORIES is empty';
    END IF;
    IF (SELECT COUNT(*) FROM ATTRIBUTES) = 0 THEN
        RAISE EXCEPTION 'seed_01 has not been run — ATTRIBUTES is empty';
    END IF;
    IF (SELECT COUNT(*) FROM ATTRIBUTE_VALUES) = 0 THEN
        RAISE EXCEPTION 'seed_01 has not been run — ATTRIBUTE_VALUES is empty';
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. STAGING TABLE
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE stg_variant_dims (
    category_name  TEXT,
    attr1_name     TEXT,
    attr1_values   TEXT,
    attr2_name     TEXT,
    attr2_values   TEXT,
    attr3_name     TEXT,
    attr3_values   TEXT
);

-- ---------------------------------------------------------------------------
-- 2. LOAD CSV INTO STAGING TABLE
-- ---------------------------------------------------------------------------

COPY stg_variant_dims (
    category_name,
    attr1_name, attr1_values,
    attr2_name, attr2_values,
    attr3_name, attr3_values
)
    FROM '/csv/variants.csv'
    CSV HEADER;

-- Trim whitespace; convert empty strings to NULL for optional columns
UPDATE stg_variant_dims SET
    category_name = TRIM(category_name),
    attr1_name    = TRIM(attr1_name),
    attr1_values  = TRIM(attr1_values),
    attr2_name    = NULLIF(TRIM(COALESCE(attr2_name, '')), ''),
    attr2_values  = NULLIF(TRIM(COALESCE(attr2_values, '')), ''),
    attr3_name    = NULLIF(TRIM(COALESCE(attr3_name, '')), ''),
    attr3_values  = NULLIF(TRIM(COALESCE(attr3_values, '')), '');

DELETE FROM stg_variant_dims WHERE TRIM(category_name) = '';

-- Deduplicate
DELETE FROM stg_variant_dims
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM   stg_variant_dims
    GROUP  BY category_name, attr1_name, attr1_values,
              attr2_name,    attr2_values,
              attr3_name,    attr3_values
);

-- ---------------------------------------------------------------------------
-- 3. EXPLODE PIPE-SEPARATED VALUES → ONE ROW PER VALUE COMBINATION
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE dim_combos AS
SELECT
    d.category_name,

    -- attr1 (mandatory)
    a1.id                AS attr1_id,
    TRIM(v1.val)         AS attr1_val,
    av1.id               AS av1_id,

    -- attr2 (optional)
    a2.id                AS attr2_id,
    TRIM(v2.val)         AS attr2_val,
    av2.id               AS av2_id,

    -- attr3 (optional)
    a3.id                AS attr3_id,
    TRIM(v3.val)         AS attr3_val,
    av3.id               AS av3_id

FROM stg_variant_dims d

-- ── attr1 ──────────────────────────────────────────────────────────────────
JOIN  ATTRIBUTES       a1  ON  a1.name = d.attr1_name
CROSS JOIN LATERAL regexp_split_to_table(d.attr1_values, '\|') AS v1(val)
JOIN  ATTRIBUTE_VALUES av1 ON  av1.attribute_id = a1.id
                           AND av1.value = TRIM(v1.val)

-- ── attr2 ──────────────────────────────────────────────────────────────────
LEFT JOIN ATTRIBUTES       a2  ON  a2.name = d.attr2_name
                               AND d.attr2_name IS NOT NULL
LEFT JOIN LATERAL regexp_split_to_table(
              COALESCE(d.attr2_values, ''), '\|'
          ) AS v2(val)           ON  d.attr2_name IS NOT NULL
LEFT JOIN ATTRIBUTE_VALUES av2  ON  av2.attribute_id = a2.id
                                AND av2.value = TRIM(v2.val)
                                AND TRIM(v2.val) <> ''

-- ── attr3 ──────────────────────────────────────────────────────────────────
LEFT JOIN ATTRIBUTES       a3  ON  a3.name = d.attr3_name
                               AND d.attr3_name IS NOT NULL
LEFT JOIN LATERAL regexp_split_to_table(
              COALESCE(d.attr3_values, ''), '\|'
          ) AS v3(val)           ON  d.attr3_name IS NOT NULL
LEFT JOIN ATTRIBUTE_VALUES av3  ON  av3.attribute_id = a3.id
                                AND av3.value = TRIM(v3.val)
                                AND TRIM(v3.val) <> ''

-- Keep only rows where every defined axis resolved to a known value
WHERE av1.id IS NOT NULL
  AND (d.attr2_name IS NULL OR av2.id IS NOT NULL)
  AND (d.attr3_name IS NULL OR av3.id IS NOT NULL);

-- ---------------------------------------------------------------------------
-- 4. BASE-PRICE LOOKUP
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE product_base_price AS
SELECT
    p.id AS product_id,
    CASE
        WHEN p.name ILIKE '%RTX 5090%'   OR p.name ILIKE '%Vision Pro%'      THEN 1799.99
        WHEN p.name ILIKE '%RTX 4090%'   OR p.name ILIKE '%RTX 5080%'
          OR p.name ILIKE '%MacBook Pro 16%'                                   THEN 1199.99
        WHEN p.name ILIKE '%Threadripper%' OR p.name ILIKE '%Xeon W9%'
          OR p.name ILIKE '%RDIMM ECC%'                                        THEN  899.99
        WHEN p.name ILIKE '%RTX 5070 Ti%' OR p.name ILIKE '%RTX 4080%'
          OR p.name ILIKE '%Ryzen 9 79%'  OR p.name ILIKE '%i9-14900%'
          OR p.name ILIKE '%Gaming Laptop%'                                    THEN  699.99
        WHEN p.name ILIKE '%RTX 5070%'   OR p.name ILIKE '%RTX 4070 Ti%'
          OR p.name ILIKE '%Ryzen 7 77%' OR p.name ILIKE '%i7-14700%'
          OR p.name ILIKE '%Mirrorless%' OR p.name ILIKE '%DSLR%'             THEN  499.99
        WHEN p.name ILIKE '%RTX 4070%'   OR p.name ILIKE '%RX 7900%'
          OR p.name ILIKE '%RX 9070%'   OR p.name ILIKE '%Ultrabook%'        THEN  399.99
        WHEN p.name ILIKE '%NVMe%'       OR p.name ILIKE '%SSD%'              THEN  129.99
        WHEN p.name ILIKE '%DDR5%'       OR p.name ILIKE '%DDR4%'             THEN   89.99
        WHEN p.name ILIKE '%HDD%'        OR p.name ILIKE '%Hard Drive%'       THEN   59.99
        WHEN p.name ILIKE '%Monitor%'    OR p.name ILIKE '%Display%'          THEN  349.99
        WHEN p.name ILIKE '%Keyboard%'                                         THEN  119.99
        WHEN p.name ILIKE '%Mouse%'                                            THEN   79.99
        WHEN p.name ILIKE '%Headset%'    OR p.name ILIKE '%Headphone%'        THEN  149.99
        WHEN p.name ILIKE '%Router%'     OR p.name ILIKE '%Mesh%'             THEN  199.99
        WHEN p.name ILIKE '%Watt%'       OR p.name ILIKE '%PSU%'              THEN  109.99
        WHEN p.name ILIKE '%Case%'                                             THEN   99.99
        WHEN p.name ILIKE '%Cooler%'     OR p.name ILIKE '%AIO%'              THEN   79.99
        WHEN p.name ILIKE '%iPhone%'     OR p.name ILIKE '%Galaxy S25%'       THEN  999.99
        WHEN p.name ILIKE '%Watch%'      OR p.name ILIKE '%Smartwatch%'       THEN  299.99
        WHEN p.name ILIKE '%Camera%'                                           THEN  299.99
        ELSE 99.99
    END AS base_price
FROM PRODUCTS p;

-- ---------------------------------------------------------------------------
-- 5. BRAND ASSIGNMENT  (round-robin one brand per product)
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE product_brand AS
WITH
    numbered_products AS (
        SELECT id,
               ROW_NUMBER() OVER (ORDER BY id) AS rn
        FROM   PRODUCTS
    ),
    numbered_brands AS (
        SELECT id,
               name,
               ROW_NUMBER() OVER (ORDER BY id) AS rn
        FROM   BRANDS
    ),
    brand_count AS (SELECT COUNT(*) AS cnt FROM BRANDS)
SELECT
    p.id   AS product_id,
    b.id   AS brand_id,
    b.name AS brand_name
FROM  numbered_products p
JOIN  numbered_brands   b  ON b.rn = ((p.rn - 1) % (SELECT cnt FROM brand_count)) + 1;

-- ---------------------------------------------------------------------------
-- 6. BUILD FULL VARIANT COMBO SET
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE variant_combos AS
SELECT
    p.id          AS product_id,
    dc.attr1_id,  dc.av1_id,
    dc.attr2_id,  dc.av2_id,
    dc.attr3_id,  dc.av3_id,
    pb.brand_id,
    pb.brand_name,
    bp.base_price,
    ROW_NUMBER() OVER () AS combo_rn
FROM   PRODUCTS            p
JOIN   PRODUCT_CATEGORIES  pc  ON  pc.product_id  = p.id
JOIN   CATEGORIES          cat ON  cat.id          = pc.category_id
JOIN   dim_combos          dc  ON  dc.category_name = cat.name
JOIN   product_brand       pb  ON  pb.product_id   = p.id
JOIN   product_base_price  bp  ON  bp.product_id   = p.id

WHERE CASE cat.name

    -- CPUs
    WHEN 'Desktop CPUs'          THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Panel Type','Switch Type','Connectivity','Wattage','Kit Size','RAM Capacity')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Panel Type','Switch Type','Connectivity','Wattage','Kit Size','RAM Capacity')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Panel Type','Switch Type','Connectivity','Wattage','Kit Size','RAM Capacity')))
    WHEN 'Laptop CPUs'           THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Panel Type','Switch Type','Connectivity','Wattage','Kit Size','RAM Capacity')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Panel Type','Switch Type','Connectivity','Wattage','Kit Size','RAM Capacity')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Panel Type','Switch Type','Connectivity','Wattage','Kit Size','RAM Capacity')))
    WHEN 'Server CPUs'           THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Panel Type','Switch Type','Color','Wattage','Kit Size','RAM Capacity')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Panel Type','Switch Type','Color','Wattage','Kit Size','RAM Capacity')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Panel Type','Switch Type','Color','Wattage','Kit Size','RAM Capacity')))

    -- Motherboards
    WHEN 'ATX Motherboards'      THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
    WHEN 'Micro-ATX Motherboards' THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
    WHEN 'Mini-ITX Motherboards' THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
    WHEN 'E-ATX Motherboards'    THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Storage Capacity','Kit Size','Wattage','RAM Capacity','Refresh Rate','Resolution')))

    -- RAM
    WHEN 'DDR5 RAM'              THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
    WHEN 'DDR4 RAM'              THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
    WHEN 'Laptop RAM'            THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
    WHEN 'Server RAM'            THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','Wattage','CPU Socket','Storage Capacity','Refresh Rate','Resolution')))

    -- SSDs / HDDs
    WHEN 'PCIe 4.0 NVMe SSDs'   THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
    WHEN 'PCIe 5.0 NVMe SSDs'   THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
    WHEN 'SATA SSDs'             THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
    WHEN '3.5" Desktop HDDs'     THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
    WHEN '2.5" Laptop HDDs'      THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','Refresh Rate','Resolution','RAM Capacity','Kit Size','Wattage')))

    -- GPUs
    WHEN 'GeForce RTX 50 Series' THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
    WHEN 'GeForce RTX 40 Series' THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
    WHEN 'Radeon RX 9000 Series' THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
    WHEN 'Radeon RX 7000 Series' THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
    WHEN 'Workstation GPUs'      THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','Kit Size','CPU Socket','Speed','Wattage','RAM Capacity','Storage Capacity')))

    -- Monitors
    WHEN 'Gaming Monitors'       THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
    WHEN 'OLED Gaming Monitors'  THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
    WHEN '144Hz Monitors'        THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
    WHEN '240Hz Monitors'        THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
    WHEN '360Hz Monitors'        THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
    WHEN 'Ultrawide Monitors'    THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
    WHEN 'Professional Monitors' THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
    WHEN '4K Monitors'           THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Switch Type','CPU Socket','Kit Size','Wattage','RAM Capacity','Storage Capacity','Speed')))

    -- PSUs
    WHEN 'Modular PSUs'          THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','RAM Capacity','Storage Capacity','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','RAM Capacity','Storage Capacity','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','RAM Capacity','Storage Capacity','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Semi-Modular PSUs'     THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','RAM Capacity','Storage Capacity','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','RAM Capacity','Storage Capacity','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','RAM Capacity','Storage Capacity','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Non-Modular PSUs'      THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','RAM Capacity','Storage Capacity','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','RAM Capacity','Storage Capacity','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Switch Type','CPU Socket','RAM Capacity','Storage Capacity','Refresh Rate','Resolution','Kit Size','Speed')))

    -- Keyboards
    WHEN 'TKL Keyboards'         THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Full-Size Keyboards'   THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN '60% Keyboards'         THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN '75% Keyboards'         THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Wireless Keyboards'    THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Membrane Keyboards'    THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed','Switch Type')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed','Switch Type')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','Storage Capacity','RAM Capacity','CPU Socket','Refresh Rate','Resolution','Kit Size','Speed','Switch Type')))

    -- Mice
    WHEN 'Gaming Mice'           THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Ergonomic Mice'        THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','Wattage','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Refresh Rate','Resolution','Kit Size','Speed')))

    -- Headsets / Audio
    WHEN 'Gaming Headsets'          THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Wireless Gaming Headsets' THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Wired Gaming Headsets'    THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Wireless Headphones'      THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
    WHEN 'Earbuds & IEMs'           THEN
        (dc.attr1_id IS NULL OR dc.attr1_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr2_id IS NULL OR dc.attr2_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))
        AND (dc.attr3_id IS NULL OR dc.attr3_id NOT IN (SELECT id FROM ATTRIBUTES WHERE name IN ('Screen Size','CPU Socket','RAM Capacity','Storage Capacity','Switch Type','Wattage','Refresh Rate','Resolution','Kit Size','Speed')))

    ELSE TRUE

END;

CREATE INDEX ON variant_combos (combo_rn);

-- ---------------------------------------------------------------------------
-- 7. PRODUCT_VARIANTS
-- ---------------------------------------------------------------------------

INSERT INTO PRODUCT_VARIANTS
    (product_id, sku, brand_id, barcode, price, weight, status, created_at)
SELECT
    vc.product_id,

    UPPER(LEFT(REGEXP_REPLACE(vc.brand_name, '[^A-Za-z0-9]', '', 'g'), 4))
        || '-P' || LPAD(vc.product_id::TEXT, 7, '0')
        || '-C' || LPAD(vc.combo_rn::TEXT,  8, '0')          AS sku,

    vc.brand_id,

    LPAD((5000000000000 + vc.combo_rn)::TEXT, 13, '0')        AS barcode,

    GREATEST(
        ROUND((vc.base_price + (vc.combo_rn % 61) - 30)::NUMERIC, 2),
        1.00
    )                                                          AS price,

    ROUND(
        CASE
            WHEN p.name ILIKE '%GeForce%'   OR p.name ILIKE '%Radeon%'  THEN 1.20 + (vc.combo_rn % 10) * 0.05
            WHEN p.name ILIKE '%Monitor%'                                THEN 4.50 + (vc.combo_rn % 10) * 0.10
            WHEN p.name ILIKE '%Laptop%'                                 THEN 1.80 + (vc.combo_rn % 10) * 0.05
            WHEN p.name ILIKE '%NVMe%'      OR p.name ILIKE '%SSD%'     THEN 0.05 + (vc.combo_rn %  5) * 0.01
            WHEN p.name ILIKE '%HDD%'                                    THEN 0.45 + (vc.combo_rn %  5) * 0.02
            WHEN p.name ILIKE '%Keyboard%'                               THEN 0.90 + (vc.combo_rn % 10) * 0.02
            WHEN p.name ILIKE '%Mouse%'                                  THEN 0.08 + (vc.combo_rn % 10) * 0.005
            WHEN p.name ILIKE '%Headset%'   OR p.name ILIKE '%Headphone%' THEN 0.30 + (vc.combo_rn % 10) * 0.01
            WHEN p.name ILIKE '%iPhone%'    OR p.name ILIKE '%Galaxy S%' THEN 0.20 + (vc.combo_rn %  5) * 0.01
            ELSE                                                               0.30 + (vc.combo_rn % 10) * 0.02
        END::NUMERIC
    , 3)                                                       AS weight,

    CASE
        WHEN vc.combo_rn % 25 IN (0, 1) THEN 'pre-order'
        WHEN vc.combo_rn % 10 = 0       THEN 'discontinued'
        ELSE                                 'active'
    END                                                        AS status,

    NOW() - ((vc.combo_rn % 730) * INTERVAL '1 day')          AS created_at

FROM variant_combos vc
JOIN PRODUCTS p ON p.id = vc.product_id;

-- ---------------------------------------------------------------------------
-- 8. VARIANT_ATTRIBUTES
-- ---------------------------------------------------------------------------

-- attr1 — always present
INSERT INTO VARIANT_ATTRIBUTES (product_variant_id, attribute_id, attribute_value_id)
SELECT
    pv.id,
    vc.attr1_id,
    vc.av1_id
FROM   variant_combos    vc
JOIN   PRODUCT_VARIANTS  pv
       ON pv.barcode = LPAD((5000000000000 + vc.combo_rn)::TEXT, 13, '0')
WHERE  vc.attr1_id IS NOT NULL
  AND  vc.av1_id   IS NOT NULL;

-- attr2 — optional
INSERT INTO VARIANT_ATTRIBUTES (product_variant_id, attribute_id, attribute_value_id)
SELECT
    pv.id,
    vc.attr2_id,
    vc.av2_id
FROM   variant_combos    vc
JOIN   PRODUCT_VARIANTS  pv
       ON pv.barcode = LPAD((5000000000000 + vc.combo_rn)::TEXT, 13, '0')
WHERE  vc.attr2_id IS NOT NULL
  AND  vc.av2_id   IS NOT NULL;

-- attr3 — optional
INSERT INTO VARIANT_ATTRIBUTES (product_variant_id, attribute_id, attribute_value_id)
SELECT
    pv.id,
    vc.attr3_id,
    vc.av3_id
FROM   variant_combos    vc
JOIN   PRODUCT_VARIANTS  pv
       ON pv.barcode = LPAD((5000000000000 + vc.combo_rn)::TEXT, 13, '0')
WHERE  vc.attr3_id IS NOT NULL
  AND  vc.av3_id   IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 9. CLEANUP
-- ---------------------------------------------------------------------------

DROP TABLE stg_variant_dims;
DROP TABLE dim_combos;
DROP TABLE product_base_price;
DROP TABLE product_brand;
DROP TABLE variant_combos;

COMMIT;

-- ---------------------------------------------------------------------------
-- SANITY CHECK
-- ---------------------------------------------------------------------------

SELECT 'PRODUCT_VARIANTS'    AS tbl, COUNT(*) AS rows FROM PRODUCT_VARIANTS
UNION ALL
SELECT 'VARIANT_ATTRIBUTES',          COUNT(*)         FROM VARIANT_ATTRIBUTES
ORDER BY tbl;