BEGIN;

-- =========================================================
-- 1. CATEGORY TREE (Navigation / UI)
-- =========================================================
CREATE OR REPLACE VIEW view_category_tree AS
WITH RECURSIVE tree AS (
    SELECT id, parent_id, name, 0 AS depth, name::text AS path
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT c.id, c.parent_id, c.name,
           t.depth + 1,
           t.path || ' > ' || c.name
    FROM categories c
    JOIN tree t ON t.id = c.parent_id
)
SELECT id AS category_id, parent_id, name AS category_name, depth, path
FROM tree;


-- =========================================================
-- 2. PRODUCTS BY CATEGORY
-- =========================================================
CREATE OR REPLACE VIEW view_products_by_category AS
SELECT c.id AS category_id,
       c.name AS category_name,
       p.id AS product_id,
       p.name AS product_name,
       p.description
FROM product_categories pc
         JOIN products p ON p.id = pc.product_id
         JOIN categories c ON c.id = pc.category_id;


-- =========================================================
-- 3. VARIANTS PER PRODUCT
-- =========================================================
CREATE OR REPLACE VIEW view_variants_per_product AS
SELECT p.id AS product_id,
       p.name AS product_name,
       pv.id AS variant_id,
       pv.sku,
       b.name AS brand_name,
       pv.barcode,
       pv.price,
       pv.status,
       pv.weight,
       pv.created_at
FROM product_variants pv
         JOIN products p ON p.id = pv.product_id
         JOIN brands b ON b.id = pv.brand_id;


-- =========================================================
-- 4. VARIANT ATTRIBUTES (RAW)
-- =========================================================
CREATE OR REPLACE VIEW view_variant_attributes AS
SELECT pv.id AS variant_id,
       pv.product_id,
       pv.sku,
       a.name AS attribute_name,
       av.value AS attribute_value,
       a.data_type,
       a.unit
FROM product_variants pv
         JOIN variant_attributes va ON va.product_variant_id = pv.id
         JOIN attribute_values av
              ON av.id = va.attribute_value_id AND av.attribute_id = va.attribute_id
         JOIN attributes a ON a.id = va.attribute_id;


-- =========================================================
-- 5. INVENTORY SUMMARY (BASE)
-- =========================================================
CREATE OR REPLACE VIEW view_inventory_summary AS
SELECT product_variant_id,
       COALESCE(SUM(quantity), 0) AS total_quantity,
       COALESCE(SUM(reserved_quantity), 0) AS reserved_quantity,
       COALESCE(SUM(quantity - reserved_quantity), 0) AS available_quantity
FROM inventory
GROUP BY product_variant_id;


-- =========================================================
-- 6. VARIANT STOCK STATUS (CORE LOGIC)
-- =========================================================
CREATE OR REPLACE VIEW view_variant_stock_status AS
SELECT pv.id AS variant_id,
       pv.product_id,
       pv.sku,
       pv.status AS variant_status,
       COALESCE(inv.total_quantity, 0) AS total_quantity,
       COALESCE(inv.reserved_quantity, 0) AS reserved_quantity,
       COALESCE(inv.available_quantity, 0) AS available_quantity,
       CASE
           WHEN inv.product_variant_id IS NULL THEN 'NO_INVENTORY'
           WHEN inv.total_quantity = 0 THEN 'OUT_OF_STOCK'
           WHEN inv.available_quantity = 0 THEN 'FULLY_RESERVED'
           WHEN inv.available_quantity < 10 THEN 'LOW_STOCK'
           ELSE 'IN_STOCK'
           END AS stock_state
FROM product_variants pv
         LEFT JOIN view_inventory_summary inv
                   ON inv.product_variant_id = pv.id;


-- =========================================================
-- 7. WAREHOUSE STOCK
-- =========================================================
CREATE OR REPLACE VIEW view_current_warehouse_stock AS
SELECT w.id AS warehouse_id,
       w.name AS warehouse_name,
       p.id AS product_id,
       p.name AS product_name,
       pv.id AS variant_id,
       pv.sku,
       b.name AS brand_name,
       COALESCE(SUM(i.quantity), 0) AS total_quantity,
       COALESCE(SUM(i.reserved_quantity), 0) AS reserved_quantity,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0) AS available_quantity
FROM inventory i
         JOIN product_variants pv ON pv.id = i.product_variant_id
         JOIN products p ON p.id = pv.product_id
         JOIN brands b ON b.id = pv.brand_id
         JOIN bins b2 ON b2.id = i.bin_id
         JOIN locations l ON l.id = b2.location_id
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
GROUP BY w.id, w.name, p.id, p.name, pv.id, pv.sku, b.name;


-- =========================================================
-- 8. INVENTORY VALUE
-- =========================================================
CREATE OR REPLACE VIEW view_inventory_value AS
SELECT pv.id AS variant_id,
       pv.sku,
       pv.price,
       COALESCE(SUM(i.quantity), 0) AS total_qty,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0) AS available_qty,
       COALESCE(SUM(i.quantity) * pv.price, 0) AS gross_value,
       COALESCE(SUM(i.quantity - i.reserved_quantity) * pv.price, 0) AS available_value
FROM product_variants pv
         LEFT JOIN inventory i ON i.product_variant_id = pv.id
GROUP BY pv.id, pv.sku, pv.price;


-- =========================================================
-- 9. PRODUCT OPERATIONAL DASHBOARD
-- =========================================================
CREATE OR REPLACE VIEW view_product_operational_dashboard AS
SELECT p.id AS product_id,
       p.name AS product_name,
       COUNT(pv.id) AS variant_count,
       COUNT(*) FILTER (WHERE s.stock_state = 'IN_STOCK') AS stocked_variants,
    COUNT(*) FILTER (WHERE s.stock_state IN ('OUT_OF_STOCK','NO_INVENTORY')) AS out_of_stock_variants,
    COUNT(*) FILTER (WHERE s.stock_state = 'LOW_STOCK') AS low_stock_variants,
    COALESCE(SUM(s.available_quantity), 0) AS total_available_qty,
       COALESCE(SUM(s.available_quantity * pv.price), 0) AS total_available_value
FROM products p
         LEFT JOIN product_variants pv ON pv.product_id = p.id
         LEFT JOIN view_variant_stock_status s ON s.variant_id = pv.id
GROUP BY p.id, p.name;


-- =========================================================
-- 10. INVENTORY MOVEMENTS
-- =========================================================
CREATE OR REPLACE VIEW view_inventory_movements_detailed AS
SELECT im.id AS movement_id,
       im.created_at,
       im.product_variant_id,
       pv.sku,
       p.name AS product_name,
       im.quantity,
       fb.bin_code AS from_bin,
       tb.bin_code AS to_bin,
       it.transaction_type,
       e.first_name || ' ' || e.last_name AS created_by
FROM inventory_movements im
         JOIN product_variants pv ON pv.id = im.product_variant_id
         JOIN products p ON p.id = pv.product_id
         JOIN inventory_transactions it ON it.id = im.inventory_transactions_id
         JOIN employees e ON e.id = it.created_by_employee
         LEFT JOIN bins fb ON fb.id = im.from_bin_id
         LEFT JOIN bins tb ON tb.id = im.to_bin_id;


-- =========================================================
-- 11. EMPLOYEE CURRENT WAREHOUSE MANS=AGER AND CURRENT PRIMARY WAREHOUSE ASSIGNMENT
-- =========================================================
CREATE OR REPLACE VIEW view_employee_current_warehouse AS
SELECT
    e.id AS employee_id,
    e.employee_number,
    e.first_name,
    e.last_name,
    e.job_title,
    e.employment_status,


    m.id AS manager_id,
    m.first_name || ' ' || m.last_name AS manager_name,


    w.id AS warehouse_id,
    w.name AS warehouse_name,
    ewa.is_primary,

    ewa.start_date

FROM employees e


         LEFT JOIN employee_warehouse_assignments ewa
                   ON ewa.employee_id = e.id
                       AND ewa.end_date IS NULL
                       AND ewa.is_primary = TRUE

         LEFT JOIN warehouses w
                   ON w.id = ewa.warehouse_id

-- manager join
         LEFT JOIN employees m
                   ON m.id = e.manager_id

WHERE e.terminated_at IS NULL;


-- =========================================================
-- 12. EMPLOYEE PERMISSIONS
-- =========================================================
CREATE OR REPLACE VIEW view_employee_permissions AS
SELECT e.id AS employee_id,
       e.first_name || ' ' || e.last_name AS employee_name,
       r.name AS role,
       p.name AS permission
FROM employees e
         JOIN roles_employees re ON re.employees_id = e.id
         JOIN roles r ON r.id = re.roles_id
         JOIN permissions_roles pr ON pr.roles_id = r.id
         JOIN permissions p ON p.id = pr.permissions_id;

COMMIT;