CREATE VIEW view_products_by_category AS
SELECT
    c.id AS category_id,
    c.name AS category_name,
    p.id AS product_id,
    p.name AS product_name,
    p.description
FROM product_categories pc
JOIN products p ON p.id = pc.product_id
JOIN categories c ON c.id = pc.category_id;

--view all products in a category
SELECT product_id, product_name
FROM view_products_by_category
WHERE category_id = 14
ORDER BY product_name;

CREATE VIEW view_variants_per_product AS
SELECT
    p.id AS product_id,
    p.name AS product_name,
    pv.id AS variant_id,
    pv.sku,
    pv.brand_id,
    pv.barcode,
    pv.price,
    pv.status,
    pv.weight,
    pv.created_at
FROM product_variants pv
JOIN products p ON p.id = pv.product_id;

--list all variants (and their attributes?) for a product
SELECT product_name, variant_id, sku, brand_id, barcode, price, status, weight, created_at
FROM view_variants_per_product
WHERE product_id = 2348
ORDER BY product_name;