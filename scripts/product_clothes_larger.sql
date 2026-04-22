
TRUNCATE TABLE VARIANT_ATTRIBUTES CASCADE;
TRUNCATE TABLE ATTRIBUTE_VALUES CASCADE;
TRUNCATE TABLE ATTRIBUTES CASCADE;
TRUNCATE TABLE PRODUCT_CATEGORIES CASCADE;
TRUNCATE TABLE PRODUCT_IMAGES CASCADE;
TRUNCATE TABLE PRODUCT_VARIANTS CASCADE;
TRUNCATE TABLE PRODUCTS CASCADE;
TRUNCATE TABLE CATEGORIES CASCADE;
TRUNCATE TABLE BRANDS CASCADE;

ALTER SEQUENCE brands_id_seq RESTART WITH 1;
ALTER SEQUENCE products_id_seq RESTART WITH 1;
ALTER SEQUENCE product_variants_id_seq RESTART WITH 1;
ALTER SEQUENCE product_images_id_seq RESTART WITH 1;
ALTER SEQUENCE categories_id_seq RESTART WITH 1;
ALTER SEQUENCE attributes_id_seq RESTART WITH 1;
ALTER SEQUENCE attribute_values_id_seq RESTART WITH 1;

-- ============================================================================
-- ============================================================================
INSERT INTO BRANDS (name) VALUES
    ('Nike'), ('Adidas'), ('Puma'), ('Under Armour'), ('New Balance'),
    ('Reebok'), ('The North Face'), ('Patagonia'), ('Columbia'), ('Fila'),
    ('Zara'), ('H&M'), ('Uniqlo'), ('Levi''s'), ('Tommy Hilfiger'),
    ('Calvin Klein'), ('Ralph Lauren'), ('Gap'), ('Banana Republic'), ('Guess'),
    ('Gucci'), ('Prada'), ('Versace'), ('Burberry'), ('Coach'),
    ('Vans'), ('Converse'), ('Dr. Martens'), ('Birkenstock'), ('Crocs'),
    ('Swarovski'), ('Pandora'), ('Tiffany & Co.'), ('Fossil'), ('Casio');

-- ============================================================================
-- ============================================================================
INSERT INTO CATEGORIES (name, parent_id) VALUES
    ('Women''s Clothing', NULL), ('Men''s Clothing', NULL), ('Kids'' Clothing', NULL), ('Footwear', NULL), ('Jewelry', NULL);
INSERT INTO CATEGORIES (name, parent_id) VALUES
    ('Dresses', 1), ('Tops', 1), ('Bottoms', 1), ('Outerwear', 1), ('Activewear', 1),
    ('Shirts', 2), ('Pants', 2), ('Jackets', 2), ('Suits', 2), ('Activewear', 2),
    ('Girls'' Clothing', 3), ('Boys'' Clothing', 3), ('Baby & Toddler', 3),
    ('Sneakers', 4), ('Boots', 4), ('Loafers', 4), ('Sandals', 4), ('Heels', 4), ('Flats', 4), ('Running Shoes', 4),
    ('Earrings', 5), ('Necklaces', 5), ('Bracelets', 5), ('Rings', 5), ('Watches', 5);
INSERT INTO CATEGORIES (name, parent_id) VALUES
    ('Maxi Dresses', 6), ('Midi Dresses', 6), ('Mini Dresses', 6),
    ('T-Shirts', 7), ('Blouses', 7), ('Sweaters', 7), ('Tank Tops', 7),
    ('Jeans', 8), ('Skirts', 8), ('Shorts', 8), ('Trousers', 8),
    ('T-Shirts', 11), ('Polo Shirts', 11), ('Dress Shirts', 11), ('Henleys', 11),
    ('Athletic Sneakers', 19), ('Casual Sneakers', 19),
    ('Ankle Boots', 20), ('Chelsea Boots', 20), ('Hiking Boots', 20);

-- ============================================================================
-- ============================================================================
WITH sample_names (base_name, description) AS (
    VALUES
        ('Floral Print Maxi Dress', 'Elegant floral print maxi dress'),
        ('Ribbed Knit Midi Dress', 'Bodycon ribbed knit midi dress'),
        ('Classic Denim Mini Dress', 'Casual denim mini dress'),
        ('Crewneck T-Shirt', 'Essential crewneck t-shirt'),
        ('V-Neck Blouse', 'Flowy v-neck blouse'),
        ('Oversized Sweater', 'Cozy oversized sweater'),
        ('High-Waist Skinny Jeans', 'Classic high-waist skinny jeans'),
        ('Pleated Midi Skirt', 'Elegant pleated midi skirt'),
        ('Relaxed Fit Shorts', 'Casual relaxed fit shorts'),
        ('Wide Leg Trousers', 'Chic wide leg trousers'),
        ('Cropped Hoodie', 'Trendy cropped hoodie'),
        ('Yoga Leggings', 'High-waist yoga leggings'),
        ('Wrap Dress', 'Flattering wrap dress'),
        ('Off-Shoulder Top', 'Romantic off-shoulder top'),
        ('Utility Jacket', 'Lightweight utility jacket'),
        ('Classic Fit T-Shirt', 'Essential classic fit t-shirt'),
        ('Slim Fit Polo Shirt', 'Slim fit polo shirt'),
        ('Non-Iron Dress Shirt', 'Non-iron dress shirt'),
        ('Slim Fit Chinos', 'Slim fit chinos'),
        ('Straight Leg Jeans', 'Classic straight leg jeans'),
        ('Bomber Jacket', 'Lightweight bomber jacket'),
        ('Slim Fit Suit Jacket', 'Slim fit suit jacket'),
        ('Tech Fleece Hoodie', 'Tech fleece hoodie'),
        ('Training Joggers', 'Athletic joggers'),
        ('Long Sleeve Henley', 'Soft long sleeve henley'),
        ('Denim Trucker Jacket', 'Classic denim trucker jacket'),
        ('Merino Wool Sweater', 'Merino wool crewneck sweater'),
        ('Graphic Print T-Shirt', 'Fun graphic print t-shirt for kids'),
        ('Denim Overalls', 'Durable denim overalls'),
        ('Tutu Dress', 'Sparkly tutu dress'),
        ('Fleece Zip Hoodie', 'Warm fleece zip hoodie for kids'),
        ('Stretch Leggings', 'Comfortable stretch leggings'),
        ('Dinosaur Pajama Set', 'Cozy dinosaur pajama set'),
        ('Ruffle Sleeve Top', 'Adorable ruffle sleeve top'),
        ('Classic Leather Sneakers', 'Timeless leather sneakers'),
        ('Running Shoes', 'Performance running shoes'),
        ('Chelsea Boots', 'Sleek Chelsea boots'),
        ('Ankle Strap Sandals', 'Elegant ankle strap sandals'),
        ('Ballet Flats', 'Classic ballet flats'),
        ('Penny Loafers', 'Classic penny loafers'),
        ('Combat Boots', 'Durable combat boots'),
        ('Platform Sneakers', 'Trendy platform sneakers'),
        ('Strappy Heels', 'Elegant strappy heels'),
        ('Trail Running Shoes', 'All-terrain trail running shoes'),
        ('Slide Sandals', 'Comfortable slide sandals'),
        ('Basketball Shoes', 'High-top basketball shoes'),
        ('Hoop Earrings', 'Classic hoop earrings'),
        ('Pendant Necklace', 'Delicate pendant necklace'),
        ('Tennis Bracelet', 'Timeless tennis bracelet'),
        ('Stackable Rings Set', 'Set of stackable rings'),
        ('Leather Strap Watch', 'Classic leather strap watch'),
        ('Statement Necklace', 'Bold statement necklace'),
        ('Stud Earrings Set', 'Versatile stud earrings set'),
        ('Charm Bracelet', 'Personalized charm bracelet'),
        ('Signet Ring', 'Classic signet ring'),
        ('Chronograph Watch', 'Sporty chronograph watch')
)
INSERT INTO PRODUCTS (name, description)
SELECT base_name, description FROM sample_names CROSS JOIN generate_series(1, 10);

-- ============================================================================
-- ============================================================================
INSERT INTO ATTRIBUTES (name, data_type, unit, is_variant_attribute) VALUES
    ('Size', 'string', NULL, true), ('Color', 'string', NULL, true),
    ('Material', 'string', NULL, false), ('Sleeve Length', 'string', NULL, false),
    ('Neckline', 'string', NULL, false), ('Fit', 'string', NULL, false),
    ('Pattern', 'string', NULL, false), ('Occasion', 'string', NULL, false),
    ('Season', 'string', NULL, false), ('Gender', 'string', NULL, false),
    ('Metal Type', 'string', NULL, false), ('Gemstone', 'string', NULL, false);

-- ============================================================================
-- ============================================================================
INSERT INTO ATTRIBUTE_VALUES (attribute_id, value) VALUES
    (1, 'XS'),(1, 'S'),(1, 'M'),(1, 'L'),(1, 'XL'),(1, 'XXL'),(1, '2XL'),(1, '3XL'),(1, '4XL'),(1, '5XL'),
    (1, '0'),(1, '2'),(1, '4'),(1, '6'),(1, '8'),(1, '10'),(1, '12'),(1, '14'),(1, '16'),(1, '18'),
    (1, '28'),(1, '30'),(1, '32'),(1, '34'),(1, '36'),(1, '38'),(1, '40'),(1, '42'),(1, '44'),(1, '46'),
    (1, '7'),(1, '9'),(1, '11'),(1, '13'),(1, 'One Size'),
    (2, 'Black'),(2, 'White'),(2, 'Red'),(2, 'Blue'),(2, 'Green'),(2, 'Yellow'),(2, 'Pink'),(2, 'Purple'),
    (2, 'Orange'),(2, 'Brown'),(2, 'Grey'),(2, 'Navy'),(2, 'Beige'),(2, 'Burgundy'),(2, 'Olive'),
    (2, 'Teal'),(2, 'Coral'),(2, 'Mint'),(2, 'Lavender'),(2, 'Peach'),(2, 'Khaki'),(2, 'Denim Blue'),
    (2, 'Charcoal'),(2, 'Ivory'),(2, 'Maroon'),
    (3, 'Cotton'),(3, 'Polyester'),(3, 'Wool'),(3, 'Silk'),(3, 'Linen'),(3, 'Leather'),(3, 'Denim'),
    (3, 'Cashmere'),(3, 'Viscose'),(3, 'Nylon'),(3, 'Spandex'),(3, 'Acrylic'),(3, 'Fleece'),(3, 'Velvet'),
    (3, 'Canvas'),(3, 'Suede'),(3, 'Mesh'),(3, 'Jersey'),(3, 'Chiffon'),(3, 'Satin'),
    (4, 'Short'),(4, 'Long'),(4, 'Sleeveless'),(4, 'Three-Quarter'),(4, 'Cap'),
    (5, 'Crewneck'),(5, 'V-Neck'),(5, 'Scoop Neck'),(5, 'Turtleneck'),(5, 'Collared'),
    (5, 'Off-Shoulder'),(5, 'Square Neck'),(5, 'Sweetheart'),(5, 'Halter'),
    (6, 'Slim'),(6, 'Regular'),(6, 'Relaxed'),(6, 'Oversized'),(6, 'Athletic'),
    (6, 'Skinny'),(6, 'Straight'),(6, 'Bootcut'),(6, 'Wide'),
    (7, 'Solid'),(7, 'Striped'),(7, 'Floral'),(7, 'Plaid'),(7, 'Polka Dot'),
    (7, 'Animal Print'),(7, 'Camouflage'),(7, 'Geometric'),(7, 'Tie-Dye'),
    (8, 'Casual'),(8, 'Formal'),(8, 'Business'),(8, 'Party'),(8, 'Athletic'),
    (8, 'Beach'),(8, 'Wedding'),(8, 'Travel'),(8, 'Loungwear'),
    (9, 'Spring'),(9, 'Summer'),(9, 'Fall'),(9, 'Winter'),(9, 'All Season'),
    (10, 'Women'),(10, 'Men'),(10, 'Unisex'),(10, 'Girls'),(10, 'Boys'),(10, 'Baby'),
    (11, 'Gold'),(11, 'Silver'),(11, 'Rose Gold'),(11, 'Platinum'),
    (11, 'Stainless Steel'),(11, 'Brass'),(11, 'Copper'),
    (12, 'Diamond'),(12, 'Cubic Zirconia'),(12, 'Pearl'),(12, 'Sapphire'),
    (12, 'Emerald'),(12, 'Ruby'),(12, 'Amethyst'),(12, 'Topaz'),(12, 'None');

-- ============================================================================
-- ============================================================================
INSERT INTO PRODUCT_CATEGORIES (product_id, category_id)
SELECT p.id, COALESCE(
    CASE
        WHEN p.id % 30 BETWEEN 0 AND 5 THEN (SELECT id FROM CATEGORIES WHERE parent_id = 6 ORDER BY random() LIMIT 1)
        WHEN p.id % 30 BETWEEN 6 AND 9 THEN (SELECT id FROM CATEGORIES WHERE parent_id = 7 ORDER BY random() LIMIT 1)
        WHEN p.id % 30 BETWEEN 10 AND 13 THEN (SELECT id FROM CATEGORIES WHERE parent_id = 8 ORDER BY random() LIMIT 1)
        WHEN p.id % 30 BETWEEN 14 AND 15 THEN (SELECT id FROM CATEGORIES WHERE parent_id = 9 ORDER BY random() LIMIT 1)
        WHEN p.id % 30 BETWEEN 16 AND 17 THEN (SELECT id FROM CATEGORIES WHERE parent_id = 10 ORDER BY random() LIMIT 1)
        WHEN p.id % 30 BETWEEN 18 AND 20 THEN (SELECT id FROM CATEGORIES WHERE parent_id = 11 ORDER BY random() LIMIT 1)
        WHEN p.id % 30 = 21 THEN (SELECT id FROM CATEGORIES WHERE parent_id = 12 ORDER BY random() LIMIT 1)
        WHEN p.id % 30 = 22 THEN (SELECT id FROM CATEGORIES WHERE parent_id = 13 ORDER BY random() LIMIT 1)
        WHEN p.id % 30 BETWEEN 23 AND 24 THEN (SELECT id FROM CATEGORIES WHERE parent_id IN (19, 20, 25) ORDER BY random() LIMIT 1)
        WHEN p.id % 30 = 25 THEN (SELECT id FROM CATEGORIES WHERE parent_id = 21 ORDER BY random() LIMIT 1)
        WHEN p.id % 30 = 26 THEN (SELECT id FROM CATEGORIES WHERE parent_id IN (22, 23, 24) ORDER BY random() LIMIT 1)
        WHEN p.id % 30 BETWEEN 27 AND 29 THEN (SELECT id FROM CATEGORIES WHERE parent_id IN (26, 27, 28, 29, 30) ORDER BY random() LIMIT 1)
    END,
    (SELECT id FROM CATEGORIES WHERE parent_id IS NOT NULL ORDER BY random() LIMIT 1)
) FROM PRODUCTS p
ON CONFLICT (product_id, category_id) DO NOTHING;

-- ============================================================================

-- ============================================================================
WITH
color_subset AS (
    SELECT value AS color,
           CASE
               WHEN value = 'Black' THEN 'BLK' WHEN value = 'White' THEN 'WHT'
               WHEN value = 'Red' THEN 'RED' WHEN value = 'Blue' THEN 'BLU'
               WHEN value = 'Green' THEN 'GRN' WHEN value = 'Yellow' THEN 'YLW'
               WHEN value = 'Pink' THEN 'PNK' WHEN value = 'Purple' THEN 'PUR'
               WHEN value = 'Orange' THEN 'ORG' WHEN value = 'Brown' THEN 'BRN'
               WHEN value = 'Grey' THEN 'GRY' WHEN value = 'Navy' THEN 'NVY'
               WHEN value = 'Beige' THEN 'BGE' WHEN value = 'Burgundy' THEN 'BUR'
               WHEN value = 'Olive' THEN 'OLV' WHEN value = 'Teal' THEN 'TEA'
               WHEN value = 'Coral' THEN 'CRL' WHEN value = 'Mint' THEN 'MNT'
               WHEN value = 'Lavender' THEN 'LAV' WHEN value = 'Peach' THEN 'PCH'
               WHEN value = 'Khaki' THEN 'KHK' WHEN value = 'Denim Blue' THEN 'DNM'
               WHEN value = 'Charcoal' THEN 'CHR' WHEN value = 'Ivory' THEN 'IVR'
               WHEN value = 'Maroon' THEN 'MRN' ELSE UPPER(SUBSTRING(value, 1, 3))
           END AS color_code
    FROM ATTRIBUTE_VALUES WHERE attribute_id = 2
    ORDER BY random() LIMIT 6
),
size_subset AS (
    SELECT value AS size,
           CASE
               WHEN value = 'XS' THEN 'XS' WHEN value = 'S' THEN 'S' WHEN value = 'M' THEN 'M'
               WHEN value = 'L' THEN 'L' WHEN value = 'XL' THEN 'XL' WHEN value = 'XXL' THEN 'XXL'
               WHEN value = 'One Size' THEN 'OS' ELSE REPLACE(value, ' ', '')
           END AS size_code
    FROM ATTRIBUTE_VALUES WHERE attribute_id = 1
    ORDER BY random() LIMIT 4
),
variant_combinations AS (
    SELECT
        p.id AS product_id,
        cs.color_code,
        ss.size_code,
        (p.id % 35) + 1 AS brand_id,
        LPAD((FLOOR(RANDOM() * 1000000000000))::TEXT, 12, '0') AS barcode,
        ROUND((RANDOM() * 150 + 15)::NUMERIC, 2) AS price,
        CASE WHEN p.id % 10 = 0 THEN ROUND((RANDOM() * 2 + 0.1)::NUMERIC, 2) ELSE NULL END AS weight,
        CASE WHEN RANDOM() < 0.9 THEN 'ACTIVE' ELSE 'INACTIVE' END AS status,
        ROW_NUMBER() OVER (ORDER BY p.id, cs.color, ss.size) AS global_seq
    FROM PRODUCTS p
    CROSS JOIN color_subset cs
    CROSS JOIN size_subset ss
    WHERE RANDOM() < 0.8
    ORDER BY random()
    LIMIT 10000
)
INSERT INTO PRODUCT_VARIANTS (product_id, sku, brand_id, barcode, price, weight, status)
SELECT
    product_id,
    UPPER(
        LEFT(REGEXP_REPLACE((SELECT name FROM PRODUCTS WHERE id = product_id), '[^a-zA-Z0-9]', '', 'g'), 6)
        || '-' || color_code || '-' || size_code
        || '-' || LPAD((product_id % 1000)::TEXT, 3, '0')
        || '-' || LPAD(global_seq::TEXT, 5, '0')
    ) AS sku,
    brand_id, barcode, price, weight, status
FROM variant_combinations;

UPDATE PRODUCT_VARIANTS SET status = CASE WHEN RANDOM() < 0.05 THEN 'OUT_OF_STOCK' WHEN RANDOM() < 0.02 THEN 'DISCONTINUED' ELSE status END;

-- ============================================================================
-- ============================================================================
INSERT INTO PRODUCT_IMAGES (url, position, product_variants_id)
SELECT 'https://picsum.photos/seed/' || pv.id || pos.seq || '/400/400', pos.seq, pv.id
FROM PRODUCT_VARIANTS pv CROSS JOIN generate_series(1, 3) pos(seq)
WHERE pv.id % 3 = 0
ON CONFLICT (product_variants_id, position) DO NOTHING;

-- ============================================================================
-- ============================================================================
WITH size_attr AS (SELECT id FROM ATTRIBUTE_VALUES WHERE attribute_id = 1)
INSERT INTO VARIANT_ATTRIBUTES (product_variant_id, attribute_value_id, attribute_id)
SELECT pv.id, (SELECT id FROM size_attr ORDER BY random() LIMIT 1), 1
FROM PRODUCT_VARIANTS pv
ON CONFLICT (product_variant_id, attribute_value_id, attribute_id) DO NOTHING;

WITH color_attr AS (SELECT id FROM ATTRIBUTE_VALUES WHERE attribute_id = 2)
INSERT INTO VARIANT_ATTRIBUTES (product_variant_id, attribute_value_id, attribute_id)
SELECT pv.id, (SELECT id FROM color_attr ORDER BY random() LIMIT 1), 2
FROM PRODUCT_VARIANTS pv
ON CONFLICT (product_variant_id, attribute_value_id, attribute_id) DO NOTHING;

-- ============================================================================
-- ============================================================================
-- DO $$
-- BEGIN
--     RAISE NOTICE '========================================';
--     RAISE NOTICE 'BRANDS: %', (SELECT COUNT(*) FROM BRANDS);
--     RAISE NOTICE 'CATEGORIES: %', (SELECT COUNT(*) FROM CATEGORIES);
--     RAISE NOTICE 'PRODUCTS: %', (SELECT COUNT(*) FROM PRODUCTS);
--     RAISE NOTICE 'PRODUCT_VARIANTS: %', (SELECT COUNT(*) FROM PRODUCT_VARIANTS);
--     RAISE NOTICE 'PRODUCT_IMAGES: %', (SELECT COUNT(*) FROM PRODUCT_IMAGES);
--     RAISE NOTICE 'ATTRIBUTES: %', (SELECT COUNT(*) FROM ATTRIBUTES);
--     RAISE NOTICE 'ATTRIBUTE_VALUES: %', (SELECT COUNT(*) FROM ATTRIBUTE_VALUES);
--     RAISE NOTICE 'VARIANT_ATTRIBUTES: %', (SELECT COUNT(*) FROM VARIANT_ATTRIBUTES);
--     RAISE NOTICE 'PRODUCT_CATEGORIES: %', (SELECT COUNT(*) FROM PRODUCT_CATEGORIES);
--     RAISE NOTICE '========================================';
-- END $$;