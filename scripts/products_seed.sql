-- ============================================================
--  WAREHOUSE INVENTORY — CLOTHING SEED DATA
--  PostgreSQL
--  Tables: BRANDS, CATEGORIES, ATTRIBUTES, ATTRIBUTE_VALUES,
--          PRODUCTS, PRODUCT_CATEGORIES, PRODUCT_VARIANTS,
--          PRODUCT_IMAGES, VARIANT_ATTRIBUTES
--
--  Summary:
--    6 brands · 14 categories (3-level) · 4 attributes · 30 attribute values
--    10 products · 12 product-category links · 23 variants
--    46 product images · 92 variant attributes
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. BRANDS  (6 clothing brands)
-- ------------------------------------------------------------
INSERT INTO BRANDS (name) VALUES
  ('Nike'),
  ('Adidas'),
  ('Levi''s'),
  ('Zara'),
  ('H&M'),
  ('Uniqlo');


-- ------------------------------------------------------------
-- 2. CATEGORIES  (3-level hierarchy)
--
--  Level 0:  Clothing
--  Level 1:  Men's Clothing · Women's Clothing · Kids' Clothing
--  Level 2:  T-Shirts · Jeans · Jackets · Hoodies & Sweatshirts ·
--            Knitwear · Trousers  (under Men's)
--            Dresses · Tops & Blouses · Jeans · Knitwear  (under Women's)
-- ------------------------------------------------------------

-- Level 0: single root
INSERT INTO CATEGORIES (name, parent_id) VALUES
  ('Clothing', NULL);

-- Level 1: direct children of Clothing
INSERT INTO CATEGORIES (name, parent_id)
SELECT v.name, root.id
FROM (VALUES
  ('Men''s Clothing'),
  ('Women''s Clothing'),
  ('Kids'' Clothing')
) AS v(name)
CROSS JOIN (
  SELECT id FROM CATEGORIES WHERE name = 'Clothing' AND parent_id IS NULL
) AS root;

-- Level 2: sub-categories under Men's Clothing
INSERT INTO CATEGORIES (name, parent_id)
SELECT v.name, parent.id
FROM (VALUES
  ('T-Shirts'),
  ('Jeans'),
  ('Jackets'),
  ('Hoodies & Sweatshirts'),
  ('Knitwear'),
  ('Trousers')
) AS v(name)
CROSS JOIN (
  SELECT id FROM CATEGORIES WHERE name = 'Men''s Clothing'
) AS parent;

-- Level 2: sub-categories under Women's Clothing
-- Note: 'Jeans' and 'Knitwear' intentionally reuse names — allowed
--       because (parent_id, name) is the unique key, not name alone.
INSERT INTO CATEGORIES (name, parent_id)
SELECT v.name, parent.id
FROM (VALUES
  ('Dresses'),
  ('Tops & Blouses'),
  ('Jeans'),
  ('Knitwear')
) AS v(name)
CROSS JOIN (
  SELECT id FROM CATEGORIES WHERE name = 'Women''s Clothing'
) AS parent;


-- ------------------------------------------------------------
-- 3. ATTRIBUTES
-- ------------------------------------------------------------
INSERT INTO ATTRIBUTES (name, data_type, unit, is_variant_attribute) VALUES
  ('Color',    'text', NULL, TRUE),   -- differentiates variants
  ('Size',     'text', NULL, TRUE),   -- differentiates variants
  ('Material', 'text', NULL, FALSE),  -- shared across all variants of a product
  ('Fit',      'text', NULL, FALSE);  -- shared across all variants of a product


-- ------------------------------------------------------------
-- 4. ATTRIBUTE_VALUES
-- ------------------------------------------------------------

-- Color
INSERT INTO ATTRIBUTE_VALUES (attribute_id, value)
SELECT a.id, v.value
FROM ATTRIBUTES a
CROSS JOIN (VALUES
  ('Black'), ('White'), ('Navy'), ('Grey'),
  ('Red'),   ('Blue'),  ('Green'),('Beige'),
  ('Olive'), ('Burgundy')
) AS v(value)
WHERE a.name = 'Color';

-- Size  (standard garment + denim waist sizes)
INSERT INTO ATTRIBUTE_VALUES (attribute_id, value)
SELECT a.id, v.value
FROM ATTRIBUTES a
CROSS JOIN (VALUES
  ('XS'), ('S'), ('M'), ('L'), ('XL'), ('XXL'),
  ('W28'), ('W30'), ('W32'), ('W34')
) AS v(value)
WHERE a.name = 'Size';

-- Material
INSERT INTO ATTRIBUTE_VALUES (attribute_id, value)
SELECT a.id, v.value
FROM ATTRIBUTES a
CROSS JOIN (VALUES
  ('100% Cotton'),
  ('Cotton-Polyester Blend'),
  ('Denim'),
  ('Merino Wool Blend'),
  ('Linen-Cotton Blend'),
  ('Fleece')
) AS v(value)
WHERE a.name = 'Material';

-- Fit
INSERT INTO ATTRIBUTE_VALUES (attribute_id, value)
SELECT a.id, v.value
FROM ATTRIBUTES a
CROSS JOIN (VALUES
  ('Regular Fit'),
  ('Slim Fit'),
  ('Relaxed Fit'),
  ('Oversized')
) AS v(value)
WHERE a.name = 'Fit';


-- ------------------------------------------------------------
-- 5. PRODUCTS  (10 clothing products)
-- ------------------------------------------------------------
INSERT INTO PRODUCTS (name, description) VALUES
  ('Classic Crew Neck T-Shirt',
   'Timeless everyday crew-neck tee crafted from premium ring-spun cotton.'),
  ('511 Slim Fit Jeans',
   'Iconic slim-fit jeans with a modern tapered leg and stretch denim.'),
  ('Essentials Zip-Up Hoodie',
   'Comfortable fleece-lined hoodie with a full-length zip and kangaroo pocket.'),
  ('Floral Midi Dress',
   'Lightweight floral-print midi dress with a flowy silhouette for warm seasons.'),
  ('Classic Polo Shirt',
   'Breathable piqué-knit polo with clean lines and a classic three-button placket.'),
  ('Striped Wrap Blouse',
   'Elegant striped blouse with a flattering wrap-style front and relaxed drape.'),
  ('Urban Bomber Jacket',
   'Casual urban bomber with a satin-feel shell, ribbed cuffs, and a full-zip front.'),
  ('Ribbed Knit Sweater',
   'Fine-knit merino wool-blend sweater featuring an all-over ribbed texture.'),
  ('Utility Cargo Trousers',
   'Relaxed-fit cargo trousers with multiple utility side pockets and a tapered hem.'),
  ('Trucker Denim Jacket',
   'Classic trucker-style jacket in rigid denim with signature chest pockets and button cuffs.');


-- ------------------------------------------------------------
-- 6. PRODUCT_CATEGORIES
--    Most products → one leaf category.
--    Classic Polo Shirt and Essentials Zip-Up Hoodie also appear
--    at the Men's Clothing level-1 category to demonstrate
--    multi-level categorisation.
-- ------------------------------------------------------------
INSERT INTO PRODUCT_CATEGORIES (product_id, category_id)
SELECT p.id, cat.id
FROM (VALUES
  -- product_name                    cat_name                parent_name
  ('Classic Crew Neck T-Shirt',  'T-Shirts',              'Men''s Clothing'),
  ('511 Slim Fit Jeans',         'Jeans',                 'Men''s Clothing'),
  ('Essentials Zip-Up Hoodie',   'Hoodies & Sweatshirts', 'Men''s Clothing'),
  ('Essentials Zip-Up Hoodie',   'Men''s Clothing',       'Clothing'),        -- also at level-1
  ('Floral Midi Dress',          'Dresses',               'Women''s Clothing'),
  ('Classic Polo Shirt',         'T-Shirts',              'Men''s Clothing'),
  ('Classic Polo Shirt',         'Men''s Clothing',       'Clothing'),        -- also at level-1
  ('Striped Wrap Blouse',        'Tops & Blouses',        'Women''s Clothing'),
  ('Urban Bomber Jacket',        'Jackets',               'Men''s Clothing'),
  ('Ribbed Knit Sweater',        'Knitwear',              'Women''s Clothing'),
  ('Utility Cargo Trousers',     'Trousers',              'Men''s Clothing'),
  ('Trucker Denim Jacket',       'Jackets',               'Men''s Clothing')
) AS pc(product_name, cat_name, parent_name)
JOIN PRODUCTS p ON p.name = pc.product_name
JOIN CATEGORIES cat
  ON  cat.name      = pc.cat_name
  AND cat.parent_id = (SELECT id FROM CATEGORIES WHERE name = pc.parent_name);


-- ------------------------------------------------------------
-- 7. PRODUCT_VARIANTS  (23 variants across 10 products)
--
--  SKU format:  {BRAND_ABBR}-{PRODUCT_ABBR}-{COLOR_ABBR}-{SIZE}
--  Statuses:    mostly 'active'; a few 'inactive' / 'discontinued'
-- ------------------------------------------------------------
INSERT INTO PRODUCT_VARIANTS (product_id, sku, brand_id, barcode, price, weight, status)
SELECT p.id, v.sku, b.id, v.barcode, v.price::NUMERIC, v.weight::NUMERIC, v.status
FROM (VALUES
  -- Classic Crew Neck T-Shirt  (Uniqlo)
  ('Classic Crew Neck T-Shirt', 'UNQ-CCNT-BLK-M',  'Uniqlo',  '4000000000001', 19.99, 0.20, 'active'),
  ('Classic Crew Neck T-Shirt', 'UNQ-CCNT-WHT-L',  'Uniqlo',  '4000000000002', 19.99, 0.20, 'active'),
  ('Classic Crew Neck T-Shirt', 'UNQ-CCNT-NVY-S',  'Uniqlo',  '4000000000003', 19.99, 0.20, 'active'),

  -- 511 Slim Fit Jeans  (Levi's)
  ('511 Slim Fit Jeans',        'LEV-511-BLK-W30', 'Levi''s', '4000000000004', 79.99, 0.82, 'active'),
  ('511 Slim Fit Jeans',        'LEV-511-BLU-W32', 'Levi''s', '4000000000005', 79.99, 0.85, 'active'),
  ('511 Slim Fit Jeans',        'LEV-511-GRY-W34', 'Levi''s', '4000000000006', 79.99, 0.88, 'discontinued'),

  -- Essentials Zip-Up Hoodie  (Nike)
  ('Essentials Zip-Up Hoodie',  'NIK-EZUH-BLK-M',  'Nike',    '4000000000007', 59.99, 0.50, 'active'),
  ('Essentials Zip-Up Hoodie',  'NIK-EZUH-GRY-L',  'Nike',    '4000000000008', 59.99, 0.55, 'active'),

  -- Floral Midi Dress  (Zara)
  ('Floral Midi Dress',         'ZAR-FMD-BEI-S',   'Zara',    '4000000000009', 49.99, 0.30, 'active'),
  ('Floral Midi Dress',         'ZAR-FMD-BLU-M',   'Zara',    '4000000000010', 49.99, 0.32, 'active'),

  -- Classic Polo Shirt  (Adidas)
  ('Classic Polo Shirt',        'ADI-CPOL-WHT-M',  'Adidas',  '4000000000011', 39.99, 0.25, 'active'),
  ('Classic Polo Shirt',        'ADI-CPOL-NVY-L',  'Adidas',  '4000000000012', 39.99, 0.25, 'active'),
  ('Classic Polo Shirt',        'ADI-CPOL-RED-S',  'Adidas',  '4000000000013', 39.99, 0.24, 'inactive'),

  -- Striped Wrap Blouse  (H&M)
  ('Striped Wrap Blouse',       'HM-SWB-WHT-S',    'H&M',     '4000000000014', 24.99, 0.20, 'active'),
  ('Striped Wrap Blouse',       'HM-SWB-BLU-M',    'H&M',     '4000000000015', 24.99, 0.22, 'active'),

  -- Urban Bomber Jacket  (Zara)
  ('Urban Bomber Jacket',       'ZAR-UBJ-BLK-M',   'Zara',    '4000000000016', 89.99, 0.90, 'active'),
  ('Urban Bomber Jacket',       'ZAR-UBJ-OLV-L',   'Zara',    '4000000000017', 89.99, 0.95, 'active'),

  -- Ribbed Knit Sweater  (Uniqlo)
  ('Ribbed Knit Sweater',       'UNQ-RKS-BEI-S',   'Uniqlo',  '4000000000018', 44.99, 0.45, 'active'),
  ('Ribbed Knit Sweater',       'UNQ-RKS-BRG-M',   'Uniqlo',  '4000000000019', 44.99, 0.47, 'active'),

  -- Utility Cargo Trousers  (H&M)
  ('Utility Cargo Trousers',    'HM-UCT-BEI-M',    'H&M',     '4000000000020', 34.99, 0.60, 'active'),
  ('Utility Cargo Trousers',    'HM-UCT-BLK-L',    'H&M',     '4000000000021', 34.99, 0.62, 'active'),

  -- Trucker Denim Jacket  (Levi's)
  ('Trucker Denim Jacket',      'LEV-TDJ-BLU-M',   'Levi''s', '4000000000022', 99.99, 1.00, 'active'),
  ('Trucker Denim Jacket',      'LEV-TDJ-BLK-L',   'Levi''s', '4000000000023', 99.99, 1.05, 'active')
) AS v(product_name, sku, brand_name, barcode, price, weight, status)
JOIN PRODUCTS p ON p.name = v.product_name
JOIN BRANDS   b ON b.name = v.brand_name;


-- ------------------------------------------------------------
-- 8. PRODUCT_IMAGES  (2 positions per variant = 46 images)
--    URL pattern: https://cdn.example.com/images/{sku}/img-{n}.jpg
-- ------------------------------------------------------------
INSERT INTO PRODUCT_IMAGES (product_variants_id, url, position)
SELECT
  pv.id,
  'https://cdn.example.com/images/' || pv.sku || '/img-' || pos.n || '.jpg',
  pos.n
FROM PRODUCT_VARIANTS pv
CROSS JOIN (VALUES (1), (2)) AS pos(n)
WHERE pv.product_id IN (
  SELECT id FROM PRODUCTS WHERE name IN (
    'Classic Crew Neck T-Shirt', '511 Slim Fit Jeans',  'Essentials Zip-Up Hoodie',
    'Floral Midi Dress',         'Classic Polo Shirt',  'Striped Wrap Blouse',
    'Urban Bomber Jacket',       'Ribbed Knit Sweater', 'Utility Cargo Trousers',
    'Trucker Denim Jacket'
  )
);


-- ------------------------------------------------------------
-- 9. VARIANT_ATTRIBUTES  (4 attributes × 23 variants = 92 rows)
--
--  Each variant carries:
--    Color    (is_variant_attribute = TRUE)  — differentiates variants
--    Size     (is_variant_attribute = TRUE)  — differentiates variants
--    Material (is_variant_attribute = FALSE) — same for all variants of a product
--    Fit      (is_variant_attribute = FALSE) — same for all variants of a product
--
--  The JOIN on ATTRIBUTE_VALUES satisfies the composite FK
--  FK_VARIANT_ATTRIBUTES_ATTRIBUTE_VALUE (attribute_id, id).
-- ------------------------------------------------------------
INSERT INTO VARIANT_ATTRIBUTES (product_variant_id, attribute_value_id, attribute_id)
SELECT pv.id, av.id, av.attribute_id
FROM (VALUES
  -- sku                  attribute    value
  -- Classic Crew Neck T-Shirt
  ('UNQ-CCNT-BLK-M',  'Color',    'Black'),
  ('UNQ-CCNT-BLK-M',  'Size',     'M'),
  ('UNQ-CCNT-BLK-M',  'Material', '100% Cotton'),
  ('UNQ-CCNT-BLK-M',  'Fit',      'Regular Fit'),
  ('UNQ-CCNT-WHT-L',  'Color',    'White'),
  ('UNQ-CCNT-WHT-L',  'Size',     'L'),
  ('UNQ-CCNT-WHT-L',  'Material', '100% Cotton'),
  ('UNQ-CCNT-WHT-L',  'Fit',      'Regular Fit'),
  ('UNQ-CCNT-NVY-S',  'Color',    'Navy'),
  ('UNQ-CCNT-NVY-S',  'Size',     'S'),
  ('UNQ-CCNT-NVY-S',  'Material', '100% Cotton'),
  ('UNQ-CCNT-NVY-S',  'Fit',      'Regular Fit'),

  -- 511 Slim Fit Jeans
  ('LEV-511-BLK-W30', 'Color',    'Black'),
  ('LEV-511-BLK-W30', 'Size',     'W30'),
  ('LEV-511-BLK-W30', 'Material', 'Denim'),
  ('LEV-511-BLK-W30', 'Fit',      'Slim Fit'),
  ('LEV-511-BLU-W32', 'Color',    'Blue'),
  ('LEV-511-BLU-W32', 'Size',     'W32'),
  ('LEV-511-BLU-W32', 'Material', 'Denim'),
  ('LEV-511-BLU-W32', 'Fit',      'Slim Fit'),
  ('LEV-511-GRY-W34', 'Color',    'Grey'),
  ('LEV-511-GRY-W34', 'Size',     'W34'),
  ('LEV-511-GRY-W34', 'Material', 'Denim'),
  ('LEV-511-GRY-W34', 'Fit',      'Slim Fit'),

  -- Essentials Zip-Up Hoodie
  ('NIK-EZUH-BLK-M',  'Color',    'Black'),
  ('NIK-EZUH-BLK-M',  'Size',     'M'),
  ('NIK-EZUH-BLK-M',  'Material', 'Fleece'),
  ('NIK-EZUH-BLK-M',  'Fit',      'Regular Fit'),
  ('NIK-EZUH-GRY-L',  'Color',    'Grey'),
  ('NIK-EZUH-GRY-L',  'Size',     'L'),
  ('NIK-EZUH-GRY-L',  'Material', 'Fleece'),
  ('NIK-EZUH-GRY-L',  'Fit',      'Regular Fit'),

  -- Floral Midi Dress
  ('ZAR-FMD-BEI-S',   'Color',    'Beige'),
  ('ZAR-FMD-BEI-S',   'Size',     'S'),
  ('ZAR-FMD-BEI-S',   'Material', 'Linen-Cotton Blend'),
  ('ZAR-FMD-BEI-S',   'Fit',      'Regular Fit'),
  ('ZAR-FMD-BLU-M',   'Color',    'Blue'),
  ('ZAR-FMD-BLU-M',   'Size',     'M'),
  ('ZAR-FMD-BLU-M',   'Material', 'Linen-Cotton Blend'),
  ('ZAR-FMD-BLU-M',   'Fit',      'Regular Fit'),

  -- Classic Polo Shirt
  ('ADI-CPOL-WHT-M',  'Color',    'White'),
  ('ADI-CPOL-WHT-M',  'Size',     'M'),
  ('ADI-CPOL-WHT-M',  'Material', '100% Cotton'),
  ('ADI-CPOL-WHT-M',  'Fit',      'Regular Fit'),
  ('ADI-CPOL-NVY-L',  'Color',    'Navy'),
  ('ADI-CPOL-NVY-L',  'Size',     'L'),
  ('ADI-CPOL-NVY-L',  'Material', '100% Cotton'),
  ('ADI-CPOL-NVY-L',  'Fit',      'Regular Fit'),
  ('ADI-CPOL-RED-S',  'Color',    'Red'),
  ('ADI-CPOL-RED-S',  'Size',     'S'),
  ('ADI-CPOL-RED-S',  'Material', '100% Cotton'),
  ('ADI-CPOL-RED-S',  'Fit',      'Regular Fit'),

  -- Striped Wrap Blouse
  ('HM-SWB-WHT-S',    'Color',    'White'),
  ('HM-SWB-WHT-S',    'Size',     'S'),
  ('HM-SWB-WHT-S',    'Material', 'Linen-Cotton Blend'),
  ('HM-SWB-WHT-S',    'Fit',      'Relaxed Fit'),
  ('HM-SWB-BLU-M',    'Color',    'Blue'),
  ('HM-SWB-BLU-M',    'Size',     'M'),
  ('HM-SWB-BLU-M',    'Material', 'Linen-Cotton Blend'),
  ('HM-SWB-BLU-M',    'Fit',      'Relaxed Fit'),

  -- Urban Bomber Jacket
  ('ZAR-UBJ-BLK-M',   'Color',    'Black'),
  ('ZAR-UBJ-BLK-M',   'Size',     'M'),
  ('ZAR-UBJ-BLK-M',   'Material', 'Cotton-Polyester Blend'),
  ('ZAR-UBJ-BLK-M',   'Fit',      'Regular Fit'),
  ('ZAR-UBJ-OLV-L',   'Color',    'Olive'),
  ('ZAR-UBJ-OLV-L',   'Size',     'L'),
  ('ZAR-UBJ-OLV-L',   'Material', 'Cotton-Polyester Blend'),
  ('ZAR-UBJ-OLV-L',   'Fit',      'Regular Fit'),

  -- Ribbed Knit Sweater
  ('UNQ-RKS-BEI-S',   'Color',    'Beige'),
  ('UNQ-RKS-BEI-S',   'Size',     'S'),
  ('UNQ-RKS-BEI-S',   'Material', 'Merino Wool Blend'),
  ('UNQ-RKS-BEI-S',   'Fit',      'Regular Fit'),
  ('UNQ-RKS-BRG-M',   'Color',    'Burgundy'),
  ('UNQ-RKS-BRG-M',   'Size',     'M'),
  ('UNQ-RKS-BRG-M',   'Material', 'Merino Wool Blend'),
  ('UNQ-RKS-BRG-M',   'Fit',      'Regular Fit'),

  -- Utility Cargo Trousers
  ('HM-UCT-BEI-M',    'Color',    'Beige'),
  ('HM-UCT-BEI-M',    'Size',     'M'),
  ('HM-UCT-BEI-M',    'Material', 'Cotton-Polyester Blend'),
  ('HM-UCT-BEI-M',    'Fit',      'Relaxed Fit'),
  ('HM-UCT-BLK-L',    'Color',    'Black'),
  ('HM-UCT-BLK-L',    'Size',     'L'),
  ('HM-UCT-BLK-L',    'Material', 'Cotton-Polyester Blend'),
  ('HM-UCT-BLK-L',    'Fit',      'Relaxed Fit'),

  -- Trucker Denim Jacket
  ('LEV-TDJ-BLU-M',   'Color',    'Blue'),
  ('LEV-TDJ-BLU-M',   'Size',     'M'),
  ('LEV-TDJ-BLU-M',   'Material', 'Denim'),
  ('LEV-TDJ-BLU-M',   'Fit',      'Regular Fit'),
  ('LEV-TDJ-BLK-L',   'Color',    'Black'),
  ('LEV-TDJ-BLK-L',   'Size',     'L'),
  ('LEV-TDJ-BLK-L',   'Material', 'Denim'),
  ('LEV-TDJ-BLK-L',   'Fit',      'Regular Fit')
) AS va(sku, attr_name, attr_value)
JOIN PRODUCT_VARIANTS  pv ON pv.sku            = va.sku
JOIN ATTRIBUTES         a ON a.name            = va.attr_name
JOIN ATTRIBUTE_VALUES  av ON av.attribute_id   = a.id
                         AND av.value          = va.attr_value;

COMMIT;

-- ============================================================
--  QUICK SANITY CHECKS  (uncomment and run after inserting)
-- ============================================================
-- SELECT COUNT(*) FROM BRANDS;              -- expected:  6
-- SELECT COUNT(*) FROM CATEGORIES;          -- expected: 14  (1+3+6+4)
-- SELECT COUNT(*) FROM ATTRIBUTES;          -- expected:  4
-- SELECT COUNT(*) FROM ATTRIBUTE_VALUES;    -- expected: 30  (10+10+6+4)
-- SELECT COUNT(*) FROM PRODUCTS;            -- expected: 10
-- SELECT COUNT(*) FROM PRODUCT_CATEGORIES;  -- expected: 12
-- SELECT COUNT(*) FROM PRODUCT_VARIANTS;    -- expected: 23
-- SELECT COUNT(*) FROM PRODUCT_IMAGES;      -- expected: 46
-- SELECT COUNT(*) FROM VARIANT_ATTRIBUTES;  -- expected: 92

-- Full product overview (variants + their resolved attribute values):
-- SELECT
--     p.name                                    AS product,
--     pv.sku,
--     b.name                                    AS brand,
--     MAX(CASE WHEN a.name = 'Color'    THEN av.value END) AS color,
--     MAX(CASE WHEN a.name = 'Size'     THEN av.value END) AS size,
--     MAX(CASE WHEN a.name = 'Material' THEN av.value END) AS material,
--     MAX(CASE WHEN a.name = 'Fit'      THEN av.value END) AS fit,
--     pv.price,
--     pv.status
-- FROM PRODUCTS p
-- JOIN PRODUCT_VARIANTS  pv ON pv.product_id       = p.id
-- JOIN BRANDS             b ON b.id                = pv.brand_id
-- JOIN VARIANT_ATTRIBUTES va ON va.product_variant_id = pv.id
-- JOIN ATTRIBUTE_VALUES  av ON av.id               = va.attribute_value_id
-- JOIN ATTRIBUTES         a ON a.id                = va.attribute_id
-- GROUP BY p.name, pv.sku, b.name, pv.price, pv.status
-- ORDER BY p.name, pv.sku;
