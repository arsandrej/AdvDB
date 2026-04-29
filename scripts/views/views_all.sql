--1
CREATE VIEW view_current_warehouse_stock AS
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


--2
CREATE VIEW view_products_by_category AS
SELECT c.id   AS category_id,
       c.name AS category_name,
       p.id   AS product_id,
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



--3
CREATE VIEW view_variants_per_product AS
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
CREATE VIEW view_inventory_summary AS
SELECT
    product_variant_id,
    SUM(quantity) AS total_quantity,
    SUM(reserved_quantity) AS reserved_quantity,
    SUM(quantity - reserved_quantity) AS available_quantity
FROM INVENTORY
GROUP BY product_variant_id;


--5
CREATE VIEW view_low_stock AS
SELECT *
FROM view_inventory_summary
WHERE (total_quantity - reserved_quantity) < 10; -- change if needed


--6
CREATE VIEW view_employee_current_warehouse AS
SELECT
    e.id AS employee_id,
    w.name AS warehouse_name,
    ewa.is_primary
FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS ewa
         JOIN EMPLOYEES e ON e.id = ewa.employee_id
         JOIN WAREHOUSES w ON w.id = ewa.warehouse_id
WHERE ewa.end_date IS NULL;

--7
CREATE VIEW view_employee_permissions AS
SELECT
    e.id AS employee_id,
    r.name AS role,
    p.name AS permission
FROM EMPLOYEES e
         JOIN ROLES_EMPLOYEES re ON re.employees_id = e.id
         JOIN ROLES r ON r.id = re.roles_id
         JOIN PERMISSIONS_ROLES pr ON pr.roles_id = r.id
         JOIN PERMISSIONS p ON p.id = pr.permissions_id;

--8
CREATE VIEW view_employees_with_manager AS
SELECT
    e.id,
    e.first_name,
    e.last_name,
    e.job_title,
    e.employment_status,
    m.first_name || ' ' || m.last_name AS manager_name
FROM EMPLOYEES e
         LEFT JOIN EMPLOYEES m ON m.id = e.manager_id;


--9
CREATE VIEW view_inventory_movements_detailed AS
SELECT
    im.id,
    im.product_variant_id,
    im.quantity,
    im.created_at,
    from_bin.bin_code AS from_bin,
    to_bin.bin_code AS to_bin,
    it.transaction_type,
    e.first_name || ' ' || e.last_name AS created_by
FROM INVENTORY_MOVEMENTS im
         JOIN INVENTORY_TRANSACTIONS it ON it.id = im.inventory_transactions_id
         JOIN EMPLOYEES e ON e.id = it.created_by_employee
         LEFT JOIN BINS from_bin ON from_bin.id = im.from_bin_id
         LEFT JOIN BINS to_bin ON to_bin.id = im.to_bin_id;

--10
CREATE VIEW view_transactions_full AS
SELECT
    it.id,
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


--11
CREATE VIEW view_variant_attributes AS
SELECT pv.id         AS variant_id,
       pv.product_id,
       a.name        AS attribute_name,
       av.value      AS attribute_value,
       a.data_type,
       a.unit
FROM PRODUCT_VARIANTS pv
         JOIN VARIANT_ATTRIBUTES va ON va.product_variant_id = pv.id
         JOIN ATTRIBUTE_VALUES av ON av.id = va.attribute_value_id
    AND av.attribute_id = va.attribute_id
         JOIN ATTRIBUTES a ON a.id = va.attribute_id;


--12
CREATE VIEW view_inventory_value AS
SELECT pv.id          AS variant_id,
       pv.sku,
       pv.price,
       SUM(i.quantity - i.reserved_quantity) AS available_qty,
       SUM(i.quantity - i.reserved_quantity) * pv.price AS available_value
FROM PRODUCT_VARIANTS pv
         JOIN INVENTORY i ON i.product_variant_id = pv.id
GROUP BY pv.id, pv.sku, pv.price;
