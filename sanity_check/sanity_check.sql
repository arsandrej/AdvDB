-- Sanity check script: row counts for all tables
-- PostgreSQL

SELECT 'brands' AS table_name, COUNT(*) AS row_count
FROM brands
UNION ALL
SELECT 'products', COUNT(*)
FROM products
UNION ALL
SELECT 'product_variants', COUNT(*)
FROM product_variants
UNION ALL
SELECT 'product_images', COUNT(*)
FROM product_images
UNION ALL
SELECT 'categories', COUNT(*)
FROM categories
UNION ALL
SELECT 'product_categories', COUNT(*)
FROM product_categories
UNION ALL
SELECT 'attributes', COUNT(*)
FROM attributes
UNION ALL
SELECT 'attribute_values', COUNT(*)
FROM attribute_values
UNION ALL
SELECT 'variant_attributes', COUNT(*)
FROM variant_attributes
UNION ALL
SELECT 'warehouses', COUNT(*)
FROM warehouses
UNION ALL
SELECT 'sections', COUNT(*)
FROM sections
UNION ALL
SELECT 'locations', COUNT(*)
FROM locations
UNION ALL
SELECT 'bins', COUNT(*)
FROM bins
UNION ALL
SELECT 'inventory', COUNT(*)
FROM inventory
UNION ALL
SELECT 'employees', COUNT(*)
FROM employees
UNION ALL
SELECT 'employee_warehouse_assignments', COUNT(*)
FROM employee_warehouse_assignments
UNION ALL
SELECT 'transaction_types', COUNT(*)
FROM transaction_types
UNION ALL
SELECT 'inventory_transactions', COUNT(*)
FROM inventory_transactions
UNION ALL
SELECT 'inventory_movements', COUNT(*)
FROM inventory_movements
UNION ALL
SELECT 'delivery_transactions', COUNT(*)
FROM delivery_transactions
UNION ALL
SELECT 'shipment_transactions', COUNT(*)
FROM shipment_transactions
UNION ALL
SELECT 'roles', COUNT(*)
FROM roles
UNION ALL
SELECT 'permissions', COUNT(*)
FROM permissions
UNION ALL
SELECT 'roles_employees', COUNT(*)
FROM roles_employees
UNION ALL
SELECT 'permissions_roles', COUNT(*)
FROM permissions_roles
ORDER BY row_count DESC;