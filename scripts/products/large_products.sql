-- Generated PostgreSQL catalog seed script
BEGIN;
SET LOCAL synchronous_commit = off;
SET LOCAL lock_timeout = '0';
SET LOCAL statement_timeout = '0';

CREATE OR REPLACE FUNCTION slug_code(name text)
    RETURNS text
    LANGUAGE sql
    IMMUTABLE
AS
$$
SELECT left(
               upper(regexp_replace(coalesce(name, ''), '[^A-Za-z0-9]+', '', 'g')),
               18
       );
$$;

CREATE OR REPLACE FUNCTION ean13_check_digit(base12 text)
    RETURNS text
    LANGUAGE sql
    IMMUTABLE
AS
$$
SELECT ((10 - (
    SUM(
            (substring(base12 from i for 1))::int *
            CASE WHEN i % 2 = 1 THEN 1 ELSE 3 END
    ) % 10
    )) % 10)::text
FROM generate_series(1, 12) AS gs(i);
$$;


CREATE OR REPLACE FUNCTION make_ean13(seq bigint)
    RETURNS text
    LANGUAGE sql
    IMMUTABLE
AS
$$
SELECT '59' || lpad(seq::text, 10, '0') ||
       ean13_check_digit('59' || lpad(seq::text, 10, '0'));
$$;

CREATE OR REPLACE FUNCTION pseudo_rand(key bigint, salt bigint)
    RETURNS numeric
    LANGUAGE sql
    IMMUTABLE
AS
$$
SELECT ((((key * 1103515245) + (salt * 12345)) % 1000000 + 1000000) % 1000000)::numeric / 1000000.0;
$$;

TRUNCATE TABLE
    variant_attributes,
    product_images,
    product_categories,
    product_variants,
    products,
    attribute_values,
    attributes,
    categories,
    brands
    RESTART IDENTITY CASCADE;


CREATE TEMP TABLE tmp_brands
(
    id   bigint PRIMARY KEY,
    name varchar(63) NOT NULL,
    code text        NOT NULL
) ON COMMIT DROP;


CREATE TEMP TABLE tmp_categories
(
    id        bigint PRIMARY KEY,
    name      varchar(63) NOT NULL,
    parent_id bigint
) ON COMMIT DROP;


CREATE TEMP TABLE tmp_attributes
(
    id                   bigint PRIMARY KEY,
    name                 varchar(63) NOT NULL,
    data_type            varchar(50) NOT NULL,
    unit                 varchar(50),
    is_variant_attribute boolean     NOT NULL
) ON COMMIT DROP;


CREATE TEMP TABLE tmp_attribute_values_lookup
(
    attribute_value_id bigint PRIMARY KEY,
    attribute_id       bigint      NOT NULL,
    attribute_name     varchar(63) NOT NULL,
    value              varchar(63) NOT NULL
) ON COMMIT DROP;


CREATE TEMP TABLE tmp_brand_category_candidates
(
    category_name varchar(63) NOT NULL,
    brand_rank    int         NOT NULL,
    brand_count   int         NOT NULL,
    brand_id      bigint      NOT NULL,
    brand_name    varchar(63) NOT NULL,
    brand_code    text        NOT NULL
) ON COMMIT DROP;


CREATE TEMP TABLE tmp_weighted_leafs
(
    ordinal       int PRIMARY KEY,
    category_name varchar(63) NOT NULL
) ON COMMIT DROP;


CREATE TEMP TABLE tmp_templates
(
    template_key  text PRIMARY KEY,
    category_name varchar(63)    NOT NULL,
    noun          varchar(63)    NOT NULL,
    adj1_pool     text[]         NOT NULL,
    adj2_pool     text[]         NOT NULL,
    desc1         text           NOT NULL,
    desc2         text           NOT NULL,
    desc3         text           NOT NULL,
    base_price    numeric(10, 2) NOT NULL,
    price_spread  numeric(10, 2) NOT NULL,
    base_weight   numeric(10, 2) NOT NULL,
    weight_spread numeric(10, 2) NOT NULL,
    axis_count    int            NOT NULL,
    combo_count   int            NOT NULL
) ON COMMIT DROP;


CREATE TEMP TABLE tmp_product_plan
(
    product_id       bigint PRIMARY KEY,
    product_index    int            NOT NULL,
    category_id      bigint         NOT NULL,
    category_name    varchar(63)    NOT NULL,
    category_code    text           NOT NULL,
    template_key     text           NOT NULL,
    brand_id         bigint         NOT NULL,
    brand_name       varchar(63)    NOT NULL,
    brand_code       text           NOT NULL,
    noun             varchar(63)    NOT NULL,
    desc1            text           NOT NULL,
    desc2            text           NOT NULL,
    desc3            text           NOT NULL,
    product_name     varchar(63)    NOT NULL,
    description      text,
    created_at       timestamp      NOT NULL,
    updated_at       timestamp      NOT NULL,
    combo_count      int            NOT NULL,
    variant_count    int            NOT NULL,
    variant_start_id bigint         NOT NULL,
    base_price       numeric(10, 2) NOT NULL,
    price_spread     numeric(10, 2) NOT NULL,
    base_weight      numeric(10, 2) NOT NULL,
    weight_spread    numeric(10, 2) NOT NULL
) ON COMMIT DROP;

INSERT INTO tmp_brands (id, name, code)
VALUES (1, 'Sony', 'SONY'),
       (2, 'Samsung', 'SAMSUNG'),
       (3, 'JBL', 'JBL'),
       (4, 'Anker', 'ANKER'),
       (5, 'Belkin', 'BELKIN'),
       (6, 'Logitech', 'LOGI'),
       (7, 'Xiaomi', 'XIAOMI'),
       (8, 'UGREEN', 'UGREEN'),
       (9, 'Baseus', 'BASEUS'),
       (10, 'Skullcandy', 'SKULL'),
       (11, 'Nike', 'NIKE'),
       (12, 'Adidas', 'ADIDAS'),
       (13, 'Puma', 'PUMA'),
       (14, 'Under Armour', 'UA'),
       (15, 'Uniqlo', 'UNIQLO'),
       (16, 'H&M', 'HM'),
       (17, 'Zara', 'ZARA'),
       (18, 'Gap', 'GAP'),
       (19, 'Columbia', 'COLUMBIA'),
       (20, 'The North Face', 'TNF'),
       (21, 'Reebok', 'REEBOK'),
       (22, 'Champion', 'CHAMPION'),
       (23, 'ASICS', 'ASICS'),
       (24, 'New Balance', 'NB'),
       (25, 'IKEA', 'IKEA'),
       (26, 'KitchenAid', 'KITCHENAID'),
       (27, 'OXO', 'OXO'),
       (28, 'Pyrex', 'PYREX'),
       (29, 'Rubbermaid', 'RUBBERMAID'),
       (30, 'Tefal', 'TEFAL'),
       (31, 'Philips', 'PHILIPS'),
       (32, 'Dyson', 'DYSON'),
       (33, 'Brabantia', 'BRABANTIA'),
       (34, 'Black+Decker', 'BDK'),
       (35, 'Joseph Joseph', 'JOSEPH'),
       (36, 'Vileda', 'VILEDA'),
       (37, 'Fellow', 'FELLOW'),
       (38, 'Decathlon', 'DECATHLON'),
       (39, 'Wilson', 'WILSON'),
       (40, 'CamelBak', 'CAMELBAK'),
       (41, 'Coleman', 'COLEMAN'),
       (42, 'Saucony', 'SAUCONY'),
       (43, 'Speedo', 'SPEEDO');
INSERT INTO tmp_categories (id, name, parent_id)
VALUES (1, 'Electronics', NULL),
       (2, 'Audio', 1),
       (3, 'Headphones', 2),
       (4, 'Earbuds', 2),
       (5, 'Accessories', 1),
       (6, 'Cables', 18),
       (7, 'Chargers', 18),
       (8, 'Power Banks', 18),
       (9, 'Clothing', NULL),
       (10, 'Tops', 9),
       (11, 'T-Shirts', 10),
       (12, 'Hoodies', 10),
       (13, 'Bottoms', 9),
       (14, 'Joggers', 13),
       (15, 'Leggings', 13),
       (16, 'Footwear', 9),
       (17, 'Sneakers', 16),
       (18, 'Accessories', 9),
       (19, 'Socks', 18),
       (20, 'Home & Kitchen', NULL),
       (21, 'Kitchen & Dining', 20),
       (22, 'Mugs', 21),
       (23, 'Water Bottles', 21),
       (24, 'Storage Containers', 21),
       (25, 'Towels', 21),
       (26, 'Home Organization', 20),
       (27, 'Storage Bins', 26),
       (28, 'Sports & Outdoors', NULL),
       (29, 'Fitness Accessories', 28),
       (30, 'Yoga Mats', 29),
       (31, 'Resistance Bands', 29),
       (32, 'Dumbbells', 29),
       (33, 'Shaker Bottles', 29);
INSERT INTO tmp_attributes (id, name, data_type, unit, is_variant_attribute)
VALUES (1, 'color', 'text', NULL, TRUE),
       (2, 'adult_size', 'text', NULL, TRUE),
       (3, 'kids_size', 'text', NULL, TRUE),
       (4, 'fit', 'text', NULL, TRUE),
       (5, 'shoe_size_us', 'text', NULL, TRUE),
       (6, 'width_fit', 'text', NULL, TRUE),
       (7, 'pack_size', 'text', NULL, TRUE),
       (8, 'finish', 'text', NULL, TRUE),
       (9, 'capacity_ml', 'integer', 'ml', TRUE),
       (10, 'capacity_mah', 'integer', 'mAh', TRUE),
       (11, 'lid_type', 'text', NULL, TRUE),
       (12, 'connector_type', 'text', NULL, TRUE),
       (13, 'wattage_w', 'integer', 'W', TRUE),
       (14, 'length_m', 'decimal', 'm', TRUE),
       (15, 'storage_size', 'text', NULL, TRUE),
       (16, 'material', 'text', NULL, TRUE),
       (17, 'resistance_level', 'text', NULL, TRUE),
       (18, 'set_size', 'text', NULL, TRUE),
       (19, 'mat_thickness_mm', 'decimal', 'mm', TRUE),
       (20, 'dumbbell_weight_kg', 'decimal', 'kg', TRUE),
       (21, 'towel_size', 'text', NULL, TRUE),
       (22, 'connection_type', 'text', NULL, TRUE),
       (23, 'gender', 'text', NULL, TRUE),
       (24, 'age_group', 'text', NULL, TRUE);
INSERT INTO tmp_attribute_values_lookup (attribute_value_id, attribute_id, attribute_name, value)
VALUES (1, 1, 'color', 'Black'),
       (2, 1, 'color', 'White'),
       (3, 1, 'color', 'Gray'),
       (4, 1, 'color', 'Navy'),
       (5, 1, 'color', 'Blue'),
       (6, 1, 'color', 'Red'),
       (7, 1, 'color', 'Green'),
       (8, 1, 'color', 'Pink'),
       (9, 2, 'adult_size', 'XS'),
       (10, 2, 'adult_size', 'S'),
       (11, 2, 'adult_size', 'M'),
       (12, 2, 'adult_size', 'L'),
       (13, 2, 'adult_size', 'XL'),
       (14, 2, 'adult_size', 'XXL'),
       (15, 3, 'kids_size', '2T'),
       (16, 3, 'kids_size', '3T'),
       (17, 3, 'kids_size', '4T'),
       (18, 3, 'kids_size', '5T'),
       (19, 3, 'kids_size', '6Y'),
       (20, 3, 'kids_size', '8Y'),
       (21, 4, 'fit', 'Slim Fit'),
       (22, 4, 'fit', 'Regular Fit'),
       (23, 4, 'fit', 'Relaxed Fit'),
       (24, 5, 'shoe_size_us', '6'),
       (25, 5, 'shoe_size_us', '7'),
       (26, 5, 'shoe_size_us', '8'),
       (27, 5, 'shoe_size_us', '9'),
       (28, 5, 'shoe_size_us', '10'),
       (29, 5, 'shoe_size_us', '11'),
       (30, 5, 'shoe_size_us', '12'),
       (31, 6, 'width_fit', 'Narrow'),
       (32, 6, 'width_fit', 'Regular'),
       (33, 6, 'width_fit', 'Wide'),
       (34, 7, 'pack_size', '1-Pack'),
       (35, 7, 'pack_size', '2-Pack'),
       (36, 7, 'pack_size', '3-Pack'),
       (37, 7, 'pack_size', '6-Pack'),
       (38, 8, 'finish', 'Matte'),
       (39, 8, 'finish', 'Gloss'),
       (40, 8, 'finish', 'Soft-Touch'),
       (41, 9, 'capacity_ml', '350'),
       (42, 9, 'capacity_ml', '500'),
       (43, 9, 'capacity_ml', '750'),
       (44, 9, 'capacity_ml', '1000'),
       (45, 10, 'capacity_mah', '5000'),
       (46, 10, 'capacity_mah', '10000'),
       (47, 10, 'capacity_mah', '20000'),
       (48, 10, 'capacity_mah', '30000'),
       (49, 11, 'lid_type', 'Flip Lid'),
       (50, 11, 'lid_type', 'Screw Lid'),
       (51, 11, 'lid_type', 'Straw Lid'),
       (52, 12, 'connector_type', 'USB-C'),
       (53, 12, 'connector_type', 'Lightning'),
       (54, 12, 'connector_type', 'Micro-USB'),
       (55, 13, 'wattage_w', '20'),
       (56, 13, 'wattage_w', '30'),
       (57, 13, 'wattage_w', '45'),
       (58, 13, 'wattage_w', '65'),
       (59, 14, 'length_m', '0.5'),
       (60, 14, 'length_m', '1'),
       (61, 14, 'length_m', '1.5'),
       (62, 14, 'length_m', '2'),
       (63, 15, 'storage_size', 'Small'),
       (64, 15, 'storage_size', 'Medium'),
       (65, 15, 'storage_size', 'Large'),
       (66, 15, 'storage_size', 'Extra Large'),
       (67, 16, 'material', 'Cotton'),
       (68, 16, 'material', 'Cotton Blend'),
       (69, 16, 'material', 'Polyester'),
       (70, 16, 'material', 'Stainless Steel'),
       (71, 16, 'material', 'BPA-Free Plastic'),
       (72, 16, 'material', 'Silicone'),
       (73, 16, 'material', 'Foam'),
       (74, 16, 'material', 'Rubber'),
       (75, 17, 'resistance_level', 'Light'),
       (76, 17, 'resistance_level', 'Medium'),
       (77, 17, 'resistance_level', 'Heavy'),
       (78, 17, 'resistance_level', 'Extra Heavy'),
       (79, 18, 'set_size', '2-Piece'),
       (80, 18, 'set_size', '3-Piece'),
       (81, 18, 'set_size', '5-Piece'),
       (82, 18, 'set_size', '10-Piece'),
       (83, 19, 'mat_thickness_mm', '4'),
       (84, 19, 'mat_thickness_mm', '6'),
       (85, 19, 'mat_thickness_mm', '8'),
       (86, 19, 'mat_thickness_mm', '10'),
       (87, 20, 'dumbbell_weight_kg', '1'),
       (88, 20, 'dumbbell_weight_kg', '2'),
       (89, 20, 'dumbbell_weight_kg', '3'),
       (90, 20, 'dumbbell_weight_kg', '5'),
       (91, 20, 'dumbbell_weight_kg', '7.5'),
       (92, 20, 'dumbbell_weight_kg', '10'),
       (93, 20, 'dumbbell_weight_kg', '12.5'),
       (94, 20, 'dumbbell_weight_kg', '15'),
       (95, 21, 'towel_size', 'Face Towel'),
       (96, 21, 'towel_size', 'Hand Towel'),
       (97, 21, 'towel_size', 'Bath Towel'),
       (98, 21, 'towel_size', 'Bath Sheet'),
       (99, 22, 'connection_type', 'Wired'),
       (100, 22, 'connection_type', 'Wireless'),
       (101, 23, 'gender', 'Men'),
       (102, 23, 'gender', 'Women'),
       (103, 23, 'gender', 'Unisex'),
       (104, 24, 'age_group', 'Adult'),
       (105, 24, 'age_group', 'Kids');
INSERT INTO tmp_brand_category_candidates (category_name, brand_rank, brand_count, brand_id, brand_name, brand_code)
VALUES ('Headphones', 1, 4, 1, 'Sony', 'SONY'),
       ('Headphones', 2, 4, 2, 'Samsung', 'SAMSUNG'),
       ('Headphones', 3, 4, 3, 'JBL', 'JBL'),
       ('Headphones', 4, 4, 10, 'Skullcandy', 'SKULL'),
       ('Earbuds', 1, 4, 1, 'Sony', 'SONY'),
       ('Earbuds', 2, 4, 2, 'Samsung', 'SAMSUNG'),
       ('Earbuds', 3, 4, 3, 'JBL', 'JBL'),
       ('Earbuds', 4, 4, 10, 'Skullcandy', 'SKULL'),
       ('Cables', 1, 6, 4, 'Anker', 'ANKER'),
       ('Cables', 2, 6, 5, 'Belkin', 'BELKIN'),
       ('Cables', 3, 6, 6, 'Logitech', 'LOGI'),
       ('Cables', 4, 6, 7, 'Xiaomi', 'XIAOMI'),
       ('Cables', 5, 6, 8, 'UGREEN', 'UGREEN'),
       ('Cables', 6, 6, 9, 'Baseus', 'BASEUS'),
       ('Chargers', 1, 6, 2, 'Samsung', 'SAMSUNG'),
       ('Chargers', 2, 6, 4, 'Anker', 'ANKER'),
       ('Chargers', 3, 6, 5, 'Belkin', 'BELKIN'),
       ('Chargers', 4, 6, 7, 'Xiaomi', 'XIAOMI'),
       ('Chargers', 5, 6, 8, 'UGREEN', 'UGREEN'),
       ('Chargers', 6, 6, 9, 'Baseus', 'BASEUS'),
       ('Power Banks', 1, 5, 2, 'Samsung', 'SAMSUNG'),
       ('Power Banks', 2, 5, 4, 'Anker', 'ANKER'),
       ('Power Banks', 3, 5, 7, 'Xiaomi', 'XIAOMI'),
       ('Power Banks', 4, 5, 8, 'UGREEN', 'UGREEN'),
       ('Power Banks', 5, 5, 9, 'Baseus', 'BASEUS'),
       ('T-Shirts', 1, 14, 11, 'Nike', 'NIKE'),
       ('T-Shirts', 2, 14, 12, 'Adidas', 'ADIDAS'),
       ('T-Shirts', 3, 14, 13, 'Puma', 'PUMA'),
       ('T-Shirts', 4, 14, 14, 'Under Armour', 'UA'),
       ('T-Shirts', 5, 14, 15, 'Uniqlo', 'UNIQLO'),
       ('T-Shirts', 6, 14, 16, 'H&M', 'HM'),
       ('T-Shirts', 7, 14, 17, 'Zara', 'ZARA'),
       ('T-Shirts', 8, 14, 18, 'Gap', 'GAP'),
       ('T-Shirts', 9, 14, 19, 'Columbia', 'COLUMBIA'),
       ('T-Shirts', 10, 14, 20, 'The North Face', 'TNF'),
       ('T-Shirts', 11, 14, 21, 'Reebok', 'REEBOK'),
       ('T-Shirts', 12, 14, 22, 'Champion', 'CHAMPION'),
       ('T-Shirts', 13, 14, 23, 'ASICS', 'ASICS'),
       ('T-Shirts', 14, 14, 24, 'New Balance', 'NB'),
       ('Hoodies', 1, 14, 11, 'Nike', 'NIKE'),
       ('Hoodies', 2, 14, 12, 'Adidas', 'ADIDAS'),
       ('Hoodies', 3, 14, 13, 'Puma', 'PUMA'),
       ('Hoodies', 4, 14, 14, 'Under Armour', 'UA'),
       ('Hoodies', 5, 14, 15, 'Uniqlo', 'UNIQLO'),
       ('Hoodies', 6, 14, 16, 'H&M', 'HM'),
       ('Hoodies', 7, 14, 17, 'Zara', 'ZARA'),
       ('Hoodies', 8, 14, 18, 'Gap', 'GAP'),
       ('Hoodies', 9, 14, 19, 'Columbia', 'COLUMBIA'),
       ('Hoodies', 10, 14, 20, 'The North Face', 'TNF'),
       ('Hoodies', 11, 14, 21, 'Reebok', 'REEBOK'),
       ('Hoodies', 12, 14, 22, 'Champion', 'CHAMPION'),
       ('Hoodies', 13, 14, 23, 'ASICS', 'ASICS'),
       ('Hoodies', 14, 14, 24, 'New Balance', 'NB'),
       ('Joggers', 1, 14, 11, 'Nike', 'NIKE'),
       ('Joggers', 2, 14, 12, 'Adidas', 'ADIDAS'),
       ('Joggers', 3, 14, 13, 'Puma', 'PUMA'),
       ('Joggers', 4, 14, 14, 'Under Armour', 'UA'),
       ('Joggers', 5, 14, 15, 'Uniqlo', 'UNIQLO'),
       ('Joggers', 6, 14, 16, 'H&M', 'HM'),
       ('Joggers', 7, 14, 17, 'Zara', 'ZARA'),
       ('Joggers', 8, 14, 18, 'Gap', 'GAP'),
       ('Joggers', 9, 14, 19, 'Columbia', 'COLUMBIA'),
       ('Joggers', 10, 14, 20, 'The North Face', 'TNF'),
       ('Joggers', 11, 14, 21, 'Reebok', 'REEBOK'),
       ('Joggers', 12, 14, 22, 'Champion', 'CHAMPION'),
       ('Joggers', 13, 14, 23, 'ASICS', 'ASICS'),
       ('Joggers', 14, 14, 24, 'New Balance', 'NB'),
       ('Leggings', 1, 13, 11, 'Nike', 'NIKE'),
       ('Leggings', 2, 13, 12, 'Adidas', 'ADIDAS'),
       ('Leggings', 3, 13, 13, 'Puma', 'PUMA'),
       ('Leggings', 4, 13, 14, 'Under Armour', 'UA'),
       ('Leggings', 5, 13, 15, 'Uniqlo', 'UNIQLO'),
       ('Leggings', 6, 13, 16, 'H&M', 'HM'),
       ('Leggings', 7, 13, 17, 'Zara', 'ZARA'),
       ('Leggings', 8, 13, 18, 'Gap', 'GAP'),
       ('Leggings', 9, 13, 19, 'Columbia', 'COLUMBIA'),
       ('Leggings', 10, 13, 20, 'The North Face', 'TNF'),
       ('Leggings', 11, 13, 21, 'Reebok', 'REEBOK'),
       ('Leggings', 12, 13, 23, 'ASICS', 'ASICS'),
       ('Leggings', 13, 13, 24, 'New Balance', 'NB'),
       ('Sneakers', 1, 9, 11, 'Nike', 'NIKE'),
       ('Sneakers', 2, 9, 12, 'Adidas', 'ADIDAS'),
       ('Sneakers', 3, 9, 13, 'Puma', 'PUMA'),
       ('Sneakers', 4, 9, 14, 'Under Armour', 'UA'),
       ('Sneakers', 5, 9, 19, 'Columbia', 'COLUMBIA'),
       ('Sneakers', 6, 9, 20, 'The North Face', 'TNF'),
       ('Sneakers', 7, 9, 21, 'Reebok', 'REEBOK'),
       ('Sneakers', 8, 9, 23, 'ASICS', 'ASICS'),
       ('Sneakers', 9, 9, 24, 'New Balance', 'NB'),
       ('Socks', 1, 14, 11, 'Nike', 'NIKE'),
       ('Socks', 2, 14, 12, 'Adidas', 'ADIDAS'),
       ('Socks', 3, 14, 13, 'Puma', 'PUMA'),
       ('Socks', 4, 14, 14, 'Under Armour', 'UA'),
       ('Socks', 5, 14, 15, 'Uniqlo', 'UNIQLO'),
       ('Socks', 6, 14, 16, 'H&M', 'HM'),
       ('Socks', 7, 14, 17, 'Zara', 'ZARA'),
       ('Socks', 8, 14, 18, 'Gap', 'GAP'),
       ('Socks', 9, 14, 19, 'Columbia', 'COLUMBIA'),
       ('Socks', 10, 14, 20, 'The North Face', 'TNF'),
       ('Socks', 11, 14, 21, 'Reebok', 'REEBOK'),
       ('Socks', 12, 14, 22, 'Champion', 'CHAMPION'),
       ('Socks', 13, 14, 23, 'ASICS', 'ASICS'),
       ('Socks', 14, 14, 24, 'New Balance', 'NB'),
       ('Mugs', 1, 7, 25, 'IKEA', 'IKEA'),
       ('Mugs', 2, 7, 26, 'KitchenAid', 'KITCHENAID'),
       ('Mugs', 3, 7, 27, 'OXO', 'OXO'),
       ('Mugs', 4, 7, 28, 'Pyrex', 'PYREX'),
       ('Mugs', 5, 7, 30, 'Tefal', 'TEFAL'),
       ('Mugs', 6, 7, 35, 'Joseph Joseph', 'JOSEPH'),
       ('Mugs', 7, 7, 37, 'Fellow', 'FELLOW'),
       ('Water Bottles', 1, 10, 25, 'IKEA', 'IKEA'),
       ('Water Bottles', 2, 10, 26, 'KitchenAid', 'KITCHENAID'),
       ('Water Bottles', 3, 10, 27, 'OXO', 'OXO'),
       ('Water Bottles', 4, 10, 28, 'Pyrex', 'PYREX'),
       ('Water Bottles', 5, 10, 29, 'Rubbermaid', 'RUBBERMAID'),
       ('Water Bottles', 6, 10, 30, 'Tefal', 'TEFAL'),
       ('Water Bottles', 7, 10, 31, 'Philips', 'PHILIPS'),
       ('Water Bottles', 8, 10, 37, 'Fellow', 'FELLOW'),
       ('Water Bottles', 9, 10, 40, 'CamelBak', 'CAMELBAK'),
       ('Water Bottles', 10, 10, 41, 'Coleman', 'COLEMAN'),
       ('Storage Containers', 1, 10, 25, 'IKEA', 'IKEA'),
       ('Storage Containers', 2, 10, 26, 'KitchenAid', 'KITCHENAID'),
       ('Storage Containers', 3, 10, 27, 'OXO', 'OXO'),
       ('Storage Containers', 4, 10, 28, 'Pyrex', 'PYREX'),
       ('Storage Containers', 5, 10, 29, 'Rubbermaid', 'RUBBERMAID'),
       ('Storage Containers', 6, 10, 30, 'Tefal', 'TEFAL'),
       ('Storage Containers', 7, 10, 31, 'Philips', 'PHILIPS'),
       ('Storage Containers', 8, 10, 33, 'Brabantia', 'BRABANTIA'),
       ('Storage Containers', 9, 10, 34, 'Black+Decker', 'BDK'),
       ('Storage Containers', 10, 10, 35, 'Joseph Joseph', 'JOSEPH'),
       ('Towels', 1, 5, 25, 'IKEA', 'IKEA'),
       ('Towels', 2, 5, 31, 'Philips', 'PHILIPS'),
       ('Towels', 3, 5, 32, 'Dyson', 'DYSON'),
       ('Towels', 4, 5, 33, 'Brabantia', 'BRABANTIA'),
       ('Towels', 5, 5, 36, 'Vileda', 'VILEDA'),
       ('Storage Bins', 1, 8, 25, 'IKEA', 'IKEA'),
       ('Storage Bins', 2, 8, 27, 'OXO', 'OXO'),
       ('Storage Bins', 3, 8, 29, 'Rubbermaid', 'RUBBERMAID'),
       ('Storage Bins', 4, 8, 32, 'Dyson', 'DYSON'),
       ('Storage Bins', 5, 8, 33, 'Brabantia', 'BRABANTIA'),
       ('Storage Bins', 6, 8, 34, 'Black+Decker', 'BDK'),
       ('Storage Bins', 7, 8, 35, 'Joseph Joseph', 'JOSEPH'),
       ('Storage Bins', 8, 8, 36, 'Vileda', 'VILEDA'),
       ('Yoga Mats', 1, 4, 38, 'Decathlon', 'DECATHLON'),
       ('Yoga Mats', 2, 4, 41, 'Coleman', 'COLEMAN'),
       ('Yoga Mats', 3, 4, 42, 'Saucony', 'SAUCONY'),
       ('Yoga Mats', 4, 4, 43, 'Speedo', 'SPEEDO'),
       ('Resistance Bands', 1, 4, 38, 'Decathlon', 'DECATHLON'),
       ('Resistance Bands', 2, 4, 39, 'Wilson', 'WILSON'),
       ('Resistance Bands', 3, 4, 42, 'Saucony', 'SAUCONY'),
       ('Resistance Bands', 4, 4, 43, 'Speedo', 'SPEEDO'),
       ('Dumbbells', 1, 2, 38, 'Decathlon', 'DECATHLON'),
       ('Dumbbells', 2, 2, 39, 'Wilson', 'WILSON'),
       ('Shaker Bottles', 1, 6, 38, 'Decathlon', 'DECATHLON'),
       ('Shaker Bottles', 2, 6, 39, 'Wilson', 'WILSON'),
       ('Shaker Bottles', 3, 6, 40, 'CamelBak', 'CAMELBAK'),
       ('Shaker Bottles', 4, 6, 41, 'Coleman', 'COLEMAN'),
       ('Shaker Bottles', 5, 6, 42, 'Saucony', 'SAUCONY'),
       ('Shaker Bottles', 6, 6, 43, 'Speedo', 'SPEEDO');
INSERT INTO tmp_weighted_leafs (ordinal, category_name)
VALUES (1, 'Headphones'),
       (2, 'Headphones'),
       (3, 'Headphones'),
       (4, 'Earbuds'),
       (5, 'Earbuds'),
       (6, 'Earbuds'),
       (7, 'Cables'),
       (8, 'Cables'),
       (9, 'Cables'),
       (10, 'Cables'),
       (11, 'Chargers'),
       (12, 'Chargers'),
       (13, 'Chargers'),
       (14, 'Chargers'),
       (15, 'Power Banks'),
       (16, 'Power Banks'),
       (17, 'Power Banks'),
       (18, 'T-Shirts'),
       (19, 'T-Shirts'),
       (20, 'T-Shirts'),
       (21, 'T-Shirts'),
       (22, 'Hoodies'),
       (23, 'Hoodies'),
       (24, 'Hoodies'),
       (25, 'Joggers'),
       (26, 'Joggers'),
       (27, 'Joggers'),
       (28, 'Joggers'),
       (29, 'Leggings'),
       (30, 'Leggings'),
       (31, 'Leggings'),
       (32, 'Sneakers'),
       (33, 'Sneakers'),
       (34, 'Sneakers'),
       (35, 'Socks'),
       (36, 'Socks'),
       (37, 'Mugs'),
       (38, 'Mugs'),
       (39, 'Mugs'),
       (40, 'Mugs'),
       (41, 'Water Bottles'),
       (42, 'Water Bottles'),
       (43, 'Water Bottles'),
       (44, 'Water Bottles'),
       (45, 'Storage Containers'),
       (46, 'Storage Containers'),
       (47, 'Storage Containers'),
       (48, 'Storage Containers'),
       (49, 'Towels'),
       (50, 'Towels'),
       (51, 'Towels'),
       (52, 'Towels'),
       (53, 'Storage Bins'),
       (54, 'Storage Bins'),
       (55, 'Storage Bins'),
       (56, 'Yoga Mats'),
       (57, 'Yoga Mats'),
       (58, 'Yoga Mats'),
       (59, 'Resistance Bands'),
       (60, 'Resistance Bands'),
       (61, 'Resistance Bands'),
       (62, 'Dumbbells'),
       (63, 'Dumbbells'),
       (64, 'Shaker Bottles'),
       (65, 'Shaker Bottles'),
       (66, 'Shaker Bottles');
INSERT INTO tmp_templates (template_key, category_name, noun, adj1_pool, adj2_pool, desc1, desc2, desc3, base_price,
                           price_spread, base_weight, weight_spread, axis_count, combo_count)
VALUES ('men_tshirt', 'T-Shirts', 'T-Shirt',
        ARRAY ['Classic', 'Essential', 'Everyday', 'Soft', 'Breathable', 'Lightweight', 'Stretch', 'Modern']::text[],
        ARRAY ['Crew', 'Core', 'Active', 'Clean', 'Relaxed', 'Premium', 'Street', 'Urban']::text[],
        'cotton-blend jersey', 'everyday comfort', 'versatile layering', '18.00', '14.00', '0.18', '0.07', 5, 144),
       ('men_hoodie', 'Hoodies', 'Hoodie',
        ARRAY ['Classic', 'Essential', 'Heavyweight', 'Cozy', 'Soft', 'Relaxed', 'Thermal', 'Active']::text[],
        ARRAY ['Pullover', 'Zip', 'Core', 'Street', 'Premium', 'Oversized', 'Urban', 'Layered']::text[],
        'fleece warmth', 'soft brushed interior', 'all-day comfort', '38.00', '24.00', '0.55', '0.25', 5, 144),
       ('men_joggers', 'Joggers', 'Jogger',
        ARRAY ['Classic', 'Essential', 'Everyday', 'Stretch', 'Slim', 'Relaxed', 'Lightweight', 'Training']::text[],
        ARRAY ['Core', 'Performance', 'Urban', 'Commuter', 'Premium', 'Active', 'Flex', 'Street']::text[],
        'tapered fit', 'stretch comfort', 'daily wear', '32.00', '18.00', '0.42', '0.18', 5, 144),
       ('men_socks', 'Socks', 'Sock',
        ARRAY ['Crew', 'Ankle', 'Athletic', 'Comfort', 'Everyday', 'Breathable', 'Cushioned', 'Dry']::text[],
        ARRAY ['Core', 'Active', 'Training', 'Daily', 'Performance', 'Stretch', 'Soft', 'Modern']::text[],
        'cushioned sole', 'breathable knit', 'multi-pack basics', '12.00', '8.00', '0.08', '0.03', 5, 192),
       ('men_sneakers', 'Sneakers', 'Sneaker',
        ARRAY ['Classic', 'Retro', 'Lightweight', 'Runner', 'Street', 'Court', 'Training', 'Urban']::text[],
        ARRAY ['Core', 'Performance', 'Comfort', 'Premium', 'Everyday', 'Active', 'Fly', 'Pulse']::text[],
        'all-day cushioning', 'supportive fit', 'sport-inspired design', '78.00', '60.00', '0.95', '0.32', 5, 168),
       ('women_tshirt', 'T-Shirts', 'T-Shirt',
        ARRAY ['Classic', 'Essential', 'Soft', 'Breathable', 'Lightweight', 'Relaxed', 'Modern', 'Clean']::text[],
        ARRAY ['Crew', 'Core', 'Street', 'Everyday', 'Premium', 'Urban', 'Active', 'Layered']::text[],
        'cotton-blend jersey', 'everyday comfort', 'versatile styling', '18.00', '14.00', '0.17', '0.06', 5, 144),
       ('women_hoodie', 'Hoodies', 'Hoodie',
        ARRAY ['Classic', 'Essential', 'Cozy', 'Soft', 'Relaxed', 'Thermal', 'Modern', 'Premium']::text[],
        ARRAY ['Pullover', 'Zip', 'Core', 'Street', 'Oversized', 'Urban', 'Layered', 'Active']::text[], 'fleece warmth',
        'soft brushed interior', 'easy layering', '40.00', '26.00', '0.58', '0.24', 5, 144),
       ('women_leggings', 'Leggings', 'Legging',
        ARRAY ['Classic', 'Essential', 'High-Rise', 'Soft', 'Stretch', 'Support', 'Lightweight', 'Training']::text[],
        ARRAY ['Core', 'Performance', 'Everyday', 'Studio', 'Premium', 'Flex', 'Urban', 'Active']::text[],
        'four-way stretch', 'comfortable waistband', 'studio-ready fit', '30.00', '18.00', '0.32', '0.16', 5, 144),
       ('women_socks', 'Socks', 'Sock',
        ARRAY ['Crew', 'Ankle', 'Athletic', 'Comfort', 'Everyday', 'Breathable', 'Cushioned', 'Dry']::text[],
        ARRAY ['Core', 'Active', 'Training', 'Daily', 'Performance', 'Stretch', 'Soft', 'Modern']::text[],
        'cushioned sole', 'breathable knit', 'multi-pack basics', '12.00', '8.00', '0.08', '0.03', 5, 192),
       ('women_sneakers', 'Sneakers', 'Sneaker',
        ARRAY ['Classic', 'Retro', 'Lightweight', 'Runner', 'Street', 'Court', 'Training', 'Urban']::text[],
        ARRAY ['Core', 'Performance', 'Comfort', 'Premium', 'Everyday', 'Active', 'Fly', 'Pulse']::text[],
        'all-day cushioning', 'supportive fit', 'sport-inspired design', '80.00', '65.00', '0.90', '0.30', 5, 168),
       ('kids_tshirt', 'T-Shirts', 'T-Shirt',
        ARRAY ['Classic', 'Soft', 'Everyday', 'Bright', 'Play', 'Lightweight', 'Comfort', 'Active']::text[],
        ARRAY ['Crew', 'Core', 'Fun', 'Easy', 'Premium', 'Urban', 'Mini', 'Fresh']::text[], 'soft cotton blend',
        'playground comfort', 'easy-care basics', '14.00', '10.00', '0.14', '0.05', 5, 144),
       ('kids_hoodie', 'Hoodies', 'Hoodie',
        ARRAY ['Classic', 'Cozy', 'Soft', 'Warm', 'Bright', 'Easy', 'Lightweight', 'Play']::text[],
        ARRAY ['Pullover', 'Zip', 'Core', 'Mini', 'Comfort', 'Everyday', 'Layered', 'Active']::text[],
        'warm fleece feel', 'easy layering', 'kid-friendly comfort', '24.00', '14.00', '0.40', '0.16', 5, 144),
       ('kids_socks', 'Socks', 'Sock',
        ARRAY ['Crew', 'Ankle', 'Athletic', 'Comfort', 'Everyday', 'Play', 'Cushioned', 'Bright']::text[],
        ARRAY ['Core', 'Active', 'School', 'Daily', 'Stretch', 'Soft', 'Mini', 'Fresh']::text[], 'soft knit comfort',
        'school-day basics', 'multi-pack essentials', '8.00', '6.00', '0.06', '0.02', 5, 192),
       ('mugs', 'Mugs', 'Mug',
        ARRAY ['Classic', 'Minimal', 'Everyday', 'Insulated', 'Ceramic', 'Cozy', 'Modern', 'Stackable']::text[],
        ARRAY ['Core', 'Kitchen', 'Morning', 'Premium', 'Clean', 'Home', 'Studio', 'Warm']::text[], 'ceramic drinkware',
        'daily coffee routine', 'dishwasher-friendly design', '12.00', '10.00', '0.34', '0.10', 3, 96),
       ('water_bottles', 'Water Bottles', 'Water Bottle',
        ARRAY ['Insulated', 'Classic', 'Everyday', 'Sport', 'Travel', 'Hydro', 'Minimal', 'Modern']::text[],
        ARRAY ['Core', 'Steel', 'Grip', 'Premium', 'Clean', 'Active', 'Trail', 'Fresh']::text[],
        'double-wall insulation', 'reliable hydration', 'on-the-go convenience', '18.00', '18.00', '0.42', '0.16', 3,
        96),
       ('storage_containers', 'Storage Containers', 'Storage Container',
        ARRAY ['Stackable', 'Compact', 'Leakproof', 'Modular', 'Everyday', 'Clear', 'Space-Saving', 'Fresh']::text[],
        ARRAY ['Kitchen', 'Pantry', 'Core', 'Smart', 'Clean', 'Home', 'Durable', 'Easy']::text[], 'airtight storage',
        'pantry organization', 'easy nesting', '16.00', '12.00', '0.28', '0.10', 3, 128),
       ('towels', 'Towels', 'Towel',
        ARRAY ['Soft', 'Absorbent', 'Plush', 'Everyday', 'Quick-Dry', 'Hotel', 'Classic', 'Fresh']::text[],
        ARRAY ['Home', 'Bath', 'Core', 'Clean', 'Premium', 'Spa', 'Comfort', 'Bright']::text[], 'soft terry loops',
        'bathroom staple', 'quick-dry comfort', '14.00', '12.00', '0.55', '0.18', 3, 128),
       ('storage_bins', 'Storage Bins', 'Storage Bin',
        ARRAY ['Stackable', 'Compact', 'Roomy', 'Everyday', 'Durable', 'Minimal', 'Organized', 'Modern']::text[],
        ARRAY ['Home', 'Core', 'Utility', 'Clean', 'Space-Saving', 'Premium', 'Flexible', 'Easy']::text[],
        'home organization', 'garage and closet storage', 'stack-friendly design', '20.00', '15.00', '0.60', '0.20', 3,
        128),
       ('yoga_mats', 'Yoga Mats', 'Yoga Mat',
        ARRAY ['Lightweight', 'Stable', 'Non-Slip', 'Comfort', 'Travel', 'Studio', 'Classic', 'Flexible']::text[],
        ARRAY ['Core', 'Performance', 'Grip', 'Active', 'Everyday', 'Premium', 'Clean', 'Zen']::text[],
        'stable practice surface', 'comfortable cushioning', 'portable fitness gear', '24.00', '22.00', '1.10', '0.40',
        3, 128),
       ('resistance_bands', 'Resistance Bands', 'Resistance Band',
        ARRAY ['Lightweight', 'Flexible', 'Training', 'Core', 'Travel', 'Classic', 'Strong', 'Active']::text[],
        ARRAY ['Grip', 'Performance', 'Studio', 'Everyday', 'Premium', 'Power', 'Clean', 'Flow']::text[],
        'strength training essential', 'portable workout accessory', 'progressive resistance', '11.00', '11.00', '0.12',
        '0.05', 3, 128),
       ('dumbbells', 'Dumbbells', 'Dumbbell',
        ARRAY ['Hex', 'Classic', 'Rubber', 'Compact', 'Core', 'Gym', 'Stable', 'Heavy-Duty']::text[],
        ARRAY ['Training', 'Performance', 'Home', 'Everyday', 'Pro', 'Grip', 'Steel', 'Strong']::text[],
        'strength training essential', 'solid grip feel', 'home-gym staple', '22.00', '20.00', '1.50', '1.00', 2, 24),
       ('shaker_bottles', 'Shaker Bottles', 'Shaker Bottle',
        ARRAY ['Classic', 'Sport', 'Protein', 'Everyday', 'Travel', 'Grip', 'Fresh', 'Hydrate']::text[],
        ARRAY ['Core', 'Active', 'Clean', 'Premium', 'Gym', 'Utility', 'Mix', 'Strong']::text[], 'smooth mixing',
        'gym-ready hydration', 'leak-resistant lid', '10.00', '10.00', '0.22', '0.07', 3, 96),
       ('headphones', 'Headphones', 'Headphones',
        ARRAY ['Wireless', 'Noise-Cancelling', 'Compact', 'Studio', 'Everyday', 'Premium', 'Foldable', 'Portable']::text[],
        ARRAY ['Sound', 'Core', 'Comfort', 'Travel', 'Pro', 'Immersive', 'Urban', 'Active']::text[],
        'over-ear listening', 'comfortable cushions', 'daily audio use', '58.00', '80.00', '0.30', '0.12', 3, 48),
       ('earbuds', 'Earbuds', 'Earbuds',
        ARRAY ['Wireless', 'Compact', 'Noise-Isolating', 'Travel', 'Everyday', 'Premium', 'Pocket', 'Sport']::text[],
        ARRAY ['Sound', 'Core', 'Comfort', 'Pro', 'Immersive', 'Urban', 'Active', 'Clean']::text[], 'in-ear listening',
        'portable charging case', 'all-day convenience', '48.00', '72.00', '0.06', '0.03', 3, 48),
       ('cables', 'Cables', 'Cable',
        ARRAY ['Braided', 'Fast-Charge', 'Durable', 'Slim', 'Travel', 'Flexible', 'Premium', 'Heavy-Duty']::text[],
        ARRAY ['Core', 'Power', 'Sync', 'Clean', 'Universal', 'Pro', 'Tough', 'Everyday']::text[],
        'reliable charging and sync', 'tangle-resistant build', 'daily accessory', '9.00', '9.00', '0.08', '0.03', 3,
        96),
       ('chargers', 'Chargers', 'Charger',
        ARRAY ['Fast', 'Compact', 'GaN', 'Travel', 'Premium', 'Power', 'Slim', 'Smart']::text[],
        ARRAY ['Core', 'Wall', 'Desk', 'Clean', 'Universal', 'Pro', 'Safe', 'Everyday']::text[], 'fast charging',
        'compact power delivery', 'daily charging solution', '18.00', '18.00', '0.12', '0.05', 3, 96),
       ('power_banks', 'Power Banks', 'Power Bank',
        ARRAY ['Portable', 'Slim', 'Fast-Charge', 'Travel', 'Premium', 'Pocket', 'Durable', 'Power']::text[],
        ARRAY ['Core', 'Charge', 'Everyday', 'Clean', 'Pro', 'Boost', 'Compact', 'Safe']::text[],
        'backup battery power', 'portable charging', 'travel-friendly design', '24.00', '28.00', '0.28', '0.12', 3, 96);

INSERT INTO brands (id, name)
SELECT id, name
FROM tmp_brands
ORDER BY id;


INSERT INTO categories (id, name, parent_id)
SELECT id, name, parent_id
FROM tmp_categories
ORDER BY id;


INSERT INTO attributes (id, name, data_type, unit, is_variant_attribute)
SELECT id, name, data_type, unit, is_variant_attribute
FROM tmp_attributes
ORDER BY id;


INSERT INTO attribute_values (id, attribute_id, value)
SELECT attribute_value_id, attribute_id, value
FROM tmp_attribute_values_lookup
ORDER BY attribute_value_id;


INSERT INTO tmp_product_plan (product_id, product_index, category_id, category_name, category_code, template_key,
                              brand_id, brand_name, brand_code, noun, desc1, desc2, desc3, product_name, description,
                              created_at, updated_at, combo_count, variant_count, variant_start_id, base_price,
                              price_spread, base_weight, weight_spread)
WITH leaf_count AS (SELECT count(*)::int AS n
                    FROM tmp_weighted_leafs),
     series AS (SELECT gs AS product_index
                FROM generate_series(1, 100000) AS gs),
     base AS (SELECT s.product_index,
                     wl.category_name,
                     c.id                                                                                  AS category_id,
                     t.template_key,
                     t.noun,
                     t.adj1_pool,
                     t.adj2_pool,
                     t.desc1,
                     t.desc2,
                     t.desc3,
                     t.base_price,
                     t.price_spread,
                     t.base_weight,
                     t.weight_spread,
                     t.combo_count,
                     (row_number() OVER (PARTITION BY wl.category_name ORDER BY s.product_index) -
                      1)::int                                                                              AS category_occurrence,
                     sum(t.combo_count) OVER (ORDER BY s.product_index)                                    AS cumulative_variants
              FROM series s
                       CROSS JOIN leaf_count lc
                       JOIN tmp_weighted_leafs wl
                            ON wl.ordinal = (((s.product_index - 1) % lc.n) + 1)
                       JOIN tmp_templates t
                            ON t.category_name = wl.category_name
                       JOIN tmp_categories c
                            ON c.name = wl.category_name),
     branded AS (SELECT b.*,
                        bc.brand_id,
                        bc.brand_name,
                        bc.brand_code,
                        bc.brand_count
                 FROM base b
                          JOIN tmp_brand_category_candidates bc
                               ON bc.category_name = b.category_name
                                   AND bc.brand_rank = ((b.category_occurrence % bc.brand_count) + 1)),
     filtered AS (SELECT *,
                         LEAST(combo_count, 3000000 - (cumulative_variants - combo_count))::int AS variant_count
                  FROM branded
                  WHERE (cumulative_variants - combo_count) < 3000000),
     final AS (SELECT row_number() OVER (ORDER BY product_index, template_key)::bigint AS product_id,
                      product_index,
                      category_id,
                      category_name,
                      slug_code(category_name)                                         AS category_code,
                      template_key,
                      brand_id,
                      brand_name,
                      brand_code,
                      noun,
                      desc1,
                      desc2,
                      desc3,
                      LEFT(
                              CASE ((product_index - 1) % 3)
                                  WHEN 0 THEN brand_name || ' ' ||
                                              adj1_pool[((product_index - 1) % array_length(adj1_pool, 1)) + 1] ||
                                              ' ' || noun
                                  WHEN 1 THEN brand_name || ' ' ||
                                              adj1_pool[((product_index - 1) % array_length(adj1_pool, 1)) + 1] ||
                                              ' ' ||
                                              adj2_pool[(((product_index - 1) / array_length(adj1_pool, 1)) %
                                                         array_length(adj2_pool, 1)) + 1] || ' ' || noun
                                  ELSE brand_name || ' ' || adj2_pool[
                                      (((product_index - 1) / array_length(adj1_pool, 1)) %
                                       array_length(adj2_pool, 1)) + 1] || ' ' || noun
                                  END,
                              63
                      )                                                                AS product_name,
                      base_price,
                      price_spread,
                      base_weight,
                      weight_spread,
                      combo_count,
                      variant_count,
                      COALESCE(
                                      SUM(variant_count)
                                      OVER (ORDER BY product_index, template_key, brand_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING),
                                      0
                      )::bigint + 1                                                    AS variant_start_id
               FROM filtered),
     stamped AS (SELECT final.*,
                        timestamp '2021-01-01 00:00:00'
                            + make_interval(secs => floor(pseudo_rand(product_id, 101) * extract(epoch from
                                                                                                 (current_timestamp - timestamp '2021-01-01 00:00:00')))::int) AS created_at,
                        LEAST(
                                timestamp '2021-01-01 00:00:00'
                                    + make_interval(secs => floor(pseudo_rand(product_id, 101) * extract(epoch from
                                                                                                         (current_timestamp - timestamp '2021-01-01 00:00:00')))::int)
                                    + make_interval(secs => floor(pseudo_rand(product_id, 102) * 31536000)::int),
                                current_timestamp
                        )                                                                                                                                      AS updated_at
                 FROM final)
SELECT product_id,
       product_index,
       category_id,
       category_name,
       category_code,
       template_key,
       brand_id,
       brand_name,
       brand_code,
       noun,
       desc1,
       desc2,
       desc3,
       product_name,
       (brand_name || ' ' || lower(noun) || ' designed for ' || desc1 || '. Built for ' || desc2 || ' and ' || desc3 ||
        '.') AS description,
       created_at,
       updated_at,
       combo_count,
       variant_count,
       variant_start_id,
       base_price,
       price_spread,
       base_weight,
       weight_spread
FROM stamped
ORDER BY product_id;


INSERT INTO products (id, name, description, created_at, updated_at)
SELECT product_id, product_name, description, created_at, updated_at
FROM tmp_product_plan
ORDER BY product_id;


INSERT INTO product_categories (product_id, category_id)
SELECT product_id, category_id
FROM tmp_product_plan
ORDER BY product_id;

CREATE TEMP TABLE tmp_variant_rows ON COMMIT DROP AS
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'adult_size', base.adult_size, 'fit', base.fit, 'gender', base.gender,
                          'age_group', base.age_group)                                         AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['XS', 'S', 'M', 'L', 'XL', 'XXL']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                       AS adult_size,
             (ARRAY ['Slim Fit', 'Regular Fit', 'Relaxed Fit']::text[])[(((((gs.variant_index - 1) / 48) % 3) + 1))]              AS fit,
             (ARRAY ['Men']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                                AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'men_tshirt') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'adult_size', base.adult_size, 'fit', base.fit, 'gender', base.gender,
                          'age_group', base.age_group)                                         AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['XS', 'S', 'M', 'L', 'XL', 'XXL']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                       AS adult_size,
             (ARRAY ['Slim Fit', 'Regular Fit', 'Relaxed Fit']::text[])[(((((gs.variant_index - 1) / 48) % 3) + 1))]              AS fit,
             (ARRAY ['Men']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                                AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'men_hoodie') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'adult_size', base.adult_size, 'fit', base.fit, 'gender', base.gender,
                          'age_group', base.age_group)                                         AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['XS', 'S', 'M', 'L', 'XL', 'XXL']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                       AS adult_size,
             (ARRAY ['Slim Fit', 'Regular Fit', 'Relaxed Fit']::text[])[(((((gs.variant_index - 1) / 48) % 3) + 1))]              AS fit,
             (ARRAY ['Men']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                                AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'men_joggers') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'adult_size', base.adult_size, 'pack_size', base.pack_size, 'gender',
                          base.gender, 'age_group', base.age_group)                            AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['XS', 'S', 'M', 'L', 'XL', 'XXL']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                       AS adult_size,
             (ARRAY ['1-Pack', '2-Pack', '3-Pack', '6-Pack']::text[])[(((((gs.variant_index - 1) / 48) % 4) + 1))]                AS pack_size,
             (ARRAY ['Men']::text[])[(((((gs.variant_index - 1) / 192) % 1) + 1))]                                                AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 192) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'men_socks') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'shoe_size_us', base.shoe_size_us, 'width_fit', base.width_fit, 'gender',
                          base.gender, 'age_group', base.age_group)                            AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['6', '7', '8', '9', '10', '11', '12']::text[])[(((((gs.variant_index - 1) / 8) % 7) + 1))]                   AS shoe_size_us,
             (ARRAY ['Narrow', 'Regular', 'Wide']::text[])[(((((gs.variant_index - 1) / 56) % 3) + 1))]                           AS width_fit,
             (ARRAY ['Men']::text[])[(((((gs.variant_index - 1) / 168) % 1) + 1))]                                                AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 168) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'men_sneakers') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'adult_size', base.adult_size, 'fit', base.fit, 'gender', base.gender,
                          'age_group', base.age_group)                                         AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['XS', 'S', 'M', 'L', 'XL', 'XXL']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                       AS adult_size,
             (ARRAY ['Slim Fit', 'Regular Fit', 'Relaxed Fit']::text[])[(((((gs.variant_index - 1) / 48) % 3) + 1))]              AS fit,
             (ARRAY ['Women']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                              AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'women_tshirt') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'adult_size', base.adult_size, 'fit', base.fit, 'gender', base.gender,
                          'age_group', base.age_group)                                         AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['XS', 'S', 'M', 'L', 'XL', 'XXL']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                       AS adult_size,
             (ARRAY ['Slim Fit', 'Regular Fit', 'Relaxed Fit']::text[])[(((((gs.variant_index - 1) / 48) % 3) + 1))]              AS fit,
             (ARRAY ['Women']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                              AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'women_hoodie') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'adult_size', base.adult_size, 'fit', base.fit, 'gender', base.gender,
                          'age_group', base.age_group)                                         AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['XS', 'S', 'M', 'L', 'XL', 'XXL']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                       AS adult_size,
             (ARRAY ['Slim Fit', 'Regular Fit', 'Relaxed Fit']::text[])[(((((gs.variant_index - 1) / 48) % 3) + 1))]              AS fit,
             (ARRAY ['Women']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                              AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'women_leggings') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'adult_size', base.adult_size, 'pack_size', base.pack_size, 'gender',
                          base.gender, 'age_group', base.age_group)                            AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['XS', 'S', 'M', 'L', 'XL', 'XXL']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                       AS adult_size,
             (ARRAY ['1-Pack', '2-Pack', '3-Pack', '6-Pack']::text[])[(((((gs.variant_index - 1) / 48) % 4) + 1))]                AS pack_size,
             (ARRAY ['Women']::text[])[(((((gs.variant_index - 1) / 192) % 1) + 1))]                                              AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 192) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'women_socks') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'shoe_size_us', base.shoe_size_us, 'width_fit', base.width_fit, 'gender',
                          base.gender, 'age_group', base.age_group)                            AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['6', '7', '8', '9', '10', '11', '12']::text[])[(((((gs.variant_index - 1) / 8) % 7) + 1))]                   AS shoe_size_us,
             (ARRAY ['Narrow', 'Regular', 'Wide']::text[])[(((((gs.variant_index - 1) / 56) % 3) + 1))]                           AS width_fit,
             (ARRAY ['Women']::text[])[(((((gs.variant_index - 1) / 168) % 1) + 1))]                                              AS gender,
             (ARRAY ['Adult']::text[])[(((((gs.variant_index - 1) / 168) % 1) + 1))]                                              AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'women_sneakers') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'kids_size', base.kids_size, 'fit', base.fit, 'gender', base.gender,
                          'age_group', base.age_group)                                         AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['2T', '3T', '4T', '5T', '6Y', '8Y']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                     AS kids_size,
             (ARRAY ['Slim Fit', 'Regular Fit', 'Relaxed Fit']::text[])[(((((gs.variant_index - 1) / 48) % 3) + 1))]              AS fit,
             (ARRAY ['Unisex']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                             AS gender,
             (ARRAY ['Kids']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                               AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'kids_tshirt') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'kids_size', base.kids_size, 'fit', base.fit, 'gender', base.gender,
                          'age_group', base.age_group)                                         AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['2T', '3T', '4T', '5T', '6Y', '8Y']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                     AS kids_size,
             (ARRAY ['Slim Fit', 'Regular Fit', 'Relaxed Fit']::text[])[(((((gs.variant_index - 1) / 48) % 3) + 1))]              AS fit,
             (ARRAY ['Unisex']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                             AS gender,
             (ARRAY ['Kids']::text[])[(((((gs.variant_index - 1) / 144) % 1) + 1))]                                               AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'kids_hoodie') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'kids_size', base.kids_size, 'pack_size', base.pack_size, 'gender',
                          base.gender, 'age_group', base.age_group)                            AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['2T', '3T', '4T', '5T', '6Y', '8Y']::text[])[(((((gs.variant_index - 1) / 8) % 6) + 1))]                     AS kids_size,
             (ARRAY ['1-Pack', '2-Pack', '3-Pack', '6-Pack']::text[])[(((((gs.variant_index - 1) / 48) % 4) + 1))]                AS pack_size,
             (ARRAY ['Unisex']::text[])[(((((gs.variant_index - 1) / 192) % 1) + 1))]                                             AS gender,
             (ARRAY ['Kids']::text[])[(((((gs.variant_index - 1) / 192) % 1) + 1))]                                               AS age_group
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'kids_socks') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                           AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric) + CASE base.capacity_ml
                                                                                               WHEN '350' THEN 0.04
                                                                                               WHEN '500' THEN 0.05
                                                                                               WHEN '750' THEN 0.06
                                                                                               WHEN '1000' THEN 0.08
                                                                                               ELSE 0.05 END)),
             2)                                                                                                    AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                     AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                           AS created_at,
       jsonb_build_object('color', base.color, 'capacity_ml', base.capacity_ml, 'finish',
                          base.finish)                                                                             AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['350', '500', '750', '1000']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))]                            AS capacity_ml,
             (ARRAY ['Matte', 'Gloss', 'Soft-Touch']::text[])[(((((gs.variant_index - 1) / 32) % 3) + 1))]                        AS finish
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'mugs') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                           AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric) + CASE base.capacity_ml
                                                                                               WHEN '350' THEN 0.04
                                                                                               WHEN '500' THEN 0.05
                                                                                               WHEN '750' THEN 0.06
                                                                                               WHEN '1000' THEN 0.08
                                                                                               ELSE 0.05 END)),
             2)                                                                                                    AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                     AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                           AS created_at,
       jsonb_build_object('color', base.color, 'capacity_ml', base.capacity_ml, 'lid_type',
                          base.lid_type)                                                                           AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['350', '500', '750', '1000']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))]                            AS capacity_ml,
             (ARRAY ['Flip Lid', 'Screw Lid', 'Straw Lid']::text[])[(((((gs.variant_index - 1) / 32) % 3) + 1))]                  AS lid_type
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'water_bottles') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                             AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))),
             2)                                                                                                      AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                       AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                             AS created_at,
       jsonb_build_object('storage_size', base.storage_size, 'pack_size', base.pack_size, 'material',
                          base.material)                                                                             AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                                                                       AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                                                                              AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                                                                         AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                                                                     AS barcode,
             (ARRAY ['Small', 'Medium', 'Large', 'Extra Large']::text[])[((gs.variant_index - 1) % 4) + 1]                                                                             AS storage_size,
             (ARRAY ['1-Pack', '2-Pack', '3-Pack', '6-Pack']::text[])[(((((gs.variant_index - 1) / 4) % 4) + 1))]                                                                      AS pack_size,
             (ARRAY ['Cotton', 'Cotton Blend', 'Polyester', 'Stainless Steel', 'BPA-Free Plastic', 'Silicone', 'Foam', 'Rubber']::text[])[(((((gs.variant_index - 1) / 16) % 8) + 1))] AS material
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'storage_containers') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                   AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))), 2)             AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                             AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                   AS created_at,
       jsonb_build_object('color', base.color, 'towel_size', base.towel_size, 'pack_size', base.pack_size) AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['Face Towel', 'Hand Towel', 'Bath Towel', 'Bath Sheet']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))] AS towel_size,
             (ARRAY ['1-Pack', '2-Pack', '3-Pack', '6-Pack']::text[])[(((((gs.variant_index - 1) / 32) % 4) + 1))]                AS pack_size
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'towels') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))),
             2)                                                                                                AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'storage_size', base.storage_size, 'pack_size', base.pack_size) AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['Small', 'Medium', 'Large', 'Extra Large']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))]              AS storage_size,
             (ARRAY ['1-Pack', '2-Pack', '3-Pack', '6-Pack']::text[])[(((((gs.variant_index - 1) / 32) % 4) + 1))]                AS pack_size
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'storage_bins') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                             AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric) + CASE base.length_m
                                                                                               WHEN '0.5' THEN 0.01
                                                                                               WHEN '1' THEN 0.02
                                                                                               WHEN '1.5' THEN 0.03
                                                                                               WHEN '2' THEN 0.04
                                                                                               ELSE 0.02 END)),
             2)                                                                                                      AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                       AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                             AS created_at,
       jsonb_build_object('color', base.color, 'mat_thickness_mm', base.mat_thickness_mm, 'length_m',
                          base.length_m)                                                                             AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['4', '6', '8', '10']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))]                                    AS mat_thickness_mm,
             (ARRAY ['0.5', '1', '1.5', '2']::text[])[(((((gs.variant_index - 1) / 32) % 4) + 1))]                                AS length_m
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'yoga_mats') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                             AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))),
             2)                                                                                                      AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                       AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                             AS created_at,
       jsonb_build_object('color', base.color, 'resistance_level', base.resistance_level, 'set_size',
                          base.set_size)                                                                             AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['Light', 'Medium', 'Heavy', 'Extra Heavy']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))]              AS resistance_level,
             (ARRAY ['2-Piece', '3-Piece', '5-Piece', '10-Piece']::text[])[(((((gs.variant_index - 1) / 32) % 4) + 1))]           AS set_size
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'resistance_bands') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                          AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.dumbbell_weight_kg::numeric)), 2) AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                    AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                          AS created_at,
       jsonb_build_object('dumbbell_weight_kg', base.dumbbell_weight_kg, 'finish', base.finish)   AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                               AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                      AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                 AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                             AS barcode,
             (ARRAY ['1', '2', '3', '5', '7.5', '10', '12.5', '15']::text[])[((gs.variant_index - 1) % 8) + 1] AS dumbbell_weight_kg,
             (ARRAY ['Matte', 'Gloss', 'Soft-Touch']::text[])[(((((gs.variant_index - 1) / 8) % 3) + 1))]      AS finish
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'dumbbells') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                           AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric) + CASE base.capacity_ml
                                                                                               WHEN '350' THEN 0.04
                                                                                               WHEN '500' THEN 0.05
                                                                                               WHEN '750' THEN 0.06
                                                                                               WHEN '1000' THEN 0.08
                                                                                               ELSE 0.05 END)),
             2)                                                                                                    AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                     AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                           AS created_at,
       jsonb_build_object('color', base.color, 'capacity_ml', base.capacity_ml, 'lid_type',
                          base.lid_type)                                                                           AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['350', '500', '750', '1000']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))]                            AS capacity_ml,
             (ARRAY ['Flip Lid', 'Screw Lid', 'Straw Lid']::text[])[(((((gs.variant_index - 1) / 32) % 3) + 1))]                  AS lid_type
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'shaker_bottles') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))),
             2)                                                                                                AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'connection_type', base.connection_type, 'finish', base.finish) AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['Wired', 'Wireless']::text[])[(((((gs.variant_index - 1) / 8) % 2) + 1))]                                    AS connection_type,
             (ARRAY ['Matte', 'Gloss', 'Soft-Touch']::text[])[(((((gs.variant_index - 1) / 16) % 3) + 1))]                        AS finish
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'headphones') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                       AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))),
             2)                                                                                                AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                 AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                       AS created_at,
       jsonb_build_object('color', base.color, 'connection_type', base.connection_type, 'finish', base.finish) AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['Wired', 'Wireless']::text[])[(((((gs.variant_index - 1) / 8) % 2) + 1))]                                    AS connection_type,
             (ARRAY ['Matte', 'Gloss', 'Soft-Touch']::text[])[(((((gs.variant_index - 1) / 16) % 3) + 1))]                        AS finish
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'earbuds') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                           AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric) + CASE base.length_m
                                                                                               WHEN '0.5' THEN 0.01
                                                                                               WHEN '1' THEN 0.02
                                                                                               WHEN '1.5' THEN 0.03
                                                                                               WHEN '2' THEN 0.04
                                                                                               ELSE 0.02 END)),
             2)                                                                                                    AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                     AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                           AS created_at,
       jsonb_build_object('color', base.color, 'length_m', base.length_m, 'connector_type',
                          base.connector_type)                                                                     AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['0.5', '1', '1.5', '2']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))]                                 AS length_m,
             (ARRAY ['USB-C', 'Lightning', 'Micro-USB']::text[])[(((((gs.variant_index - 1) / 32) % 3) + 1))]                     AS connector_type
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'cables') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                           AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric))),
             2)                                                                                                    AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                     AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                           AS created_at,
       jsonb_build_object('color', base.color, 'wattage_w', base.wattage_w, 'connector_type',
                          base.connector_type)                                                                     AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['20', '30', '45', '65']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))]                                 AS wattage_w,
             (ARRAY ['USB-C', 'Lightning', 'Micro-USB']::text[])[(((((gs.variant_index - 1) / 32) % 3) + 1))]                     AS connector_type
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'chargers') AS base
UNION ALL
SELECT base.variant_id,
       base.product_id,
       base.sku,
       base.brand_id,
       base.barcode,
       round(
               greatest(3.99::numeric, least(999.99::numeric,
                                             (base.base_price::numeric
                                                 * (1
                                                     + CASE
                                                           WHEN base.brand_name = ANY
                                                                (ARRAY ['Apple', 'Sony', 'Samsung', 'JBL', 'Nike', 'Adidas', 'The North Face', 'Columbia', 'Dyson', 'KitchenAid', 'Fellow', 'CamelBak', 'Decathlon']::text[])
                                                               THEN 0.25
                                                           ELSE 0 END
                                                     + (pseudo_rand(base.variant_id, 1) * 0.20 - 0.08)
                                                  )
                                                 )
                                                 + (base.price_spread::numeric * ((base.variant_index - 1)::numeric /
                                                                                  greatest(1, base.variant_count - 1)::numeric))
                                       )),
               2
       )                                                                                                           AS price,
       round(greatest(0.02::numeric, least(25.00::numeric, base.base_weight::numeric +
                                                           ((pseudo_rand(base.variant_id, 2) * (base.weight_spread::numeric * 2)) -
                                                            base.weight_spread::numeric) + CASE base.capacity_mah
                                                                                               WHEN '5000' THEN 0.04
                                                                                               WHEN '10000' THEN 0.08
                                                                                               WHEN '20000' THEN 0.14
                                                                                               WHEN '30000' THEN 0.20
                                                                                               ELSE 0.08 END)),
             2)                                                                                                    AS weight,
       CASE
           WHEN pseudo_rand(base.variant_id, 3) < 0.965 THEN 'active'
           WHEN pseudo_rand(base.variant_id, 3) < 0.985 THEN 'discontinued'
           ELSE 'archived'
           END                                                                                                     AS status,
       least(
               base.product_created_at + make_interval(secs => floor(pseudo_rand(base.variant_id, 4) * 10368000)::int),
               current_timestamp
       )                                                                                                           AS created_at,
       jsonb_build_object('color', base.color, 'capacity_mah', base.capacity_mah, 'finish',
                          base.finish)                                                                             AS attrs
FROM (SELECT (p.variant_start_id + gs.variant_index - 1)::bigint                                                                  AS variant_id,
             p.product_id,
             p.template_key,
             gs.variant_index,
             p.brand_id,
             p.brand_name,
             p.brand_code,
             p.base_price,
             p.price_spread,
             p.base_weight,
             p.weight_spread,
             p.variant_count,
             p.created_at                                                                                                         AS product_created_at,
             left(
                     p.brand_code || '-' || slug_code(p.template_key) || '-' ||
                     lpad(p.product_id::text, 6, '0') || '-' || lpad(gs.variant_index::text, 3, '0'),
                     63
             )                                                                                                                    AS sku,
             make_ean13(p.variant_start_id + gs.variant_index - 1)                                                                AS barcode,
             (ARRAY ['Black', 'White', 'Gray', 'Navy', 'Blue', 'Red', 'Green', 'Pink']::text[])[((gs.variant_index - 1) % 8) + 1] AS color,
             (ARRAY ['5000', '10000', '20000', '30000']::text[])[(((((gs.variant_index - 1) / 8) % 4) + 1))]                      AS capacity_mah,
             (ARRAY ['Matte', 'Gloss', 'Soft-Touch']::text[])[(((((gs.variant_index - 1) / 32) % 3) + 1))]                        AS finish
      FROM tmp_product_plan p
               JOIN generate_series(1, p.variant_count) AS gs(variant_index) ON true
      WHERE p.template_key = 'power_banks') AS base;

INSERT INTO product_variants (id, product_id, sku, brand_id, barcode, price, weight, status, created_at)
SELECT variant_id,
       product_id,
       sku,
       brand_id,
       barcode,
       price,
       weight,
       status,
       created_at
FROM tmp_variant_rows
ORDER BY variant_id;


INSERT INTO variant_attributes (product_variant_id, attribute_value_id, attribute_id)
SELECT v.variant_id AS product_variant_id,
       av.attribute_value_id,
       av.attribute_id
FROM tmp_variant_rows v
         CROSS JOIN LATERAL jsonb_each_text(v.attrs) AS j(attribute_name, attribute_value)
         JOIN tmp_attribute_values_lookup av
              ON av.attribute_name = j.attribute_name
                  AND av.value = j.attribute_value
ORDER BY v.variant_id;

INSERT INTO product_images (id, url, position, product_variants_id)
SELECT p.product_id       AS id,
       'https://cdn.example-retail.com/' || lower(tmp_brands.code) || '/' || lower(p.category_code) || '/' ||
       lower(
               tmp_brands.code || '-' || slug_code(p.template_key) || '-' ||
               lpad(p.product_id::text, 6, '0') || '-001'
       ) || '/1.jpg'      AS url,
       1                  AS position,
       p.variant_start_id AS product_variants_id
FROM tmp_product_plan p
         JOIN tmp_brands ON tmp_brands.id = p.brand_id
ORDER BY p.product_id;


SELECT setval(pg_get_serial_sequence('brands', 'id'), (SELECT max(id) FROM brands), true);
SELECT setval(pg_get_serial_sequence('categories', 'id'), (SELECT max(id) FROM categories), true);
SELECT setval(pg_get_serial_sequence('attributes', 'id'), (SELECT max(id) FROM attributes), true);
SELECT setval(pg_get_serial_sequence('attribute_values', 'id'), (SELECT max(id) FROM attribute_values), true);
SELECT setval(pg_get_serial_sequence('products', 'id'), (SELECT max(id) FROM products), true);
SELECT setval(pg_get_serial_sequence('product_variants', 'id'), (SELECT max(id) FROM product_variants), true);
SELECT setval(pg_get_serial_sequence('product_images', 'id'), (SELECT max(id) FROM product_images), true);
COMMIT;