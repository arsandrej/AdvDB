-- ============================================================================
-- TABLE: CATEGORIES (apparel only)
-- ============================================================================

INSERT INTO categories (name, parent_id)
VALUES ('goods', NULL);

INSERT INTO categories (name, parent_id)
VALUES ('apparel', (SELECT id FROM categories WHERE name = 'goods'));

INSERT INTO categories (name, parent_id)
SELECT 'clothing', id FROM categories WHERE name = 'apparel';

INSERT INTO categories (name, parent_id)
SELECT 'tops', id FROM categories WHERE name = 'clothing'
UNION ALL
SELECT 'bottoms', id FROM categories WHERE name = 'clothing'
UNION ALL
SELECT 'outerwear', id FROM categories WHERE name = 'clothing'
UNION ALL
SELECT 'underwear', id FROM categories WHERE name = 'clothing';

INSERT INTO categories (name, parent_id)
SELECT 'pants', id FROM categories WHERE name = 'bottoms'
UNION ALL
SELECT 'skirts', id FROM categories WHERE name = 'bottoms'
UNION ALL
SELECT 'tshirts', id FROM categories WHERE name = 'tops'
UNION ALL
SELECT 'shirts', id FROM categories WHERE name = 'tops'
UNION ALL
SELECT 'jackets', id FROM categories WHERE name = 'outerwear'
UNION ALL
SELECT 'hoodies', id FROM categories WHERE name = 'outerwear'
UNION ALL
SELECT 'socks', id FROM categories WHERE name = 'underwear'
UNION ALL
SELECT 'underpants', id FROM categories WHERE name = 'underwear';

-- ============================================================================
-- BRANDS (apparel relevant)
-- ============================================================================
INSERT INTO brands (name)
VALUES ('Nike'), ('Adidas'), ('Puma'), ('Under Armour'), ('Levi''s'),
       ('H&M'), ('Zara'), ('Hugo Boss'), ('Guess'), ('Uniqlo');

-- ============================================================================
-- PRODUCTS (apparel only)
-- ============================================================================
INSERT INTO products (name, description)
VALUES ('Jeans', 'Denim trousers used for general apparel wear'),
       ('Trousers', 'Formal or casual lower-body garment'),
       ('Chinos', 'Lightweight cotton trousers for casual or semi-formal use'),
       ('Joggers', 'Comfortable elastic waist athletic pants'),
       ('Shorts', 'Short length lower-body garment for warm weather'),
       ('Skirt', 'Lower-body garment worn in apparel fashion'),
       ('Tshirt', 'Short-sleeve upper-body cotton garment'),
       ('Shirt', 'Buttoned upper-body garment for formal or casual use'),
       ('Polo', 'Collared short-sleeve shirt for casual and sporty wear'),
       ('Tanktop', 'Sleeveless upper-body garment for warm climates'),
       ('Jacket', 'Light to heavy outerwear garment for protection and warmth'),
       ('Coat', 'Long outerwear garment for cold weather protection'),
       ('Hoodie', 'Soft pullover garment with hood'),
       ('Socks', 'Footwear inner garment for comfort and hygiene'),
       ('Underwear', 'Base layer garment worn under clothing');

-- ============================================================================
-- PRODUCT CATEGORIES MAPPING
-- ============================================================================
INSERT INTO product_categories (product_id, category_id)
SELECT p.id, c.id
FROM products p
JOIN categories c ON c.name = CASE p.name
    WHEN 'Jeans' THEN 'pants'
    WHEN 'Trousers' THEN 'pants'
    WHEN 'Chinos' THEN 'pants'
    WHEN 'Joggers' THEN 'pants'
    WHEN 'Shorts' THEN 'pants'
    WHEN 'Skirt' THEN 'skirts'
    WHEN 'Tshirt' THEN 'tshirts'
    WHEN 'Shirt' THEN 'shirts'
    WHEN 'Polo' THEN 'shirts'
    WHEN 'Tanktop' THEN 'shirts'
    WHEN 'Jacket' THEN 'jackets'
    WHEN 'Coat' THEN 'jackets'
    WHEN 'Hoodie' THEN 'hoodies'
    WHEN 'Socks' THEN 'socks'
    WHEN 'Underwear' THEN 'underpants'
END;

-- ============================================================================
-- ATTRIBUTES (apparel relevant)
-- ============================================================================
INSERT INTO attributes (name, data_type, unit, is_variant_attribute)
VALUES ('size', 'VARCHAR', NULL, TRUE),
       ('color', 'VARCHAR', NULL, TRUE),
       ('fit', 'VARCHAR', NULL, TRUE),
       ('gender', 'VARCHAR', NULL, TRUE),
       ('fabric_type', 'VARCHAR', NULL, TRUE),
       ('sleeve_length', 'VARCHAR', NULL, TRUE),
       ('season', 'VARCHAR', NULL, TRUE),
       ('material', 'VARCHAR', NULL, TRUE);

-- ============================================================================
-- ATTRIBUTE VALUES (apparel relevant)
-- ============================================================================
INSERT INTO attribute_values (attribute_id, value)
SELECT a.id, val
FROM (VALUES
    ('size', 'XS'), ('size', 'S'), ('size', 'M'), ('size', 'L'), ('size', 'XL'), ('size', 'XXL'),
    ('color', 'beige'), ('color', 'black'), ('color', 'blue'), ('color', 'camel'), ('color', 'green'),
    ('color', 'grey'), ('color', 'khaki'), ('color', 'navy'), ('color', 'olive'), ('color', 'red'),
    ('color', 'striped'), ('color', 'white'),
    ('fit', 'flared'), ('fit', 'loose'), ('fit', 'oversized'), ('fit', 'regular'), ('fit', 'relaxed'),
    ('fit', 'skinny'), ('fit', 'slim'), ('fit', 'tailored'), ('fit', 'tight'),
    ('gender', 'male'), ('gender', 'female'), ('gender', 'unisex'),
    ('fabric_type', 'cashmere'), ('fabric_type', 'cotton'), ('fabric_type', 'cotton_pique'),
    ('fabric_type', 'cotton_twill'), ('fabric_type', 'denim'), ('fabric_type', 'fleece'),
    ('fabric_type', 'leather'), ('fabric_type', 'linen'), ('fabric_type', 'nylon'),
    ('fabric_type', 'polyester'), ('fabric_type', 'raw_denim'), ('fabric_type', 'stretch_cotton'),
    ('fabric_type', 'stretch_denim'), ('fabric_type', 'wool'),
    ('sleeve_length', 'long'), ('sleeve_length', 'short'), ('sleeve_length', 'sleeveless'),
    ('season', 'spring'), ('season', 'summer'), ('season', 'autumn'), ('season', 'winter'),
    ('material', 'cotton'), ('material', 'wool'), ('material', 'polyester'), ('material', 'microfiber'), ('material', 'modal')
) AS t(attr_name, val)
JOIN attributes a ON a.name = t.attr_name;

-- ============================================================================
-- HELPER SEQUENCE FOR SKU
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS variant_sku_seq START 1;

-- ============================================================================
-- FUNCTION TO GET ATTRIBUTE VALUE ID
-- ============================================================================
CREATE OR REPLACE FUNCTION get_av_id(attr_name TEXT, attr_value TEXT)
RETURNS INTEGER LANGUAGE sql STABLE AS $$
    SELECT id FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = attr_name)
      AND value = attr_value;
$$;

-- ============================================================================
-- TEMPORARY HASH COLUMN FOR PRODUCT_VARIANTS (will be dropped later)
-- ============================================================================
ALTER TABLE product_variants ADD COLUMN temp_hash TEXT;

-- ============================================================================
-- 1. PANTS & SKIRTS
-- ============================================================================
CREATE TEMP TABLE temp_pants_skirts AS
SELECT
    p.id AS product_id,
    b.id AS brand_id,
    get_av_id('size', sz.val) AS size_av_id,
    get_av_id('color', col.val) AS color_av_id,
    get_av_id('fit', fit.val) AS fit_av_id,
    get_av_id('gender', gen.val) AS gender_av_id,
    get_av_id('fabric_type', fab.val) AS fabric_av_id,
    sz.val AS size_val,
    col.val AS color_val,
    fit.val AS fit_val,
    gen.val AS gender_val,
    fab.val AS fabric_val,
    md5(p.id::text || b.id::text || sz.val || col.val || fit.val || gen.val || fab.val) AS unique_hash
FROM products p
JOIN product_categories pc ON pc.product_id = p.id
JOIN categories c ON c.id = pc.category_id AND c.name IN ('pants', 'skirts')
CROSS JOIN (VALUES ('XS'),('S'),('M'),('L'),('XL'),('XXL')) AS sz(val)
CROSS JOIN (VALUES ('beige'),('black'),('blue'),('camel'),('green'),('grey'),('khaki'),('navy'),('olive'),('red'),('striped'),('white')) AS col(val)
CROSS JOIN (VALUES ('flared'),('loose'),('oversized'),('regular'),('relaxed'),('skinny'),('slim'),('tailored'),('tight')) AS fit(val)
CROSS JOIN (VALUES ('male'),('female'),('unisex')) AS gen(val)
CROSS JOIN (VALUES ('cotton'),('denim'),('polyester'),('stretch_denim'),('wool')) AS fab(val)
CROSS JOIN LATERAL (SELECT id FROM brands WHERE name IN ('Nike','Adidas','Levi''s','Uniqlo','Zara')) b
WHERE p.name IN ('Jeans','Trousers','Chinos','Joggers','Shorts','Skirt');

-- Insert variants with hash
INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status, temp_hash)
SELECT
    t.product_id,
    'SKU-' || nextval('variant_sku_seq'),
    t.brand_id,
    'BAR-' || currval('variant_sku_seq'),
    ROUND(
        CASE p.name
            WHEN 'Jeans' THEN 49.99
            WHEN 'Trousers' THEN 59.99
            WHEN 'Chinos' THEN 44.99
            WHEN 'Joggers' THEN 39.99
            WHEN 'Shorts' THEN 29.99
            WHEN 'Skirt' THEN 34.99
        END *
        CASE b.name
            WHEN 'Nike' THEN 1.2 WHEN 'Adidas' THEN 1.2 WHEN 'Levi''s' THEN 1.3
            WHEN 'Uniqlo' THEN 0.9 WHEN 'Zara' THEN 1.0 ELSE 1.0
        END *
        CASE t.size_val
            WHEN 'XS' THEN 0.9 WHEN 'S' THEN 0.95 WHEN 'M' THEN 1.0
            WHEN 'L' THEN 1.05 WHEN 'XL' THEN 1.1 WHEN 'XXL' THEN 1.15
        END
    , 2) AS price,
    CASE p.name
        WHEN 'Jeans' THEN 0.7 WHEN 'Trousers' THEN 0.6 WHEN 'Chinos' THEN 0.5
        WHEN 'Joggers' THEN 0.4 WHEN 'Shorts' THEN 0.3 WHEN 'Skirt' THEN 0.3
    END AS weight,
    'active',
    t.unique_hash
FROM temp_pants_skirts t
JOIN products p ON p.id = t.product_id
JOIN brands b ON b.id = t.brand_id;

-- Add product_variant_id column to temp table
ALTER TABLE temp_pants_skirts ADD COLUMN product_variant_id BIGINT;

-- Match using hash (and also product_id, brand_id as safety)
UPDATE temp_pants_skirts t
SET product_variant_id = v.id
FROM product_variants v
WHERE t.unique_hash = v.temp_hash
  AND t.product_id = v.product_id
  AND t.brand_id = v.brand_id;

-- Insert variant attributes (only where product_variant_id is not null)
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT product_variant_id, size_av_id, (SELECT id FROM attributes WHERE name = 'size')
FROM temp_pants_skirts WHERE product_variant_id IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT product_variant_id, color_av_id, (SELECT id FROM attributes WHERE name = 'color')
FROM temp_pants_skirts WHERE product_variant_id IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT product_variant_id, fit_av_id, (SELECT id FROM attributes WHERE name = 'fit')
FROM temp_pants_skirts WHERE product_variant_id IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT product_variant_id, gender_av_id, (SELECT id FROM attributes WHERE name = 'gender')
FROM temp_pants_skirts WHERE product_variant_id IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT product_variant_id, fabric_av_id, (SELECT id FROM attributes WHERE name = 'fabric_type')
FROM temp_pants_skirts WHERE product_variant_id IS NOT NULL
ON CONFLICT DO NOTHING;

DROP TABLE temp_pants_skirts;

-- ============================================================================
-- 2. TOPS (add sleeve_length)
-- ============================================================================
CREATE TEMP TABLE temp_tops AS
SELECT
    p.id AS product_id,
    b.id AS brand_id,
    get_av_id('size', sz.val) AS size_av_id,
    get_av_id('color', col.val) AS color_av_id,
    get_av_id('fit', fit.val) AS fit_av_id,
    get_av_id('gender', gen.val) AS gender_av_id,
    get_av_id('fabric_type', fab.val) AS fabric_av_id,
    get_av_id('sleeve_length', sl.val) AS sleeve_av_id,
    sz.val AS size_val,
    col.val AS color_val,
    fit.val AS fit_val,
    gen.val AS gender_val,
    fab.val AS fabric_val,
    sl.val AS sleeve_val,
    md5(p.id::text || b.id::text || sz.val || col.val || fit.val || gen.val || fab.val || sl.val) AS unique_hash
FROM products p
JOIN product_categories pc ON pc.product_id = p.id
JOIN categories c ON c.id = pc.category_id AND c.name IN ('tshirts', 'shirts')
CROSS JOIN (VALUES ('XS'),('S'),('M'),('L'),('XL'),('XXL')) AS sz(val)
CROSS JOIN (VALUES ('white'),('black'),('blue'),('red'),('grey'),('navy')) AS col(val)
CROSS JOIN (VALUES ('regular'),('slim'),('loose'),('oversized')) AS fit(val)
CROSS JOIN (VALUES ('male'),('female'),('unisex')) AS gen(val)
CROSS JOIN (VALUES ('cotton'),('polyester'),('cotton_pique'),('linen')) AS fab(val)
CROSS JOIN (VALUES ('short'),('long'),('sleeveless')) AS sl(val)
CROSS JOIN LATERAL (SELECT id FROM brands WHERE name IN ('Nike','Adidas','Uniqlo','H&M','Zara')) b
WHERE p.name IN ('Tshirt','Shirt','Polo','Tanktop');

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status, temp_hash)
SELECT
    t.product_id,
    'SKU-' || nextval('variant_sku_seq'),
    t.brand_id,
    'BAR-' || currval('variant_sku_seq'),
    ROUND(
        CASE p.name
            WHEN 'Tshirt' THEN 19.99 WHEN 'Shirt' THEN 34.99
            WHEN 'Polo' THEN 29.99 WHEN 'Tanktop' THEN 14.99
        END *
        CASE b.name WHEN 'Nike' THEN 1.3 WHEN 'Adidas' THEN 1.3 ELSE 1.0 END *
        CASE t.size_val WHEN 'XS' THEN 0.9 WHEN 'XXL' THEN 1.15 ELSE 1.0 END
    , 2) AS price,
    CASE p.name WHEN 'Tshirt' THEN 0.2 WHEN 'Shirt' THEN 0.25 WHEN 'Polo' THEN 0.22 ELSE 0.15 END AS weight,
    'active',
    t.unique_hash
FROM temp_tops t
JOIN products p ON p.id = t.product_id
JOIN brands b ON b.id = t.brand_id;

ALTER TABLE temp_tops ADD COLUMN product_variant_id BIGINT;

UPDATE temp_tops t
SET product_variant_id = v.id
FROM product_variants v
WHERE t.unique_hash = v.temp_hash
  AND t.product_id = v.product_id
  AND t.brand_id = v.brand_id;

INSERT INTO variant_attributes SELECT product_variant_id, size_av_id, (SELECT id FROM attributes WHERE name = 'size') FROM temp_tops WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, color_av_id, (SELECT id FROM attributes WHERE name = 'color') FROM temp_tops WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, fit_av_id, (SELECT id FROM attributes WHERE name = 'fit') FROM temp_tops WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, gender_av_id, (SELECT id FROM attributes WHERE name = 'gender') FROM temp_tops WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, fabric_av_id, (SELECT id FROM attributes WHERE name = 'fabric_type') FROM temp_tops WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, sleeve_av_id, (SELECT id FROM attributes WHERE name = 'sleeve_length') FROM temp_tops WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;

DROP TABLE temp_tops;

-- ============================================================================
-- 3. OUTERWEAR (add season)
-- ============================================================================
CREATE TEMP TABLE temp_outerwear AS
SELECT
    p.id AS product_id,
    b.id AS brand_id,
    get_av_id('size', sz.val) AS size_av_id,
    get_av_id('color', col.val) AS color_av_id,
    get_av_id('fit', fit.val) AS fit_av_id,
    get_av_id('fabric_type', fab.val) AS fabric_av_id,
    get_av_id('season', se.val) AS season_av_id,
    sz.val AS size_val,
    col.val AS color_val,
    fit.val AS fit_val,
    fab.val AS fabric_val,
    se.val AS season_val,
    md5(p.id::text || b.id::text || sz.val || col.val || fit.val || fab.val || se.val) AS unique_hash
FROM products p
JOIN product_categories pc ON pc.product_id = p.id
JOIN categories c ON c.id = pc.category_id AND c.name IN ('jackets', 'hoodies')
CROSS JOIN (VALUES ('S'),('M'),('L'),('XL'),('XXL')) AS sz(val)
CROSS JOIN (VALUES ('black'),('navy'),('grey'),('olive'),('brown')) AS col(val)
CROSS JOIN (VALUES ('regular'),('loose'),('oversized')) AS fit(val)
CROSS JOIN (VALUES ('cotton'),('polyester'),('wool'),('nylon')) AS fab(val)
CROSS JOIN (VALUES ('winter'),('autumn'),('spring')) AS se(val)
CROSS JOIN LATERAL (SELECT id FROM brands WHERE name IN ('Nike','Adidas','The North Face','Patagonia','Columbia')) b
WHERE p.name IN ('Jacket','Coat','Hoodie');

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status, temp_hash)
SELECT
    t.product_id,
    'SKU-' || nextval('variant_sku_seq'),
    t.brand_id,
    'BAR-' || currval('variant_sku_seq'),
    ROUND(
        CASE p.name WHEN 'Jacket' THEN 79.99 WHEN 'Coat' THEN 129.99 WHEN 'Hoodie' THEN 49.99 END *
        CASE b.name WHEN 'Nike' THEN 1.2 WHEN 'Adidas' THEN 1.2 ELSE 1.0 END *
        CASE t.size_val WHEN 'XXL' THEN 1.1 ELSE 1.0 END
    , 2) AS price,
    CASE p.name WHEN 'Jacket' THEN 0.9 WHEN 'Coat' THEN 1.2 WHEN 'Hoodie' THEN 0.5 END AS weight,
    'active',
    t.unique_hash
FROM temp_outerwear t
JOIN products p ON p.id = t.product_id
JOIN brands b ON b.id = t.brand_id;

ALTER TABLE temp_outerwear ADD COLUMN product_variant_id BIGINT;

UPDATE temp_outerwear t
SET product_variant_id = v.id
FROM product_variants v
WHERE t.unique_hash = v.temp_hash
  AND t.product_id = v.product_id
  AND t.brand_id = v.brand_id;

INSERT INTO variant_attributes SELECT product_variant_id, size_av_id, (SELECT id FROM attributes WHERE name = 'size') FROM temp_outerwear WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, color_av_id, (SELECT id FROM attributes WHERE name = 'color') FROM temp_outerwear WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, fit_av_id, (SELECT id FROM attributes WHERE name = 'fit') FROM temp_outerwear WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, fabric_av_id, (SELECT id FROM attributes WHERE name = 'fabric_type') FROM temp_outerwear WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, season_av_id, (SELECT id FROM attributes WHERE name = 'season') FROM temp_outerwear WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;

DROP TABLE temp_outerwear;

-- ============================================================================
-- 4. UNDERWEAR (Socks, Underwear)
-- ============================================================================
CREATE TEMP TABLE temp_underwear AS
SELECT
    p.id AS product_id,
    b.id AS brand_id,
    get_av_id('size', sz.val) AS size_av_id,
    get_av_id('color', col.val) AS color_av_id,
    get_av_id('material', mat.val) AS material_av_id,
    get_av_id('fit', fit.val) AS fit_av_id,
    sz.val AS size_val,
    col.val AS color_val,
    mat.val AS material_val,
    fit.val AS fit_val,
    md5(p.id::text || b.id::text || sz.val || col.val || mat.val || fit.val) AS unique_hash
FROM products p
JOIN product_categories pc ON pc.product_id = p.id
JOIN categories c ON c.id = pc.category_id AND c.name IN ('socks', 'underpants')
CROSS JOIN (VALUES ('S'),('M'),('L'),('XL')) AS sz(val)
CROSS JOIN (VALUES ('white'),('black'),('grey'),('blue')) AS col(val)
CROSS JOIN (VALUES ('cotton'),('polyester'),('wool'),('microfiber')) AS mat(val)
CROSS JOIN (VALUES ('regular'),('tight')) AS fit(val)
CROSS JOIN LATERAL (SELECT id FROM brands WHERE name IN ('Nike','Adidas','Hanes','Calvin Klein','Uniqlo')) b
WHERE p.name IN ('Socks','Underwear');

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status, temp_hash)
SELECT
    t.product_id,
    'SKU-' || nextval('variant_sku_seq'),
    t.brand_id,
    'BAR-' || currval('variant_sku_seq'),
    ROUND(
        CASE p.name WHEN 'Socks' THEN 9.99 WHEN 'Underwear' THEN 14.99 END *
        CASE b.name WHEN 'Calvin Klein' THEN 1.5 WHEN 'Nike' THEN 1.2 ELSE 1.0 END *
        CASE t.size_val WHEN 'XL' THEN 1.1 ELSE 1.0 END
    , 2) AS price,
    CASE p.name WHEN 'Socks' THEN 0.05 WHEN 'Underwear' THEN 0.1 END AS weight,
    'active',
    t.unique_hash
FROM temp_underwear t
JOIN products p ON p.id = t.product_id
JOIN brands b ON b.id = t.brand_id;

ALTER TABLE temp_underwear ADD COLUMN product_variant_id BIGINT;

UPDATE temp_underwear t
SET product_variant_id = v.id
FROM product_variants v
WHERE t.unique_hash = v.temp_hash
  AND t.product_id = v.product_id
  AND t.brand_id = v.brand_id;

INSERT INTO variant_attributes SELECT product_variant_id, size_av_id, (SELECT id FROM attributes WHERE name = 'size') FROM temp_underwear WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, color_av_id, (SELECT id FROM attributes WHERE name = 'color') FROM temp_underwear WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
INSERT INTO variant_attributes SELECT product_variant_id, material_av_id, (SELECT id FROM attributes WHERE name = 'material') FROM temp_underwear WHERE product_variant_id IS NOT NULL ON CONFLICT DO NOTHING;
-- Insert fit only for 'Underwear' product
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT t.product_variant_id, t.fit_av_id, (SELECT id FROM attributes WHERE name = 'fit')
FROM temp_underwear t
JOIN products p ON p.id = t.product_id
WHERE p.name = 'Underwear' AND t.product_variant_id IS NOT NULL
ON CONFLICT DO NOTHING;

DROP TABLE temp_underwear;

-- ============================================================================
-- CLEANUP: remove temporary hash column
-- ============================================================================
ALTER TABLE product_variants DROP COLUMN temp_hash;

-- ============================================================================
-- FINAL CHECK
-- ============================================================================
DO $$
DECLARE
    cnt BIGINT;
BEGIN
    SELECT COUNT(*) INTO cnt FROM product_variants;
    RAISE NOTICE 'Total product variants inserted: %', cnt;
END $$;