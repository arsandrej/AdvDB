INSERT INTO product_images (url, position, product_variants_id)
SELECT 'https://dummy.com/' || id || '-1.jpg',
       1,
       id
FROM product_variants;

INSERT INTO product_images (url, position, product_variants_id)
SELECT 'https://dummy.com/' || id || '-2.jpg',
       2,
       id
FROM product_variants
WHERE id % 2 = 0;

INSERT INTO product_images (url, position, product_variants_id)
SELECT 'https://dummy.com/' || id || '-3.jpg',
       3,
       id
FROM product_variants
WHERE id % 3 = 0;