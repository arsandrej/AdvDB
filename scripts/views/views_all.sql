--1
-- View: Shows current stock per warehouse, product, and variant (total, reserved, available)
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
         JOIN bins b ON b.id = i.bin_id
         JOIN product_variants pv ON pv.id = i.product_variant_id
         JOIN products p ON p.id = pv.product_id
         JOIN locations l ON l.id = b.location_id
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
GROUP BY w.id, w.name, p.id, p.name, pv.id, pv.sku;
drop view view_current_warehouse_stock;

CREATE OR REPLACE VIEW view_current_warehouse_stock AS
SELECT agg.warehouse_id,
       w.name AS warehouse_name,

       agg.product_id,
       p.name AS product_name,

       agg.variant_id,
       pv.sku,

       agg.total_quantity,
       agg.reserved_quantity,
       agg.available_quantity

FROM (SELECT s.warehouse_id,
             pv.product_id,
             pv.id                                 AS variant_id,

             SUM(i.quantity)                       AS total_quantity,
             SUM(i.reserved_quantity)              AS reserved_quantity,
             SUM(i.quantity - i.reserved_quantity) AS available_quantity

      FROM inventory i

               JOIN bins b
                    ON b.id = i.bin_id

               JOIN locations l
                    ON l.id = b.location_id

               JOIN sections s
                    ON s.id = l.section_id

               JOIN product_variants pv
                    ON pv.id = i.product_variant_id

      GROUP BY s.warehouse_id,
               pv.product_id,
               pv.id) agg

         JOIN warehouses w
              ON w.id = agg.warehouse_id

         JOIN product_variants pv
              ON pv.id = agg.variant_id

         JOIN products p
              ON p.id = agg.product_id;

SELECT *
FROM view_current_warehouse_stock;

SELECT *
FROM view_current_warehouse_stock
WHERE warehouse_id = 2;

SELECT *
FROM view_current_warehouse_stock
WHERE product_id = 2;

SELECT *
FROM view_current_warehouse_stock
WHERE variant_id = 10000;



--2
CREATE OR REPLACE VIEW view_category_descendants AS
WITH RECURSIVE descendants AS (SELECT c.id AS root_id, c.id AS category_id
                               FROM categories c

                               UNION ALL

                               SELECT d.root_id, c.id
                               FROM categories c
                                        JOIN descendants d ON c.parent_id = d.category_id)
SELECT root_id, category_id
FROM descendants;

SELECT *
FROM view_category_descendants;

CREATE OR REPLACE VIEW view_product_category_flat AS
SELECT c.id   AS category_id,
       c.name AS category_name,
       p.id   AS product_id,
       p.name AS product_name,
       p.description
FROM product_categories pc
         JOIN categories c ON c.id = pc.category_id
         JOIN products p ON p.id = pc.product_id;

-- View: Lists all products grouped by their categories
-- drop view view_products_by_category;
CREATE OR REPLACE VIEW view_products_by_category AS
SELECT d.root_id        AS main_category_id,
       main_c.name      AS main_category_name,

       pc.category_id   AS subcategory_id,
       pc.category_name AS subcategory_name,

       pc.product_id,
       pc.product_name,
       pc.description
FROM view_category_descendants d
         JOIN view_product_category_flat pc
              ON pc.category_id = d.category_id
         JOIN categories main_c
              ON main_c.id = d.root_id;

SELECT *
FROM view_products_by_category
WHERE main_category_id = 8;

SELECT *
FROM view_products_by_category
WHERE main_category_name = 'pants';

SELECT *
FROM view_products_by_category
WHERE product_id = 5;

SELECT *
FROM view_products_by_category;

--3
-- View: Shows all variants for each product with detailed variant information
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
         JOIN products p ON p.id = pv.product_id
ORDER BY product_name;

SELECT *
FROM view_variants_per_product
WHERE product_id = 13;

SELECT *
FROM view_variants_per_product;

--4
-- View: Aggregates inventory quantities per product variant
CREATE OR REPLACE VIEW view_inventory_summary AS
SELECT product_variant_id,
       SUM(quantity)                     AS total_quantity,
       SUM(reserved_quantity)            AS reserved_quantity,
       SUM(quantity - reserved_quantity) AS available_quantity
FROM INVENTORY
GROUP BY product_variant_id;

SELECT *
FROM view_inventory_summary;

SELECT *
FROM view_inventory_summary
where product_variant_id = 312312;

SELECT *
FROM view_inventory_summary
WHERE available_quantity < 10;

--5
-- View: Shows employees with their currently assigned warehouse and their manager
CREATE OR REPLACE VIEW view_employee_current_warehouse AS
SELECT e.id                               AS employee_id,
       e.employee_number,
       e.first_name,
       e.last_name,
       e.job_title,
       e.employment_status,
       m.id                               AS manager_id,
       m.first_name || ' ' || m.last_name AS manager_name,
       w.id                               AS warehouse_id,
       w.name                             AS warehouse_name,
       ewa.is_primary,
       ewa.start_date
FROM employees e
         LEFT JOIN employee_warehouse_assignments ewa
                   ON ewa.employee_id = e.id
                       AND ewa.end_date IS NULL
                       AND ewa.is_primary = TRUE

         LEFT JOIN warehouses w
                   ON w.id = ewa.warehouse_id

         LEFT JOIN employees m
                   ON m.id = e.manager_id

WHERE e.terminated_at IS NULL;

SELECT *
FROM view_employee_current_warehouse;

SELECT *
FROM view_employee_current_warehouse
where employee_id = 685;

SELECT *
FROM view_employee_current_warehouse
where warehouse_id = 12;

--6
-- View: Lists employee roles and their associated permissions
--drop view view_employee_permissions;
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

SELECT *
FROM view_employee_permissions;


--7
-- View: Detailed inventory movement records including bins and responsible employee
-- drop view view_inventory_movements_detailed;
CREATE OR REPLACE VIEW view_inventory_movements_detailed AS
SELECT im.id,
       im.product_variant_id,
       im.quantity,
       im.created_at,
       from_bin.bin_code                  AS from_bin,
       to_bin.bin_code                    AS to_bin,
       it.id                              as inventory_transaction_id,
       it.transaction_type,
       e.first_name || ' ' || e.last_name AS created_by,
       e.id                               as employee_id
FROM INVENTORY_MOVEMENTS im
         LEFT JOIN BINS from_bin ON from_bin.id = im.from_bin_id
         LEFT JOIN BINS to_bin ON to_bin.id = im.to_bin_id
         JOIN INVENTORY_TRANSACTIONS it ON it.id = im.inventory_transactions_id
         JOIN EMPLOYEES e ON e.id = it.created_by_employee;


SELECT *
FROM view_inventory_movements_detailed
WHERE inventory_transaction_id = 3200376;

SELECT *
FROM view_inventory_movements_detailed
WHERE created_at >= '2025-01-01 00:00:00.000000';

SELECT *
FROM view_inventory_movements_detailed
WHERE employee_id = 1674;

SELECT *
FROM view_inventory_movements_detailed
WHERE transaction_type = 'TRANSFER';


ANALYZE inventory_transactions;
ANALYZE inventory_movements;
--9
-- View: Combines all transaction types with related delivery and shipment details
CREATE OR REPLACE VIEW view_transactions_full AS
SELECT it.id,
       it.transaction_type,
       it.created_at,
       e.first_name || ' ' || e.last_name AS created_by,
       dt.supplier_company,
       NULL::bigint                       AS shipment_number,
       NULL::text                         AS destination_address
FROM inventory_transactions it
         JOIN employees e ON e.id = it.created_by_employee
         LEFT JOIN delivery_transactions dt ON dt.inventory_transactions_id = it.id
WHERE it.transaction_type IN ('TRANSFER', 'RECEIPT')

UNION ALL

SELECT it.id,
       it.transaction_type,
       it.created_at,
       e.first_name || ' ' || e.last_name AS created_by,
       NULL::text                         AS supplier_company,
       st.shipment_number,
       st.destination_adress
FROM inventory_transactions it
         JOIN employees e ON e.id = it.created_by_employee
         LEFT JOIN shipment_transactions st ON st.inventory_transactions_id = it.id
WHERE it.transaction_type = 'SHIPMENT';

-- drop view view_transactions_full;

SELECT *
FROM view_transactions_full
WHERE transaction_type = 'SHIPMENT';

--10
-- View: Lists all attributes and values assigned to each product variant
drop view view_variant_details;

CREATE OR REPLACE VIEW view_variant_details AS
SELECT pv.id    AS variant_id,
       b.name      brand_name,
       p.name   AS product_name,
       c.name   as category_name,
       pv.price,
       pv.status,
       pv.sku,
       pv.product_id,
       a.name   AS attribute_name,
       av.value AS attribute_value,
       a.data_type,
       a.unit,
       pim.url
FROM PRODUCT_VARIANTS pv
         JOIN VARIANT_ATTRIBUTES va ON va.product_variant_id = pv.id
         JOIN ATTRIBUTE_VALUES av ON av.id = va.attribute_value_id
    AND av.attribute_id = va.attribute_id
         JOIN ATTRIBUTES a ON a.id = va.attribute_id
         JOIN products p on pv.product_id = p.id
         JOIN brands as b on pv.brand_id = b.id
         LEFT JOIN product_images as pim on pv.id = pim.product_variants_id
         JOIN product_categories pc on p.id = pc.product_id
         JOIN categories c on pc.category_id = c.id;

SELECT *
FROM view_variant_details;

SELECT *
FROM view_variant_details
where variant_id = 291589;
-- ORDER BY variant_id;
-- WHERE variant_id = 1 OR variant_id = 2;

SELECT *
FROM view_variant_details
WHERE variant_id = 6;

--11
-- View: Calculates available inventory value per product variant
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
FROM view_inventory_value
WHERE available_qty <10;

SELECT *
FROM view_inventory_value
WHERE variant_id = 10000;


--12
--View: Builds a hierarchical category tree with depth and full path (breadcrumb)
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

SELECT *
FROM view_category_tree;

