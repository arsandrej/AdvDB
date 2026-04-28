-- VARIANT total stock per warehouse, and total stock per all warehouses

CREATE VIEW view_total_stock AS
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


