--1
CREATE OR REPLACE VIEW view_current_warehouse_stock AS
SELECT w.id                                  AS warehouse_id,
       w.name                                AS warehouse_name,
       p.id                                  AS product_id,
       p.name                                AS product_name,
       pv.id                                 AS variant_id,
       pv.sku,
       SUM(i.quantity)                       AS total_quantity,
       SUM(i.reserved_quantity)              AS reserved_quantity,
       SUM(i.quantity - i.reserved_quantity) AS available_quantity
FROM inventory i
         JOIN product_variants pv ON pv.id = i.product_variant_id
         JOIN products p ON p.id = pv.product_id
         JOIN bins b ON b.id = i.bin_id
         JOIN locations l ON l.id = b.location_id
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
GROUP BY w.id, w.name, p.id, p.name, pv.id, pv.sku;

SELECT *
FROM view_current_warehouse_stock
WHERE warehouse_id = 14;

--2
CREATE OR REPLACE VIEW view_products_by_category AS
SELECT c.id   AS category_id,
       c.name AS category_name,
       p.id   AS product_id,
       p.name AS product_name,
       p.description
FROM product_categories pc
         JOIN products p ON p.id = pc.product_id
         JOIN categories c ON c.id = pc.category_id;

--view all products in a category
SELECT vp.product_id, product_name, category_name, pv.sku
FROM view_products_by_category vp JOIN product_variants pv on pv.product_id=vp.product_id
WHERE category_id = 10
ORDER BY product_name;



--3
CREATE OR REPLACE VIEW view_variants_per_product AS
SELECT p.id   AS product_id,
       p.name AS product_name,
       pv.id  AS variant_id,
       pv.sku,
       pv.brand_id,
       pv.barcode,
       pv.price,
       pv.status,
       pv.weight,
       pv.created_at
FROM product_variants pv
         JOIN products p ON p.id = pv.product_id;

--list all variants for a product
SELECT product_name,
       variant_id,
       sku,
       brand_id,
       barcode,
       price,
       status,
       weight,
       created_at
FROM view_variants_per_product
WHERE product_id = 2348
ORDER BY product_name;


--4
CREATE OR REPLACE VIEW view_inventory_summary AS
SELECT product_variant_id,
       SUM(quantity)                     AS total_quantity,
       SUM(reserved_quantity)            AS reserved_quantity,
       SUM(quantity - reserved_quantity) AS available_quantity
FROM INVENTORY
GROUP BY product_variant_id;

SELECT *
FROM view_inventory_summary;


--5
CREATE OR REPLACE VIEW view_low_stock AS
SELECT pv.sku, vis.*
FROM view_inventory_summary vis
         JOIN product_variants pv on vis.product_variant_id = pv.id
WHERE available_quantity < 10; -- change if needed

SELECT *
FROM view_low_stock;

--6
CREATE OR REPLACE VIEW view_employee_current_warehouse AS
SELECT e.id   AS employee_id,
       w.name AS warehouse_name,
       ewa.is_primary
FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS ewa
         JOIN EMPLOYEES e ON e.id = ewa.employee_id
         JOIN WAREHOUSES w ON w.id = ewa.warehouse_id
WHERE ewa.end_date IS NULL;

SELECT *
FROM view_employee_current_warehouse;

--7
drop view view_employee_permissions;
CREATE OR REPLACE VIEW view_employee_permissions AS
SELECT e.first_name || ' ' || e.last_name AS employee_full_name,
       e.id                               AS employee_id,
       r.name                             AS role,
       p.name                             AS permission
FROM EMPLOYEES e
         JOIN ROLES_EMPLOYEES re ON re.employees_id = e.id
         JOIN ROLES r ON r.id = re.roles_id
         JOIN PERMISSIONS_ROLES pr ON pr.roles_id = r.id
         JOIN PERMISSIONS p ON p.id = pr.permissions_id;

SELECT *
FROM view_employee_permissions
WHERE employee_id = 22;

--8
-- drop view view_employees_with_manager;
CREATE OR REPLACE VIEW view_employees_with_manager AS
SELECT e.id,
       e.first_name,
       e.last_name,
       e.job_title,
       e.employment_status,
       m.first_name || ' ' || m.last_name AS manager_name,
       e.manager_id                       as manager
FROM EMPLOYEES e
         LEFT JOIN EMPLOYEES m ON m.id = e.manager_id;

SELECT *
FROM view_employees_with_manager
where manager = 4;


--9
CREATE OR REPLACE VIEW view_inventory_movements_detailed AS
SELECT im.id,
       im.product_variant_id,
       im.quantity,
       im.created_at,
       from_bin.bin_code                  AS from_bin,
       to_bin.bin_code                    AS to_bin,
       it.transaction_type,
       e.first_name || ' ' || e.last_name AS created_by
FROM INVENTORY_MOVEMENTS im
         JOIN INVENTORY_TRANSACTIONS it ON it.id = im.inventory_transactions_id
         JOIN EMPLOYEES e ON e.id = it.created_by_employee
         LEFT JOIN BINS from_bin ON from_bin.id = im.from_bin_id
         LEFT JOIN BINS to_bin ON to_bin.id = im.to_bin_id;

SELECT *
FROM view_inventory_movements_detailed;

--10
CREATE OR REPLACE VIEW view_transactions_full AS
SELECT it.id,
       it.transaction_type,
       it.created_at,
       e.first_name || ' ' || e.last_name AS created_by,
       dt.supplier_company,
       st.shipment_number,
       st.destination_adress
FROM INVENTORY_TRANSACTIONS it
         JOIN EMPLOYEES e ON e.id = it.created_by_employee
         LEFT JOIN DELIVERY_TRANSACTIONS dt
                   ON dt.inventory_transactions_id = it.id
         LEFT JOIN SHIPMENT_TRANSACTIONS st
                   ON st.inventory_transactions_id = it.id;

SELECT *
FROM view_transactions_full;

--11
--drop view view_variant_attributes;
CREATE OR REPLACE VIEW view_variant_attributes AS
SELECT pv.id    AS variant_id,
       pv.brand_id,
       p.name,
       pv.sku,
       pv.product_id,
       a.name   AS attribute_name,
       av.value AS attribute_value,
       a.data_type,
       a.unit
FROM PRODUCT_VARIANTS pv
         JOIN VARIANT_ATTRIBUTES va ON va.product_variant_id = pv.id
         JOIN ATTRIBUTE_VALUES av ON av.id = va.attribute_value_id
    AND av.attribute_id = va.attribute_id
         JOIN ATTRIBUTES a ON a.id = va.attribute_id
            JOIN products p on pv.product_id = p.id;

SELECT *
FROM view_variant_attributes vva join brands b on vva.brand_id=b.id
-- ORDER BY variant_id;
WHERE variant_id = 1 OR variant_id = 2;

SELECT *
FROM view_variant_attributes
WHERE variant_id = 6;

--12
CREATE OR REPLACE VIEW view_inventory_value AS
SELECT pv.id                                            AS variant_id,
       pv.sku,
       pv.price,
       SUM(i.quantity - i.reserved_quantity)            AS available_qty,
       SUM(i.quantity - i.reserved_quantity) * pv.price AS available_value
FROM PRODUCT_VARIANTS pv
         JOIN INVENTORY i ON i.product_variant_id = pv.id
GROUP BY pv.id, pv.sku, pv.price;

SELECT *
FROM view_inventory_value;

CREATE OR REPLACE VIEW view_category_tree AS
WITH RECURSIVE tree AS (SELECT c.id,
                               c.parent_id,
                               c.name,
                               0            AS depth,
                               c.name::text AS path
                        FROM categories c
                        WHERE c.parent_id IS NULL

                        UNION ALL

                        SELECT c.id,
                               c.parent_id,
                               c.name,
                               t.depth + 1               AS depth,
                               t.path || ' > ' || c.name AS path
                        FROM categories c
                                 JOIN tree t ON t.id = c.parent_id)
SELECT id   AS category_id,
       parent_id,
       name AS category_name,
       depth,
       path
FROM tree;
COMMENT
    ON VIEW view_category_tree IS 'Recursive category tree with depth and breadcrumb path for navigation, menus, and reporting.';

SELECT *
FROM view_category_tree;

--drop view view_active_employees;
CREATE OR REPLACE VIEW view_active_employees AS
SELECT e.id                             AS employee_id,
       w.name                           as warehouse_name,
       e.employee_number,
       e.first_name,
       e.last_name,
       e.email,
       e.phone,
       e.job_title,
       e.employment_status,
       e.hired_at,
       COUNT(DISTINCT ewa.warehouse_id) AS current_warehouse_count,
       COUNT(DISTINCT re.roles_id)      AS role_count
FROM employees e
         LEFT JOIN employee_warehouse_assignments ewa
                   ON ewa.employee_id = e.id
                       AND ewa.end_date IS NULL
         LEFT JOIN roles_employees re ON re.employees_id = e.id
         JOIN warehouses w ON ewa.warehouse_id = w.id
WHERE e.terminated_at IS NULL
GROUP BY e.id, e.employee_number, e.first_name, e.last_name, e.email, e.phone,
         e.job_title, e.employment_status, e.hired_at, w.name;
COMMENT
    ON VIEW view_active_employees IS 'Currently active employees with warehouse and role coverage counts.';

SELECT *
FROM view_active_employees
where warehouse_name = 'Axis Storage Facility';