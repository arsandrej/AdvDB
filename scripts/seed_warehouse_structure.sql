-- =============================================================
-- Warehouse Structure Seed Script
-- Populates: WAREHOUSES, SECTIONS, LOCATIONS, BINS
--
-- Layout per warehouse:
--   6 sections × (20 columns × 20 rows × 5 levels) locations
--   Each location → 5 bins
--
-- Strategy:
--   1. COPY CSV data into temp staging tables
--   2. INSERT into target tables using set-based SQL
--      (generate_series cross joins — no row-by-row loops)
-- =============================================================

BEGIN;

-- -----------------------------------------------------------
-- 1. Staging tables for CSV data
-- -----------------------------------------------------------

CREATE TEMP TABLE stg_warehouses (
    name        VARCHAR(63),
    address     TEXT,
    city        VARCHAR(63),
    country     VARCHAR(63)
) ON COMMIT DROP;

CREATE TEMP TABLE stg_sections (
    section_name VARCHAR(63),
    description  TEXT
) ON COMMIT DROP;

-- -----------------------------------------------------------
-- 2. Load CSVs
-- -----------------------------------------------------------

COPY stg_warehouses (name, address, city, country)
    FROM '/csv/warehouses.csv'
    WITH (FORMAT CSV, HEADER true);

COPY stg_sections (section_name, description)
    FROM '/csv/sections.csv'
    WITH (FORMAT CSV, HEADER true);

-- -----------------------------------------------------------
-- 3. Insert WAREHOUSES
-- -----------------------------------------------------------

INSERT INTO WAREHOUSES (name, address, city, country)
SELECT name, address, city, country
FROM   stg_warehouses
ON CONFLICT (name) DO NOTHING;

-- -----------------------------------------------------------
-- 4. Insert SECTIONS
--    Every warehouse gets every section from the staging table.
--    section_name is scoped per warehouse so uniqueness holds.
-- -----------------------------------------------------------

INSERT INTO SECTIONS (warehouse_id, name, description)
SELECT
    w.id                AS warehouse_id,
    s.section_name      AS name,
    s.description       AS description
FROM
    WAREHOUSES   w
    CROSS JOIN stg_sections s
WHERE
    w.name IN (SELECT name FROM stg_warehouses)
ON CONFLICT (warehouse_id, name) DO NOTHING;

-- -----------------------------------------------------------
-- 5. Insert LOCATIONS
--    generate_series produces all (row, col, level) combos.
--    location_code format: <warehouse_abbrev>-<section>-R<rr>C<cc>L<ll>
--    e.g.  ALC-A-R01C01L1
-- -----------------------------------------------------------

INSERT INTO LOCATIONS (section_id, row_number, column_number, level_number, location_code)
SELECT
    sec.id                                          AS section_id,
    r.row_number,
    c.col_number                                    AS column_number,
    l.lvl_number                                    AS level_number,
    -- Abbreviate warehouse name to first letters of each word (max 4 chars)
    upper(
        left(
            regexp_replace(w.name, '\s+', '', 'g'),
            4
        )
    )
    || '-'
    || upper(left(sec.name, 3))
    || '-R' || lpad(r.row_number::text, 2, '0')
    || 'C'  || lpad(c.col_number::text, 2, '0')
    || 'L'  || l.lvl_number::text                  AS location_code
FROM
    SECTIONS                                sec
    JOIN  WAREHOUSES                        w   ON w.id = sec.warehouse_id
    CROSS JOIN generate_series(1, 20)  AS  r(row_number)
    CROSS JOIN generate_series(1, 20)  AS  c(col_number)
    CROSS JOIN generate_series(1,  5)  AS  l(lvl_number)
WHERE
    w.name IN (SELECT name FROM stg_warehouses)
ON CONFLICT (location_code) DO NOTHING;

-- -----------------------------------------------------------
-- 6. Insert BINS
--    5 bins per location, bin_code = <location_code>-B<n>
-- -----------------------------------------------------------

INSERT INTO BINS (location_id, bin_code, capacity)
SELECT
    loc.id                                         AS location_id,
    loc.location_code || '-B' || b.bin_num         AS bin_code,
    -- Capacity varies by level: higher levels → smaller capacity
    CASE loc.level_number
        WHEN 1 THEN 100
        WHEN 2 THEN  90
        WHEN 3 THEN  80
        WHEN 4 THEN  60
        WHEN 5 THEN  40
    END                                            AS capacity
FROM
    LOCATIONS                              loc
    JOIN  SECTIONS                         sec ON sec.id = loc.section_id
    JOIN  WAREHOUSES                       w   ON w.id  = sec.warehouse_id
    CROSS JOIN generate_series(1, 5)  AS  b(bin_num)
WHERE
    w.name IN (SELECT name FROM stg_warehouses)
ON CONFLICT (bin_code) DO NOTHING;


-- -----------------------------------------------------------
-- 7. Verification summary
-- -----------------------------------------------------------

/*SELECT 'WAREHOUSES' AS "Table",  COUNT(*) AS "Rows" FROM WAREHOUSES
    WHERE name IN (SELECT name FROM stg_warehouses)  -- stg is gone; just totals
UNION ALL
SELECT 'SECTIONS',   COUNT(*) FROM SECTIONS
UNION ALL
SELECT 'LOCATIONS',  COUNT(*) FROM LOCATIONS
UNION ALL
SELECT 'BINS',       COUNT(*) FROM BINS;*/


COMMIT;
