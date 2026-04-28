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

SELECT product_id, product_name
FROM view_products_by_category
WHERE category_id = 14
ORDER BY product_name;