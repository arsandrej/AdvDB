--============================================================================
-- TABLE: CATEGORIES
-- ============================================================================

INSERT INTO categories (name, parent_id)
VALUES ('goods', NULL);
-- id 1

-- Level 1
INSERT INTO categories (name, parent_id)
VALUES ('apparel', (SELECT id FROM categories WHERE name = 'goods')),
       ('electronics', (SELECT id FROM categories WHERE name = 'goods')),
       ('home_goods', (SELECT id FROM categories WHERE name = 'goods')),
       ('industrial_supplies', (SELECT id FROM categories WHERE name = 'goods')),
       ('tools_hardware', (SELECT id FROM categories WHERE name = 'goods'));

-- Level 2
INSERT INTO categories (name, parent_id)
SELECT 'clothing', id
FROM categories
WHERE name = 'apparel'
UNION ALL
SELECT 'footwear', id
FROM categories
WHERE name = 'apparel'
UNION ALL
SELECT 'accessories', id
FROM categories
WHERE name = 'apparel'
UNION ALL
SELECT 'laptops', id
FROM categories
WHERE name = 'electronics'
UNION ALL
SELECT 'desktops', id
FROM categories
WHERE name = 'electronics'
UNION ALL
SELECT 'components', id
FROM categories
WHERE name = 'electronics'
UNION ALL
SELECT 'peripherals', id
FROM categories
WHERE name = 'electronics'
UNION ALL
SELECT 'audio', id
FROM categories
WHERE name = 'electronics'
UNION ALL
SELECT 'video', id
FROM categories
WHERE name = 'electronics'
UNION ALL
SELECT 'networking', id
FROM categories
WHERE name = 'electronics'
UNION ALL
SELECT 'storage', id
FROM categories
WHERE name = 'electronics'
UNION ALL
SELECT 'furniture', id
FROM categories
WHERE name = 'home_goods'
UNION ALL
SELECT 'kitchen_accessories', id
FROM categories
WHERE name = 'home_goods'
UNION ALL
SELECT 'cleaning_supplies', id
FROM categories
WHERE name = 'home_goods'
UNION ALL
SELECT 'decor', id
FROM categories
WHERE name = 'home_goods'
UNION ALL
SELECT 'fasteners', id
FROM categories
WHERE name = 'tools_hardware'
UNION ALL
SELECT 'hand_tools', id
FROM categories
WHERE name = 'tools_hardware'
UNION ALL
SELECT 'power_tools', id
FROM categories
WHERE name = 'tools_hardware'
UNION ALL
SELECT 'safety_equipment', id
FROM categories
WHERE name = 'tools_hardware';

-- Level 3
INSERT INTO categories (name, parent_id)
SELECT 'tops', id
FROM categories
WHERE name = 'clothing'
UNION ALL
SELECT 'bottoms', id
FROM categories
WHERE name = 'clothing'
UNION ALL
SELECT 'outerwear', id
FROM categories
WHERE name = 'clothing'
UNION ALL
SELECT 'underwear', id
FROM categories
WHERE name = 'clothing'
UNION ALL
SELECT 'keyboards', id
FROM categories
WHERE name = 'peripherals'
UNION ALL
SELECT 'mice', id
FROM categories
WHERE name = 'peripherals'
UNION ALL
SELECT 'monitors', id
FROM categories
WHERE name = 'video'
UNION ALL
SELECT 'headphones', id
FROM categories
WHERE name = 'audio'
UNION ALL
SELECT 'speakers', id
FROM categories
WHERE name = 'audio'
UNION ALL
SELECT 'routers', id
FROM categories
WHERE name = 'networking'
UNION ALL
SELECT 'drives', id
FROM categories
WHERE name = 'storage';

-- Level 4 (leaf categories)
INSERT INTO categories (name, parent_id)
SELECT 'pants', id
FROM categories
WHERE name = 'bottoms'
UNION ALL
SELECT 'shirts', id
FROM categories
WHERE name = 'tops'
UNION ALL
SELECT 'tshirts', id
FROM categories
WHERE name = 'tops'
UNION ALL
SELECT 'dresses', id
FROM categories
WHERE name = 'clothing'
UNION ALL
SELECT 'skirts', id
FROM categories
WHERE name = 'bottoms'
UNION ALL
SELECT 'jackets', id
FROM categories
WHERE name = 'outerwear'
UNION ALL
SELECT 'hoodies', id
FROM categories
WHERE name = 'outerwear'
UNION ALL
SELECT 'socks', id
FROM categories
WHERE name = 'underwear'
UNION ALL
SELECT 'underpants', id
FROM categories
WHERE name = 'underwear';

--==========================
--BRANDS
--==========================
INSERT INTO brands (name)
VALUES ('Nike'),
       ('Adidas'),
       ('Puma'),
       ('Under Armour'),
       ('Levi''s'),
       ('H&M'),
       ('Zara'),
       ('Hugo Boss'),
       ('Guess'),
       ('Uniqlo'),
       ('Apple'),
       ('Samsung'),
       ('Sony'),
       ('LG'),
       ('Dell'),
       ('HP'),
       ('Lenovo'),
       ('Asus'),
       ('IKEA'),
       ('Philips'),
       ('Tefal'),
       ('KitchenAid'),
       ('Dyson'),
       ('Bosch'),
       ('3M'),
       ('Makita'),
       ('Stanley'),
       ('Hilti'),
       ('DeWalt'),
       ('Milwaukee'),
       ('Black+Decker'),
       ('Craftsman'),
       ('Ryobi');


--=========================
--PRODUCTS
--=========================
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
       ('Underwear', 'Base layer garment worn under clothing'),
       ('Laptop', 'Portable computing device'),
       ('Desktop', 'Stationary computing system'),
       ('Tablet', 'Touch-based portable computing device'),
       ('Monitor', 'Display screen for computing systems'),
       ('Keyboard', 'Input device for typing'),
       ('Mouse', 'Pointing input device'),
       ('Headphones', 'Personal audio listening device'),
       ('Speakers', 'Audio output device'),
       ('Router', 'Network device for internet distribution'),
       ('SSD', 'Solid state data storage device'),
       ('HDD', 'Hard disk data storage device'),
       ('USB Drive', 'Portable flash storage device'),
       ('Hammer', 'Hand tool used for striking and driving objects'),
       ('Screwdriver', 'Hand tool used for driving and removing screws'),
       ('Wrench', 'Hand tool used for tightening and loosening bolts and nuts'),
       ('Saw', 'Hand tool used for cutting wood and solid materials'),
       ('Pliers', 'Hand tool used for gripping, bending, and cutting objects'),
       ('Drill', 'Powered tool used for drilling holes in materials'),
       ('Bolt', 'Threaded fastening component used in mechanical assembly'),
       ('Screw', 'Threaded fastener used for joining materials'),
       ('Nut', 'Fastening component used with bolts for secure assembly'),
       ('Glue', 'Adhesive material used for bonding surfaces'),
       ('Tape', 'Adhesive strip used for sealing and fastening materials'),
       ('Helmet', 'Protective headgear used for safety in industrial environments'),
       ('Gloves', 'Protective hand covering used for safety and handling'),
       ('Goggles', 'Protective eyewear used to prevent injury from debris');

--=============================
--Product categoires
--=============================
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
                                           WHEN 'Laptop' THEN 'components'
                                           WHEN 'Desktop' THEN 'components'
                                           WHEN 'Tablet' THEN 'components'
                                           WHEN 'Monitor' THEN 'monitors'
                                           WHEN 'Keyboard' THEN 'keyboards'
                                           WHEN 'Mouse' THEN 'mice'
                                           WHEN 'Headphones' THEN 'headphones'
                                           WHEN 'Speakers' THEN 'speakers'
                                           WHEN 'Router' THEN 'routers'
                                           WHEN 'SSD' THEN 'drives'
                                           WHEN 'HDD' THEN 'drives'
                                           WHEN 'USB Drive' THEN 'drives'
                                           WHEN 'Hammer' THEN 'hand_tools'
                                           WHEN 'Screwdriver' THEN 'hand_tools'
                                           WHEN 'Wrench' THEN 'hand_tools'
                                           WHEN 'Saw' THEN 'hand_tools'
                                           WHEN 'Pliers' THEN 'hand_tools'
                                           WHEN 'Drill' THEN 'power_tools'
                                           WHEN 'Bolt' THEN 'fasteners'
                                           WHEN 'Screw' THEN 'fasteners'
                                           WHEN 'Nut' THEN 'fasteners'
                                           WHEN 'Glue' THEN 'fasteners'
                                           WHEN 'Tape' THEN 'fasteners'
                                           WHEN 'Helmet' THEN 'safety_equipment'
                                           WHEN 'Gloves' THEN 'safety_equipment'
                                           WHEN 'Goggles' THEN 'safety_equipment'
    END;



--==================
--ATTRIBUTES
--===================


INSERT INTO attributes (name, data_type, unit, is_variant_attribute)
VALUES ('size', 'VARCHAR', NULL, TRUE),
       ('color', 'VARCHAR', NULL, TRUE),
       ('material', 'VARCHAR', NULL, TRUE),
       ('weight', 'VARCHAR', 'kg', FALSE),
       ('volume', 'VARCHAR', 'L', FALSE),
       ('length', 'VARCHAR', 'mm', TRUE),
       ('width', 'VARCHAR', 'mm', FALSE),
       ('height', 'VARCHAR', 'mm', FALSE),
       ('fit', 'VARCHAR', NULL, TRUE),
       ('gender', 'VARCHAR', NULL, TRUE),
       ('layer_type', 'VARCHAR', NULL, FALSE),
       ('fabric_type', 'VARCHAR', NULL, TRUE),
       ('texture', 'VARCHAR', NULL, FALSE),
       ('strength_rating', 'VARCHAR', NULL, TRUE),
       ('load_capacity', 'VARCHAR', NULL, FALSE),
       ('torque', 'VARCHAR', 'Nm', TRUE),
       ('pressure_rating', 'VARCHAR', NULL, FALSE),
       ('temperature_range', 'VARCHAR', NULL, TRUE),
       ('hardness', 'VARCHAR', NULL, FALSE),
       ('corrosion_resistance', 'VARCHAR', NULL, TRUE),
       ('power_consumption', 'VARCHAR', 'W', TRUE),
       ('voltage', 'VARCHAR', 'V', TRUE),
       ('current', 'VARCHAR', 'A', FALSE),
       ('frequency', 'VARCHAR', 'Hz', TRUE),
       ('connectivity_type', 'VARCHAR', NULL, TRUE),
       ('interface_type', 'VARCHAR', NULL, TRUE),
       ('compatibility', 'VARCHAR', NULL, FALSE),
       ('efficiency_rating', 'VARCHAR', NULL, FALSE),
       ('storage_capacity', 'VARCHAR', 'GB', TRUE),
       ('ram_capacity', 'VARCHAR', 'GB', TRUE),
       ('cpu_type', 'VARCHAR', NULL, TRUE),
       ('gpu_type', 'VARCHAR', NULL, TRUE),
       ('operating_system', 'VARCHAR', NULL, TRUE),
       ('refresh_rate', 'VARCHAR', 'Hz', TRUE),
       ('resolution', 'VARCHAR', NULL, TRUE),
       ('latency', 'VARCHAR', NULL, FALSE),
       ('grip_type', 'VARCHAR', NULL, TRUE),
       ('handle_material', 'VARCHAR', NULL, FALSE),
       ('tool_material', 'VARCHAR', NULL, TRUE),
       ('precision_level', 'VARCHAR', NULL, TRUE),
       ('usage_intensity', 'VARCHAR', NULL, FALSE),
       ('ergonomics_level', 'VARCHAR', NULL, TRUE),
       ('protection_level', 'VARCHAR', NULL, TRUE),
       ('impact_resistance', 'VARCHAR', NULL, TRUE),
       ('certification_standard', 'VARCHAR', NULL, TRUE),
       ('hazard_rating', 'VARCHAR', NULL, FALSE),
       ('visibility_level', 'VARCHAR', NULL, TRUE),
       ('fire_resistance', 'VARCHAR', NULL, TRUE),
       ('packaging_type', 'VARCHAR', NULL, FALSE),
       ('stackability', 'VARCHAR', NULL, FALSE),
       ('fragility', 'VARCHAR', NULL, FALSE),
       ('reusability', 'VARCHAR', NULL, FALSE),
       ('seal_type', 'VARCHAR', NULL, FALSE),
       ('storage_condition', 'VARCHAR', NULL, FALSE),
       ('sleeve_length', 'VARCHAR', NULL, TRUE),
       ('season', 'VARCHAR', NULL, TRUE),
       ('screen_size', 'VARCHAR', 'inch', TRUE),
       ('battery_life', 'VARCHAR', NULL, TRUE),
       ('panel_type', 'VARCHAR', NULL, TRUE),
       ('response_time', 'VARCHAR', 'ms', TRUE),
       ('frequency_range', 'VARCHAR', NULL, TRUE),
       ('power_output', 'VARCHAR', NULL, TRUE),
       ('noise_cancellation', 'VARCHAR', NULL, TRUE),
       ('audio_quality_level', 'VARCHAR', NULL, TRUE),
       ('band_support', 'VARCHAR', NULL, TRUE),
       ('speed', 'VARCHAR', NULL, TRUE),
       ('range', 'VARCHAR', NULL, TRUE),
       ('read_speed', 'VARCHAR', NULL, TRUE),
       ('write_speed', 'VARCHAR', NULL, TRUE),
       ('durability', 'VARCHAR', NULL, TRUE),
       ('diameter', 'VARCHAR', NULL, TRUE),
       ('thread_type', 'VARCHAR', NULL, TRUE),
       ('adhesive_strength', 'VARCHAR', NULL, TRUE),
       ('rpm', 'VARCHAR', 'rpm', TRUE);



--===================================
--ATTRIBUTE VALUES
--===================================

INSERT INTO attribute_values (attribute_id, value)
SELECT a.id, val
FROM (VALUES ('size', 'XS'),
             ('size', 'S'),
             ('size', 'M'),
             ('size', 'L'),
             ('size', 'XL'),
             ('size', 'XXL'),
             ('color', 'beige'),
             ('color', 'black'),
             ('color', 'blue'),
             ('color', 'camel'),
             ('color', 'green'),
             ('color', 'grey'),
             ('color', 'khaki'),
             ('color', 'navy'),
             ('color', 'olive'),
             ('color', 'red'),
             ('color', 'striped'),
             ('color', 'white'),
             ('material', 'alloy'),
             ('material', 'brass'),
             ('material', 'carbon_steel'),
             ('material', 'cashmere'),
             ('material', 'composite'),
             ('material', 'cotton'),
             ('material', 'cotton_twill'),
             ('material', 'denim'),
             ('material', 'fleece'),
             ('material', 'leather'),
             ('material', 'microfiber'),
             ('material', 'modal'),
             ('material', 'nylon'),
             ('material', 'plastic'),
             ('material', 'polyester'),
             ('material', 'raw_denim'),
             ('material', 'rubber'),
             ('material', 'rubber_based'),
             ('material', 'stainless_steel'),
             ('material', 'steel'),
             ('material', 'stretch_cotton'),
             ('material', 'stretch_denim'),
             ('material', 'synthetic'),
             ('material', 'wool'),
             ('fit', 'flared'),
             ('fit', 'loose'),
             ('fit', 'oversized'),
             ('fit', 'regular'),
             ('fit', 'relaxed'),
             ('fit', 'skinny'),
             ('fit', 'slim'),
             ('fit', 'tailored'),
             ('fit', 'tight'),
             ('gender', 'female'),
             ('gender', 'male'),
             ('gender', 'unisex'),
             ('fabric_type', 'cashmere'),
             ('fabric_type', 'cotton'),
             ('fabric_type', 'cotton_pique'),
             ('fabric_type', 'cotton_twill'),
             ('fabric_type', 'denim'),
             ('fabric_type', 'fleece'),
             ('fabric_type', 'leather'),
             ('fabric_type', 'linen'),
             ('fabric_type', 'nylon'),
             ('fabric_type', 'polyester'),
             ('fabric_type', 'raw_denim'),
             ('fabric_type', 'stretch_cotton'),
             ('fabric_type', 'stretch_denim'),
             ('fabric_type', 'wool'),
             ('sleeve_length', 'long'),
             ('sleeve_length', 'short'),
             ('sleeve_length', 'sleeveless'),
             ('season', 'autumn'),
             ('season', 'spring'),
             ('season', 'winter'),
             ('storage_capacity', '64GB'),
             ('storage_capacity', '128GB'),
             ('storage_capacity', '256GB'),
             ('storage_capacity', '512GB'),
             ('storage_capacity', '1TB'),
             ('storage_capacity', '2TB'),
             ('ram_capacity', '8GB'),
             ('ram_capacity', '16GB'),
             ('ram_capacity', '32GB'),
             ('ram_capacity', '64GB'),
             ('cpu_type', 'i5'),
             ('cpu_type', 'i7'),
             ('cpu_type', 'ryzen5'),
             ('cpu_type', 'ryzen7'),
             ('cpu_type', 'ryzen9'),
             ('gpu_type', 'dedicated'),
             ('gpu_type', 'integrated'),
             ('gpu_type', 'rtx'),
             ('operating_system', 'linux'),
             ('operating_system', 'macos'),
             ('operating_system', 'windows'),
             ('screen_size', '8'),
             ('screen_size', '10'),
             ('screen_size', '12'),
             ('screen_size', '13'),
             ('screen_size', '14'),
             ('screen_size', '15'),
             ('screen_size', '17'),
             ('screen_size', '24'),
             ('screen_size', '27'),
             ('screen_size', '32'),
             ('screen_size', '34'),
             ('resolution', '1080p'),
             ('resolution', '2k'),
             ('resolution', '4k'),
             ('connectivity_type', 'bluetooth'),
             ('connectivity_type', 'displayport'),
             ('connectivity_type', 'ethernet'),
             ('connectivity_type', 'hdmi'),
             ('connectivity_type', 'lte'),
             ('connectivity_type', 'usb_c'),
             ('connectivity_type', 'wifi'),
             ('connectivity_type', 'wired'),
             ('connectivity_type', 'wireless'),
             ('connectivity_type', '5g'),
             ('refresh_rate', '60'),
             ('refresh_rate', '120'),
             ('refresh_rate', '144'),
             ('refresh_rate', '240'),
             ('panel_type', 'ips'),
             ('panel_type', 'tn'),
             ('panel_type', 'va'),
             ('response_time', '1ms'),
             ('response_time', '5ms'),
             ('response_time', 'fast'),
             ('response_time', 'normal'),
             ('precision_level', 'high'),
             ('precision_level', 'low'),
             ('precision_level', 'medium'),
             ('ergonomics_level', 'basic'),
             ('ergonomics_level', 'ergonomic'),
             ('frequency_range', 'high'),
             ('frequency_range', 'low'),
             ('frequency_range', 'medium'),
             ('power_output', 'high'),
             ('power_output', 'low'),
             ('power_output', 'medium'),
             ('noise_cancellation', 'active'),
             ('noise_cancellation', 'no'),
             ('noise_cancellation', 'yes'),
             ('audio_quality_level', 'basic'),
             ('audio_quality_level', 'high'),
             ('audio_quality_level', 'premium'),
             ('frequency', '2.4ghz'),
             ('frequency', '5ghz'),
             ('frequency', 'dual_band'),
             ('band_support', 'dual'),
             ('band_support', 'single'),
             ('band_support', 'tri'),
             ('speed', '100mbps'),
             ('speed', '1gbps'),
             ('speed', '10gbps'),
             ('range', 'long'),
             ('range', 'medium'),
             ('range', 'short'),
             ('read_speed', 'high'),
             ('read_speed', 'low'),
             ('read_speed', 'medium'),
             ('write_speed', 'high'),
             ('write_speed', 'low'),
             ('write_speed', 'medium'),
             ('interface_type', 'nvme'),
             ('interface_type', 'sata'),
             ('interface_type', 'usb_2'),
             ('interface_type', 'usb_3'),
             ('strength_rating', 'high'),
             ('strength_rating', 'low'),
             ('strength_rating', 'medium'),
             ('grip_type', 'plastic'),
             ('grip_type', 'rubber'),
             ('grip_type', 'wood'),
             ('durability', 'high'),
             ('durability', 'low'),
             ('durability', 'medium'),
             ('torque', 'high'),
             ('torque', 'low'),
             ('torque', 'medium'),
             ('voltage', '12v'),
             ('voltage', '18v'),
             ('voltage', '24v'),
             ('power_consumption', 'high'),
             ('power_consumption', 'low'),
             ('power_consumption', 'medium'),
             ('rpm', '1000'),
             ('rpm', '2000'),
             ('rpm', '3000'),
             ('length', '10mm'),
             ('length', '20mm'),
             ('length', '50mm'),
             ('diameter', 'large'),
             ('diameter', 'medium'),
             ('diameter', 'small'),
             ('corrosion_resistance', 'high'),
             ('corrosion_resistance', 'low'),
             ('corrosion_resistance', 'medium'),
             ('thread_type', 'coarse'),
             ('thread_type', 'fine'),
             ('adhesive_strength', 'high'),
             ('adhesive_strength', 'low'),
             ('adhesive_strength', 'medium'),
             ('temperature_range', 'high'),
             ('temperature_range', 'low'),
             ('temperature_range', 'medium'),
             ('protection_level', 'high'),
             ('protection_level', 'low'),
             ('protection_level', 'medium'),
             ('impact_resistance', 'high'),
             ('impact_resistance', 'low'),
             ('impact_resistance', 'medium'),
             ('certification_standard', 'basic'),
             ('certification_standard', 'en_standard'),
             ('certification_standard', 'iso'),
             ('visibility_level', 'high'),
             ('visibility_level', 'low'),
             ('visibility_level', 'medium'),
             ('fire_resistance', 'no'),
             ('fire_resistance', 'yes')) AS t(attr_name, val)
         JOIN attributes a ON a.name = t.attr_name;

--======================================
--FINAL LOGIC
--======================================

-- ============================================================================
-- TEMP / HELPER SEQUENCE FOR SKU GENERATION
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS variant_sku_seq START 1;

-- ============================================================================
-- BUILD PRODUCT VARIANTS (≥ 1,000,000 rows) + variant_attribute data
-- We use a staging table per product family to store intermediate combinations.
-- ============================================================================

-- -----------------------------------------------------------------------
-- 1. APPAREL: PANTS / SKIRTS FAMILY (size, color, fit, gender, fabric_type)
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_pants_skirts AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       sz.id                                 AS size_av_id,
       col.id                                AS color_av_id,
       fit.id                                AS fit_av_id,
       gen.id                                AS gender_av_id,
       fab.id                                AS fabric_av_id,
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id AND c.name IN ('pants', 'skirts') -- 6 products
         CROSS JOIN LATERAL (
    SELECT id
    FROM brands
    WHERE name IN ('Nike', 'Adidas', 'Puma', 'Under Armour', 'Levi''s', 'H&M', 'Zara', 'Hugo Boss', 'Guess', 'Uniqlo')
    ) b
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'size')
      AND value IN ('XS', 'S', 'M', 'L', 'XL', 'XXL')
    ) sz
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'color')
      AND value IN
          ('beige', 'black', 'blue', 'camel', 'green', 'grey', 'khaki', 'navy', 'olive', 'red', 'striped', 'white')
    ) col
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'fit')
      AND value IN ('flared', 'loose', 'oversized', 'regular', 'relaxed', 'skinny', 'slim', 'tailored', 'tight')
    ) fit
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'gender')
      AND value IN ('male', 'female', 'unisex')
    ) gen
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'fabric_type')
      AND value IN
          ('cashmere', 'cotton', 'cotton_pique', 'cotton_twill', 'denim', 'fleece', 'leather', 'linen', 'nylon',
           'polyester', 'raw_denim', 'stretch_cotton', 'stretch_denim', 'wool')
    ) fab;

-- Insert into product_variants using a sequence‑based SKU
INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq')::text,
       brand_id,
       'BAR-' || currval('variant_sku_seq')::text,
       price,
       weight,
       status
FROM temp_var_pants_skirts;

-- Link variant attributes: size, color, fit, gender, fabric_type
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.size_av_id, (SELECT id FROM attributes WHERE name = 'size')
FROM product_variants v
         JOIN temp_var_pants_skirts t ON v.product_id = t.product_id
    AND v.brand_id = t.brand_id
    AND v.price = t.price AND v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.color_av_id, (SELECT id FROM attributes WHERE name = 'color')
FROM product_variants v
         JOIN temp_var_pants_skirts t
              ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                 v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.fit_av_id, (SELECT id FROM attributes WHERE name = 'fit')
FROM product_variants v
         JOIN temp_var_pants_skirts t
              ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                 v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.gender_av_id, (SELECT id FROM attributes WHERE name = 'gender')
FROM product_variants v
         JOIN temp_var_pants_skirts t
              ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                 v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.fabric_av_id, (SELECT id FROM attributes WHERE name = 'fabric_type')
FROM product_variants v
         JOIN temp_var_pants_skirts t
              ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                 v.weight = t.weight AND v.status = t.status;

DROP TABLE temp_var_pants_skirts;

-- -----------------------------------------------------------------------
-- 2. APPAREL: TOPS (tshirt, shirt, polo, tanktop) + sleeve_length
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_tops AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       sz.id                                 AS size_av_id,
       col.id                                AS color_av_id,
       fit.id                                AS fit_av_id,
       gen.id                                AS gender_av_id,
       fab.id                                AS fabric_av_id,
       sl.id                                 AS sleeve_av_id,
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c
              ON c.id = pc.category_id AND c.name IN ('tshirts', 'shirts') -- includes tshirts, shirts (shirt,polo,tanktop mapped to shirts; but we need all tops products: 'Tshirt','Shirt','Polo','Tanktop' may be in categories 'tshirts', 'shirts'. The mapping: Tshirt -> tshirts, Shirt,Polo,Tanktop -> shirts. So include both.
         CROSS JOIN LATERAL (
    SELECT id
    FROM brands
    WHERE name IN ('Nike', 'Adidas', 'Puma', 'Under Armour', 'Levi''s', 'H&M', 'Zara', 'Hugo Boss', 'Guess', 'Uniqlo')
    ) b
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'size')
      AND value IN ('XS', 'S', 'M', 'L', 'XL', 'XXL')
    ) sz
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'color')
      AND value IN
          ('beige', 'black', 'blue', 'camel', 'green', 'grey', 'khaki', 'navy', 'olive', 'red', 'striped', 'white')
    ) col
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'fit')
      AND value IN ('flared', 'loose', 'oversized', 'regular', 'relaxed', 'skinny', 'slim', 'tailored', 'tight')
    ) fit
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'gender')
      AND value IN ('male', 'female', 'unisex')
    ) gen
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'fabric_type')
      AND value IN
          ('cashmere', 'cotton', 'cotton_pique', 'cotton_twill', 'denim', 'fleece', 'leather', 'linen', 'nylon',
           'polyester', 'raw_denim', 'stretch_cotton', 'stretch_denim', 'wool')
    ) fab
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'sleeve_length')
      AND value IN ('long', 'short', 'sleeveless')
    ) sl;

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq'),
       brand_id,
       'BAR-' || currval('variant_sku_seq'),
       price,
       weight,
       status
FROM temp_var_tops;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.size_av_id, (SELECT id FROM attributes WHERE name = 'size')
FROM product_variants v
         JOIN temp_var_tops t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                 v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.color_av_id, (SELECT id FROM attributes WHERE name = 'color')
FROM product_variants v
         JOIN temp_var_tops t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                 v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.fit_av_id, (SELECT id FROM attributes WHERE name = 'fit')
FROM product_variants v
         JOIN temp_var_tops t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                 v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.gender_av_id, (SELECT id FROM attributes WHERE name = 'gender')
FROM product_variants v
         JOIN temp_var_tops t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                 v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.fabric_av_id, (SELECT id FROM attributes WHERE name = 'fabric_type')
FROM product_variants v
         JOIN temp_var_tops t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                 v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.sleeve_av_id, (SELECT id FROM attributes WHERE name = 'sleeve_length')
FROM product_variants v
         JOIN temp_var_tops t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                 v.weight = t.weight AND v.status = t.status;

DROP TABLE temp_var_tops;

-- -----------------------------------------------------------------------
-- 3. APPAREL: OUTERWEAR (jacket, coat, hoodie) + season
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_outerwear AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       sz.id                                 AS size_av_id,
       col.id                                AS color_av_id,
       fit.id                                AS fit_av_id,
       fab.id                                AS fabric_av_id,
       se.id                                 AS season_av_id,
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id AND c.name IN ('jackets', 'hoodies')
         CROSS JOIN LATERAL (SELECT id
                             FROM brands
                             WHERE name IN
                                   ('Nike', 'Adidas', 'Puma', 'Under Armour', 'Levi''s', 'H&M', 'Zara', 'Hugo Boss',
                                    'Guess', 'Uniqlo')) b
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'size')
                               AND value IN ('XS', 'S', 'M', 'L', 'XL', 'XXL')) sz
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'color')
                               AND value IN
                                   ('beige', 'black', 'blue', 'camel', 'green', 'grey', 'khaki', 'navy', 'olive', 'red',
                                    'striped', 'white')) col
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'fit')
                               AND value IN
                                   ('flared', 'loose', 'oversized', 'regular', 'relaxed', 'skinny', 'slim', 'tailored',
                                    'tight')) fit
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'fabric_type')
                               AND value IN
                                   ('cashmere', 'cotton', 'cotton_pique', 'cotton_twill', 'denim', 'fleece', 'leather',
                                    'linen', 'nylon', 'polyester', 'raw_denim', 'stretch_cotton', 'stretch_denim',
                                    'wool')) fab
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'season')
                               AND value IN ('winter', 'autumn', 'spring')) se;

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq'),
       brand_id,
       'BAR-' || currval('variant_sku_seq'),
       price,
       weight,
       status
FROM temp_var_outerwear;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.size_av_id, (SELECT id FROM attributes WHERE name = 'size')
FROM product_variants v
         JOIN temp_var_outerwear t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.color_av_id, (SELECT id FROM attributes WHERE name = 'color')
FROM product_variants v
         JOIN temp_var_outerwear t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.fit_av_id, (SELECT id FROM attributes WHERE name = 'fit')
FROM product_variants v
         JOIN temp_var_outerwear t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.fabric_av_id, (SELECT id FROM attributes WHERE name = 'fabric_type')
FROM product_variants v
         JOIN temp_var_outerwear t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.season_av_id, (SELECT id FROM attributes WHERE name = 'season')
FROM product_variants v
         JOIN temp_var_outerwear t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;

DROP TABLE temp_var_outerwear;

-- -----------------------------------------------------------------------
-- 4. APPAREL: UNDERWEAR (socks, underwear) - size, color, material
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_underwear AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       sz.id                                 AS size_av_id,
       col.id                                AS color_av_id,
       mat.id                                AS material_av_id,
       fit.id                                AS fit_av_id, -- only for underwear, socks will have NULL but we handle later
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id AND c.name IN ('socks', 'underpants')
         CROSS JOIN LATERAL (SELECT id
                             FROM brands
                             WHERE name IN
                                   ('Nike', 'Adidas', 'Puma', 'Under Armour', 'Levi''s', 'H&M', 'Zara', 'Hugo Boss',
                                    'Guess', 'Uniqlo')) b
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'size')
                               AND value IN ('S', 'M', 'L', 'XL')) sz
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'color')
                               AND value IN
                                   ('beige', 'black', 'blue', 'camel', 'green', 'grey', 'khaki', 'navy', 'olive', 'red',
                                    'striped', 'white')) col
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'material')
                               AND value IN ('cotton', 'wool', 'polyester', 'microfiber', 'modal')) mat
         CROSS JOIN LATERAL (
    SELECT id
    FROM attribute_values
    WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'fit')
      AND value IN ('tight', 'regular')
    ) fit; -- socks won't use fit, but we store the ID; we'll insert attribute only for underwear later

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq'),
       brand_id,
       'BAR-' || currval('variant_sku_seq'),
       price,
       weight,
       status
FROM temp_var_underwear;

-- Insert attributes: size, color, material for all; fit only when product is underwear
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.size_av_id, (SELECT id FROM attributes WHERE name = 'size')
FROM product_variants v
         JOIN temp_var_underwear t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.color_av_id, (SELECT id FROM attributes WHERE name = 'color')
FROM product_variants v
         JOIN temp_var_underwear t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.material_av_id, (SELECT id FROM attributes WHERE name = 'material')
FROM product_variants v
         JOIN temp_var_underwear t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.fit_av_id, (SELECT id FROM attributes WHERE name = 'fit')
FROM product_variants v
         JOIN temp_var_underwear t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status
         JOIN products p ON p.id = v.product_id
WHERE p.name = 'Underwear'; -- only underpants uses fit

DROP TABLE temp_var_underwear;

-- -----------------------------------------------------------------------
-- 5. ELECTRONICS: COMPUTING (laptop, desktop, tablet)
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_computing AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       sc.id                                 AS storage_av_id,
       rc.id                                 AS ram_av_id,
       cpu.id                                AS cpu_av_id,
       gpu.id                                AS gpu_av_id,
       os.id                                 AS os_av_id,
       ss.id                                 AS screen_av_id,
       res.id                                AS res_av_id,
       ctype.id                              AS conn_av_id,
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id AND c.name = 'components' -- laptops, desktops, tablets
         CROSS JOIN LATERAL (SELECT id
                             FROM brands
                             WHERE name IN ('Apple', 'Samsung', 'Sony', 'LG', 'Dell', 'HP', 'Lenovo', 'Asus')) b
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'storage_capacity')
                               AND value IN ('64GB', '128GB', '256GB', '512GB', '1TB', '2TB')) sc
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'ram_capacity')
                               AND value IN ('8GB', '16GB', '32GB', '64GB')) rc
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'cpu_type')
                               AND value IN ('i5', 'i7', 'ryzen5', 'ryzen7', 'ryzen9')) cpu
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'gpu_type')
                               AND value IN ('dedicated', 'integrated', 'rtx')) gpu
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'operating_system')
                               AND value IN ('linux', 'macos', 'windows')) os
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'screen_size')
                               AND value IN ('8', '10', '12', '13', '14', '15', '17', '24', '27', '32', '34')) ss
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'resolution')
                               AND value IN ('1080p', '2k', '4k')) res
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'connectivity_type')
                               AND value IN
                                   ('bluetooth', 'displayport', 'ethernet', 'hdmi', 'lte', 'usb_c', 'wifi', 'wired',
                                    'wireless', '5g')) ctype;

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq'),
       brand_id,
       'BAR-' || currval('variant_sku_seq'),
       price,
       weight,
       status
FROM temp_var_computing;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.storage_av_id, (SELECT id FROM attributes WHERE name = 'storage_capacity')
FROM product_variants v
         JOIN temp_var_computing t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.ram_av_id, (SELECT id FROM attributes WHERE name = 'ram_capacity')
FROM product_variants v
         JOIN temp_var_computing t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.cpu_av_id, (SELECT id FROM attributes WHERE name = 'cpu_type')
FROM product_variants v
         JOIN temp_var_computing t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.gpu_av_id, (SELECT id FROM attributes WHERE name = 'gpu_type')
FROM product_variants v
         JOIN temp_var_computing t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.os_av_id, (SELECT id FROM attributes WHERE name = 'operating_system')
FROM product_variants v
         JOIN temp_var_computing t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.screen_av_id, (SELECT id FROM attributes WHERE name = 'screen_size')
FROM product_variants v
         JOIN temp_var_computing t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.res_av_id, (SELECT id FROM attributes WHERE name = 'resolution')
FROM product_variants v
         JOIN temp_var_computing t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.conn_av_id, (SELECT id FROM attributes WHERE name = 'connectivity_type')
FROM product_variants v
         JOIN temp_var_computing t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                      v.weight = t.weight AND v.status = t.status;

DROP TABLE temp_var_computing;

-- -----------------------------------------------------------------------
-- 6. ELECTRONICS: MONITORS
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_monitors AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       ss.id                                 AS screen_av_id,
       res.id                                AS res_av_id,
       rr.id                                 AS refresh_av_id,
       pt.id                                 AS panel_av_id,
       rt.id                                 AS resp_av_id,
       ctype.id                              AS conn_av_id,
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id AND c.name = 'monitors'
         CROSS JOIN LATERAL (SELECT id
                             FROM brands
                             WHERE name IN ('Apple', 'Samsung', 'Sony', 'LG', 'Dell', 'HP', 'Lenovo', 'Asus')) b
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'screen_size')
                               AND value IN ('24', '27', '32', '34')) ss
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'resolution')
                               AND value IN ('1080p', '2k', '4k')) res
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'refresh_rate')
                               AND value IN ('60', '120', '144', '240')) rr
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'panel_type')
                               AND value IN ('ips', 'tn', 'va')) pt
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'response_time')
                               AND value IN ('1ms', '5ms')) rt
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'connectivity_type')
                               AND value IN ('hdmi', 'displayport', 'usb_c')) ctype;

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq'),
       brand_id,
       'BAR-' || currval('variant_sku_seq'),
       price,
       weight,
       status
FROM temp_var_monitors;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.screen_av_id, (SELECT id FROM attributes WHERE name = 'screen_size')
FROM product_variants v
         JOIN temp_var_monitors t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                     v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.res_av_id, (SELECT id FROM attributes WHERE name = 'resolution')
FROM product_variants v
         JOIN temp_var_monitors t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                     v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.refresh_av_id, (SELECT id FROM attributes WHERE name = 'refresh_rate')
FROM product_variants v
         JOIN temp_var_monitors t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                     v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.panel_av_id, (SELECT id FROM attributes WHERE name = 'panel_type')
FROM product_variants v
         JOIN temp_var_monitors t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                     v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.resp_av_id, (SELECT id FROM attributes WHERE name = 'response_time')
FROM product_variants v
         JOIN temp_var_monitors t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                     v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.conn_av_id, (SELECT id FROM attributes WHERE name = 'connectivity_type')
FROM product_variants v
         JOIN temp_var_monitors t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                     v.weight = t.weight AND v.status = t.status;

DROP TABLE temp_var_monitors;

-- -----------------------------------------------------------------------
-- 7. ELECTRONICS: INPUT DEVICES (keyboard, mouse)
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_input AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       ctype.id                              AS conn_av_id,
       prec.id                               AS prec_av_id,
       erg.id                                AS erg_av_id,
       rt.id                                 AS resp_av_id,
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id AND c.name IN ('keyboards', 'mice')
         CROSS JOIN LATERAL (SELECT id
                             FROM brands
                             WHERE name IN ('Apple', 'Samsung', 'Sony', 'LG', 'Dell', 'HP', 'Lenovo', 'Asus')) b
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'connectivity_type')
                               AND value IN ('wired', 'wireless', 'bluetooth')) ctype
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'precision_level')
                               AND value IN ('low', 'medium', 'high')) prec
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'ergonomics_level')
                               AND value IN ('basic', 'ergonomic')) erg
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'response_time')
                               AND value IN ('fast', 'normal')) rt;

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq'),
       brand_id,
       'BAR-' || currval('variant_sku_seq'),
       price,
       weight,
       status
FROM temp_var_input;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.conn_av_id, (SELECT id FROM attributes WHERE name = 'connectivity_type')
FROM product_variants v
         JOIN temp_var_input t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                  v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.prec_av_id, (SELECT id FROM attributes WHERE name = 'precision_level')
FROM product_variants v
         JOIN temp_var_input t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                  v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.erg_av_id, (SELECT id FROM attributes WHERE name = 'ergonomics_level')
FROM product_variants v
         JOIN temp_var_input t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                  v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.resp_av_id, (SELECT id FROM attributes WHERE name = 'response_time')
FROM product_variants v
         JOIN temp_var_input t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                  v.weight = t.weight AND v.status = t.status;

DROP TABLE temp_var_input;

-- -----------------------------------------------------------------------
-- 8. ELECTRONICS: AUDIO (headphones, speakers)
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_audio AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       ctype.id                              AS conn_av_id,
       fr.id                                 AS freq_av_id,
       po.id                                 AS power_av_id,
       nc.id                                 AS noise_av_id,
       aq.id                                 AS audio_av_id,
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id AND c.name IN ('headphones', 'speakers')
         CROSS JOIN LATERAL (SELECT id
                             FROM brands
                             WHERE name IN ('Apple', 'Samsung', 'Sony', 'LG', 'Dell', 'HP', 'Lenovo', 'Asus')) b
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'connectivity_type')
                               AND value IN ('wired', 'wireless', 'bluetooth')) ctype
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'frequency_range')
                               AND value IN ('low', 'medium', 'high')) fr
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'power_output')
                               AND value IN ('low', 'medium', 'high')) po
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'noise_cancellation')
                               AND value IN ('yes', 'no', 'active')) nc
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'audio_quality_level')
                               AND value IN ('basic', 'high', 'premium')) aq;

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq'),
       brand_id,
       'BAR-' || currval('variant_sku_seq'),
       price,
       weight,
       status
FROM temp_var_audio;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.conn_av_id, (SELECT id FROM attributes WHERE name = 'connectivity_type')
FROM product_variants v
         JOIN temp_var_audio t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                  v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.freq_av_id, (SELECT id FROM attributes WHERE name = 'frequency_range')
FROM product_variants v
         JOIN temp_var_audio t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                  v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.power_av_id, (SELECT id FROM attributes WHERE name = 'power_output')
FROM product_variants v
         JOIN temp_var_audio t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                  v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.noise_av_id, (SELECT id FROM attributes WHERE name = 'noise_cancellation')
FROM product_variants v
         JOIN temp_var_audio t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                  v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.audio_av_id, (SELECT id FROM attributes WHERE name = 'audio_quality_level')
FROM product_variants v
         JOIN temp_var_audio t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                  v.weight = t.weight AND v.status = t.status;

DROP TABLE temp_var_audio;

-- -----------------------------------------------------------------------
-- 9. ELECTRONICS: NETWORKING (router)
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_networking AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       ctype.id                              AS conn_av_id,
       freq.id                               AS freq_av_id,
       band.id                               AS band_av_id,
       spd.id                                AS speed_av_id,
       rng.id                                AS range_av_id,
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id AND c.name = 'routers'
         CROSS JOIN LATERAL (SELECT id
                             FROM brands
                             WHERE name IN ('Apple', 'Samsung', 'Sony', 'LG', 'Dell', 'HP', 'Lenovo', 'Asus')) b
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'connectivity_type')
                               AND value IN ('wifi', 'ethernet')) ctype
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'frequency')
                               AND value IN ('2.4ghz', '5ghz', 'dual_band')) freq
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'band_support')
                               AND value IN ('single', 'dual', 'tri')) band
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'speed')
                               AND value IN ('100mbps', '1gbps', '10gbps')) spd
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'range')
                               AND value IN ('short', 'medium', 'long')) rng;

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq'),
       brand_id,
       'BAR-' || currval('variant_sku_seq'),
       price,
       weight,
       status
FROM temp_var_networking;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.conn_av_id, (SELECT id FROM attributes WHERE name = 'connectivity_type')
FROM product_variants v
         JOIN temp_var_networking t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                       v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.freq_av_id, (SELECT id FROM attributes WHERE name = 'frequency')
FROM product_variants v
         JOIN temp_var_networking t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                       v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.band_av_id, (SELECT id FROM attributes WHERE name = 'band_support')
FROM product_variants v
         JOIN temp_var_networking t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                       v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.speed_av_id, (SELECT id FROM attributes WHERE name = 'speed')
FROM product_variants v
         JOIN temp_var_networking t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                       v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.range_av_id, (SELECT id FROM attributes WHERE name = 'range')
FROM product_variants v
         JOIN temp_var_networking t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                       v.weight = t.weight AND v.status = t.status;

DROP TABLE temp_var_networking;

-- -----------------------------------------------------------------------
-- 10. ELECTRONICS: STORAGE (SSD, HDD, USB Drive)
-- -----------------------------------------------------------------------
CREATE
    TEMP TABLE temp_var_storage AS
SELECT p.id                                  AS product_id,
       b.id                                  AS brand_id,
       sc.id                                 AS storage_av_id,
       rs.id                                 AS read_av_id,
       ws.id                                 AS write_av_id,
       iface.id                              AS iface_av_id,
       (random() * 990 + 10)::numeric(10, 2) AS price,
       (random() * 10)::numeric(10, 2)       AS weight,
       'active'                              AS status
FROM products p
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id AND c.name = 'drives'
         CROSS JOIN LATERAL (SELECT id
                             FROM brands
                             WHERE name IN ('Apple', 'Samsung', 'Sony', 'LG', 'Dell', 'HP', 'Lenovo', 'Asus')) b
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'storage_capacity')
                               AND value IN ('128GB', '256GB', '512GB', '1TB', '2TB')) sc
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'read_speed')
                               AND value IN ('low', 'medium', 'high')) rs
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'write_speed')
                               AND value IN ('low', 'medium', 'high')) ws
         CROSS JOIN LATERAL (SELECT id
                             FROM attribute_values
                             WHERE attribute_id = (SELECT id FROM attributes WHERE name = 'interface_type')
                               AND value IN ('sata', 'nvme', 'usb_2', 'usb_3')) iface;

INSERT INTO product_variants (product_id, sku, brand_id, barcode, price, weight, status)
SELECT product_id,
       'SKU-' || nextval('variant_sku_seq'),
       brand_id,
       'BAR-' || currval('variant_sku_seq'),
       price,
       weight,
       status
FROM temp_var_storage;

INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.storage_av_id, (SELECT id FROM attributes WHERE name = 'storage_capacity')
FROM product_variants v
         JOIN temp_var_storage t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                    v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.read_av_id, (SELECT id FROM attributes WHERE name = 'read_speed')
FROM product_variants v
         JOIN temp_var_storage t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                    v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.write_av_id, (SELECT id FROM attributes WHERE name = 'write_speed')
FROM product_variants v
         JOIN temp_var_storage t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                    v.weight = t.weight AND v.status = t.status;
INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.id, t.iface_av_id, (SELECT id FROM attributes WHERE name = 'interface_type')
FROM product_variants v
         JOIN temp_var_storage t ON v.product_id = t.product_id AND v.brand_id = t.brand_id AND v.price = t.price AND
                                    v.weight = t.weight AND v.status = t.status;

DROP TABLE temp_var_storage;

DO $$
DECLARE
    cnt BIGINT;
BEGIN
    SELECT COUNT(*) INTO cnt FROM product_variants;
    IF cnt < 1000000 THEN
        RAISE WARNING 'Only % rows in product_variants – expected >= 1,000,000', cnt;
    ELSE
        RAISE NOTICE 'product_variants contains % rows (requirement satisfied)', cnt;
    END IF;
END $$;
