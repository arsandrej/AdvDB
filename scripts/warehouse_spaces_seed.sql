-- ============================================================
--  WAREHOUSE INVENTORY MANAGEMENT SYSTEM — SEED DATA
--  PostgreSQL  |  ~408 locations, ~408 bins
--  Run order: WAREHOUSES → SECTIONS → LOCATIONS → BINS
-- ============================================================


-- ------------------------------------------------------------
-- 1. WAREHOUSES  (5 records)
-- ------------------------------------------------------------
INSERT INTO WAREHOUSES (name, address, city, country) VALUES
  ('Central Depot',             '123 Industrial Blvd',       'New York',     'United States'),
  ('West Coast Hub',            '456 Harbor Way',            'Los Angeles',  'United States'),
  ('Euro Logistics Center',     'Industriestrasse 78',       'Berlin',       'Germany'),
  ('Asia Pacific Warehouse',    '12 Jurong East Avenue',     'Singapore',    'Singapore'),
  ('Nordic Storage Facility',   'Logistikvägen 5',           'Stockholm',    'Sweden');


-- ------------------------------------------------------------
-- 2. SECTIONS  (17 records — 3-4 per warehouse)
-- ------------------------------------------------------------
INSERT INTO SECTIONS (warehouse_id, name, description)
SELECT w.id, s.name, s.description
FROM WAREHOUSES w
JOIN (VALUES
  -- Warehouse: Central Depot
  ('Central Depot',       'Electronics',      'High-value electronic components and consumer devices'),
  ('Central Depot',       'Apparel',          'Clothing, footwear, and textile products'),
  ('Central Depot',       'Bulk Storage',     'Large-volume non-perishable goods and raw materials'),
  ('Central Depot',       'Hazmat',           'Hazardous materials requiring special handling and compliance'),

  -- Warehouse: West Coast Hub
  ('West Coast Hub',      'Refrigerated',     'Temperature-controlled perishable and pharmaceutical goods'),
  ('West Coast Hub',      'Dry Goods',        'Non-perishable food, beverages, and household items'),
  ('West Coast Hub',      'Oversized',        'Large and bulky items requiring special equipment'),
  ('West Coast Hub',      'Returns',          'Customer returns, refurbished, and inspection-pending items'),

  -- Warehouse: Euro Logistics Center
  ('Euro Logistics Center','Industrial',       'Heavy industrial machinery parts, tools, and raw inputs'),
  ('Euro Logistics Center','Consumer Goods',   'Everyday packaged consumer products'),
  ('Euro Logistics Center','Automotive',       'Vehicle parts, fluids, and accessories'),

  -- Warehouse: Asia Pacific Warehouse
  ('Asia Pacific Warehouse','Technology',      'IT hardware, accessories, and components'),
  ('Asia Pacific Warehouse','Textiles',        'Fabric rolls, garment materials, and sewing supplies'),
  ('Asia Pacific Warehouse','Food & Beverage', 'Packaged food products, snacks, and beverages'),

  -- Warehouse: Nordic Storage Facility
  ('Nordic Storage Facility','Cold Storage',   'Frozen and deep-refrigerated product lines'),
  ('Nordic Storage Facility','General',        'Mixed general merchandise and seasonal goods'),
  ('Nordic Storage Facility','Heavy Equipment','Industrial machinery, cranes, and large tools')
) AS s(warehouse_name, name, description)
  ON w.name = s.warehouse_name;


-- ------------------------------------------------------------
-- 3. LOCATIONS  (generate_series: 3 rows × 4 cols × 2 levels
--                = 24 locations per section, ~408 total)
--
--  location_code format:  SEC{section_id:03d}-R{row}C{col}L{lvl}
--  e.g. SEC001-R1C3L2
-- ------------------------------------------------------------
INSERT INTO LOCATIONS (section_id, row_number, column_number, level_number, location_code)
SELECT
    s.id                                                               AS section_id,
    r.row_number,
    c.column_number,
    l.level_number,
    'SEC' || LPAD(s.id::TEXT, 3, '0')
        || '-R' || r.row_number
        || 'C' || c.column_number
        || 'L' || l.level_number                                       AS location_code
FROM       SECTIONS                          s
CROSS JOIN generate_series(1, 3)  AS r(row_number)
CROSS JOIN generate_series(1, 4)  AS c(column_number)
CROSS JOIN generate_series(1, 2)  AS l(level_number);


-- ------------------------------------------------------------
-- 4. BINS  (one bin per location — capacity cycles through
--           realistic values based on section characteristics)
--
--  bin_code format:  BIN-{location_code}
--  capacity:         50–400 units, driven by section type
-- ------------------------------------------------------------
INSERT INTO BINS (location_id, bin_code, capacity)
SELECT
    l.id                                    AS location_id,
    'BIN-' || l.location_code               AS bin_code,
    -- Capacity varies by section name to reflect real-world sizing:
    --   small precision bins  → Electronics / Technology / Hazmat
    --   medium standard bins  → Apparel / Textiles / Returns / Food & Beverage
    --   large volume bins     → Bulk Storage / Dry Goods / General / Cold Storage
    --   heavy-load bins       → Industrial / Automotive / Oversized / Heavy Equipment
    CASE sec.name
        WHEN 'Electronics'      THEN (ARRAY[50,  75,  100, 75 ])[1 + (l.id % 4)]
        WHEN 'Technology'       THEN (ARRAY[50,  75,  100, 50 ])[1 + (l.id % 4)]
        WHEN 'Hazmat'           THEN (ARRAY[25,  50,  25,  50 ])[1 + (l.id % 4)]
        WHEN 'Apparel'          THEN (ARRAY[100, 150, 200, 150])[1 + (l.id % 4)]
        WHEN 'Textiles'         THEN (ARRAY[100, 200, 150, 100])[1 + (l.id % 4)]
        WHEN 'Returns'          THEN (ARRAY[100, 100, 150, 200])[1 + (l.id % 4)]
        WHEN 'Food & Beverage'  THEN (ARRAY[150, 200, 150, 100])[1 + (l.id % 4)]
        WHEN 'Refrigerated'     THEN (ARRAY[100, 150, 100, 150])[1 + (l.id % 4)]
        WHEN 'Cold Storage'     THEN (ARRAY[200, 250, 200, 150])[1 + (l.id % 4)]
        WHEN 'Bulk Storage'     THEN (ARRAY[300, 400, 350, 300])[1 + (l.id % 4)]
        WHEN 'Dry Goods'        THEN (ARRAY[250, 300, 350, 250])[1 + (l.id % 4)]
        WHEN 'General'          THEN (ARRAY[200, 250, 300, 200])[1 + (l.id % 4)]
        WHEN 'Industrial'       THEN (ARRAY[200, 300, 400, 300])[1 + (l.id % 4)]
        WHEN 'Automotive'       THEN (ARRAY[150, 200, 250, 200])[1 + (l.id % 4)]
        WHEN 'Oversized'        THEN (ARRAY[400, 300, 400, 350])[1 + (l.id % 4)]
        WHEN 'Heavy Equipment'  THEN (ARRAY[300, 400, 300, 400])[1 + (l.id % 4)]
        WHEN 'Consumer Goods'   THEN (ARRAY[150, 200, 150, 250])[1 + (l.id % 4)]
        ELSE                         (ARRAY[100, 150, 200, 100])[1 + (l.id % 4)]
    END                                     AS capacity
FROM  LOCATIONS l
JOIN  SECTIONS  sec ON sec.id = l.section_id;


-- ============================================================
--  QUICK SANITY CHECKS  (run these after inserting)
-- ============================================================
SELECT COUNT(*) FROM WAREHOUSES;   -- expected:   5
SELECT COUNT(*) FROM SECTIONS;     -- expected:  17
SELECT COUNT(*) FROM LOCATIONS;    -- expected: 408  (17 × 3 × 4 × 2)
SELECT COUNT(*) FROM BINS;         -- expected: 408

--Sample: overview per warehouse
SELECT w.name, COUNT(DISTINCT s.id) AS sections,
       COUNT(DISTINCT l.id) AS locations,
       COUNT(DISTINCT b.id) AS bins,
       SUM(b.capacity)      AS total_capacity
FROM   WAREHOUSES w
JOIN   SECTIONS   s ON s.warehouse_id = w.id
JOIN   LOCATIONS  l ON l.section_id   = s.id
JOIN   BINS       b ON b.location_id  = l.id
GROUP BY w.name
ORDER BY w.name;
