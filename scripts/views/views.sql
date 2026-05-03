BEGIN;

-- ---------------------------------------------------------------------------
-- 1) CATEGORY / CATALOG VIEWS
-- ---------------------------------------------------------------------------

CREATE
OR REPLACE VIEW view_category_tree AS
WITH RECURSIVE tree AS (
    SELECT
        c.id,
        c.parent_id,
        c.name,
        0 AS depth,
        c.name::text AS path
    FROM categories c
    WHERE c.parent_id IS NULL

    UNION ALL

    SELECT
        c.id,
        c.parent_id,
        c.name,
        t.depth + 1 AS depth,
        t.path || ' > ' || c.name AS path
    FROM categories c
    JOIN tree t ON t.id = c.parent_id
)
SELECT id   AS category_id,
       parent_id,
       name AS category_name,
       depth,
       path
FROM tree;
COMMENT
ON VIEW view_category_tree IS 'Recursive category tree with depth and breadcrumb path for navigation, menus, and reporting.';

CREATE
OR REPLACE VIEW view_category_hierarchy_stats AS
WITH RECURSIVE tree AS (
    SELECT
        c.id,
        c.parent_id,
        c.name,
        0 AS depth
    FROM categories c
    WHERE c.parent_id IS NULL

    UNION ALL

    SELECT
        c.id,
        c.parent_id,
        c.name,
        t.depth + 1 AS depth
    FROM categories c
    JOIN tree t ON t.id = c.parent_id
),
child_counts AS (
    SELECT parent_id AS category_id, COUNT(*) AS child_category_count
    FROM categories
    GROUP BY parent_id
),
product_counts AS (
    SELECT category_id, COUNT(*) AS direct_product_count
    FROM product_categories
    GROUP BY category_id
)
SELECT t.id                                 AS category_id,
       t.parent_id,
       t.name                               AS category_name,
       t.depth,
       COALESCE(cc.child_category_count, 0) AS child_category_count,
       COALESCE(pc.direct_product_count, 0) AS direct_product_count
FROM tree t
         LEFT JOIN child_counts cc ON cc.category_id = t.id
         LEFT JOIN product_counts pc ON pc.category_id = t.id;
COMMENT
ON VIEW view_category_hierarchy_stats IS 'Category hierarchy with direct child counts and direct product counts for catalog governance.';

CREATE
OR REPLACE VIEW view_products_by_category AS
SELECT c.id   AS category_id,
       c.name AS category_name,
       p.id   AS product_id,
       p.name AS product_name,
       p.description
FROM product_categories pc
         JOIN products p ON p.id = pc.product_id
         JOIN categories c ON c.id = pc.category_id;
COMMENT
ON VIEW view_products_by_category IS 'Product-to-category listing for category pages, filters, and merchandising reports.';

CREATE
OR REPLACE VIEW view_product_catalog_full AS
SELECT p.id                          AS product_id,
       p.name                        AS product_name,
       p.description,
       COALESCE(v.variant_count, 0)  AS variant_count,
       COALESCE(v.min_price, 0)      AS min_price,
       COALESCE(v.max_price, 0)      AS max_price,
       COALESCE(c.category_count, 0) AS category_count,
       COALESCE(img.total_images, 0) AS image_count,
       img.primary_image_url,
       p.created_at,
       p.updated_at
FROM products p
         LEFT JOIN (SELECT product_id,
                           COUNT(*)   AS variant_count,
                           MIN(price) AS min_price,
                           MAX(price) AS max_price
                    FROM product_variants
                    GROUP BY product_id) v ON v.product_id = p.id
         LEFT JOIN (SELECT pc.product_id,
                           COUNT(*) AS category_count
                    FROM product_categories pc
                    GROUP BY pc.product_id) c ON c.product_id = p.id
         LEFT JOIN (SELECT pv.product_id,
                           COUNT(pi.id) AS total_images,
                           MAX(pi.url)     FILTER (WHERE pi.position = 1) AS primary_image_url
                    FROM product_variants pv
                             LEFT JOIN product_images pi ON pi.product_variants_id = pv.id
                    GROUP BY pv.product_id) img ON img.product_id = p.id;
COMMENT
ON VIEW view_product_catalog_full IS 'One-row-per-product catalog summary with variant, category, and image rollups.';

CREATE
OR REPLACE VIEW view_variants_per_product AS
SELECT p.id                         AS product_id,
       p.name                       AS product_name,
       pv.id                        AS variant_id,
       pv.sku,
       b.id                         AS brand_id,
       b.name                       AS brand_name,
       pv.barcode,
       pv.price,
       pv.status,
       pv.weight,
       pv.created_at,
       COALESCE(img.image_count, 0) AS image_count,
       img.primary_image_url
FROM product_variants pv
         JOIN products p ON p.id = pv.product_id
         JOIN brands b ON b.id = pv.brand_id
         LEFT JOIN (SELECT product_variants_id,
                           COUNT(*) AS image_count,
                           MAX(url)    FILTER (WHERE position = 1) AS primary_image_url
                    FROM product_images
                    GROUP BY product_variants_id) img ON img.product_variants_id = pv.id;
COMMENT
ON VIEW view_variants_per_product IS 'Variant catalog with brand and primary image information for product detail pages.';

CREATE
OR REPLACE VIEW view_product_images_summary AS
SELECT p.id   AS             product_id,
       p.name AS             product_name,
       COUNT(DISTINCT pv.id) FILTER (WHERE pi.id IS NOT NULL) AS variant_count_with_images, COUNT(pi.id) AS total_images,
       MAX(pi.url)           FILTER (WHERE pi.position = 1) AS primary_image_url
FROM products p
         JOIN product_variants pv ON pv.product_id = p.id
         LEFT JOIN product_images pi ON pi.product_variants_id = pv.id
GROUP BY p.id, p.name;
COMMENT
ON VIEW view_product_images_summary IS 'Product-level image summary rolled up from variant images.';

CREATE
OR REPLACE VIEW view_variant_images_ordered AS
SELECT pv.id AS variant_id,
       pv.sku,
       pi.id AS image_id,
       pi.url,
       pi.position
FROM product_variants pv
         JOIN product_images pi ON pi.product_variants_id = pv.id;
COMMENT
ON VIEW view_variant_images_ordered IS 'Ordered variant images for UI galleries and media management.';

CREATE
OR REPLACE VIEW view_variant_attributes AS
SELECT pv.id    AS variant_id,
       pv.product_id,
       pv.sku,
       a.id     AS attribute_id,
       a.name   AS attribute_name,
       av.id    AS attribute_value_id,
       av.value AS attribute_value,
       a.data_type,
       a.unit
FROM product_variants pv
         JOIN variant_attributes va ON va.product_variant_id = pv.id
         JOIN attribute_values av ON av.id = va.attribute_value_id
    AND av.attribute_id = va.attribute_id
         JOIN attributes a ON a.id = va.attribute_id;
COMMENT
ON VIEW view_variant_attributes IS 'Variant attribute assignments in normalized row form for filtering and enrichment.';

CREATE
OR REPLACE VIEW view_variant_attribute_matrix AS
SELECT pv.id AS variant_id,
       pv.sku,
       pv.product_id,
       COALESCE(
               STRING_AGG(a.name || ': ' || av.value, ', ' ORDER BY a.name),
               ''
       )     AS attributes_text
FROM product_variants pv
         LEFT JOIN variant_attributes va ON va.product_variant_id = pv.id
         LEFT JOIN attribute_values av ON av.id = va.attribute_value_id
    AND av.attribute_id = va.attribute_id
         LEFT JOIN attributes a ON a.id = va.attribute_id
GROUP BY pv.id, pv.sku, pv.product_id;
COMMENT
ON VIEW view_variant_attribute_matrix IS 'Compact, human-readable variant attribute string for UI badges and reports.';

CREATE
OR REPLACE VIEW view_products_without_categories AS
SELECT p.id   AS product_id,
       p.name AS product_name,
       p.description,
       p.created_at,
       p.updated_at
FROM products p
         LEFT JOIN product_categories pc ON pc.product_id = p.id
WHERE pc.product_id IS NULL;
COMMENT
ON VIEW view_products_without_categories IS 'Data-quality view listing products that are not assigned to any category.';

CREATE
OR REPLACE VIEW view_products_without_variants AS
SELECT p.id   AS product_id,
       p.name AS product_name,
       p.description,
       p.created_at,
       p.updated_at
FROM products p
         LEFT JOIN product_variants pv ON pv.product_id = p.id
WHERE pv.product_id IS NULL;
COMMENT
ON VIEW view_products_without_variants IS 'Data-quality view listing products that do not have any variants yet.';

CREATE
OR REPLACE VIEW view_variants_without_images AS
SELECT pv.id AS variant_id,
       pv.product_id,
       pv.sku,
       pv.status,
       pv.created_at
FROM product_variants pv
         LEFT JOIN product_images pi ON pi.product_variants_id = pv.id
WHERE pi.product_variants_id IS NULL;
COMMENT
ON VIEW view_variants_without_images IS 'Data-quality view listing variants with no images attached.';

CREATE
OR REPLACE VIEW view_categories_without_products AS
SELECT c.id   AS category_id,
       c.parent_id,
       c.name AS category_name
FROM categories c
         LEFT JOIN product_categories pc ON pc.category_id = c.id
WHERE pc.category_id IS NULL;
COMMENT
ON VIEW view_categories_without_products IS 'Data-quality view listing categories that currently contain no products.';

-- ---------------------------------------------------------------------------
-- 2) INVENTORY / WAREHOUSE STOCK VIEWS
-- ---------------------------------------------------------------------------

CREATE
OR REPLACE VIEW view_inventory_summary AS
SELECT i.product_variant_id,
       COALESCE(SUM(i.quantity), 0)                       AS total_quantity,
       COALESCE(SUM(i.reserved_quantity), 0)              AS reserved_quantity,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0) AS available_quantity,
       COUNT(*)                                           AS inventory_rows,
       COUNT(DISTINCT i.bin_id)                           AS bin_count
FROM inventory i
GROUP BY i.product_variant_id;
COMMENT
ON VIEW view_inventory_summary IS 'Variant-level inventory aggregation across all bins and warehouses.';

CREATE
OR REPLACE VIEW view_variant_stock_status AS
SELECT pv.id                               AS variant_id,
       pv.product_id,
       pv.sku,
       pv.status                           AS variant_status,
       COALESCE(inv.total_quantity, 0)     AS total_quantity,
       COALESCE(inv.reserved_quantity, 0)  AS reserved_quantity,
       COALESCE(inv.available_quantity, 0) AS available_quantity,
       CASE
           WHEN inv.product_variant_id IS NULL THEN 'NO_INVENTORY'
           WHEN COALESCE(inv.total_quantity, 0) = 0 THEN 'OUT_OF_STOCK'
           WHEN COALESCE(inv.available_quantity, 0) = 0 AND COALESCE(inv.total_quantity, 0) > 0 THEN 'FULLY_RESERVED'
           WHEN COALESCE(inv.available_quantity, 0) < 10 THEN 'LOW_STOCK'
           ELSE 'IN_STOCK'
           END                             AS stock_state
FROM product_variants pv
         LEFT JOIN view_inventory_summary inv ON inv.product_variant_id = pv.id;
COMMENT
ON VIEW view_variant_stock_status IS 'Variant stock state with operational classification such as in stock, low stock, fully reserved, or no inventory.';

CREATE
OR REPLACE VIEW view_low_stock AS
SELECT *
FROM view_variant_stock_status
WHERE stock_state = 'LOW_STOCK';
COMMENT
ON VIEW view_low_stock IS 'Variants with low available stock below the operational threshold.';

CREATE
OR REPLACE VIEW view_out_of_stock AS
SELECT *
FROM view_variant_stock_status
WHERE stock_state IN ('NO_INVENTORY', 'OUT_OF_STOCK');
COMMENT
ON VIEW view_out_of_stock IS 'Variants with no inventory records or zero total stock.';

CREATE
OR REPLACE VIEW view_fully_reserved_stock AS
SELECT *
FROM view_variant_stock_status
WHERE stock_state = 'FULLY_RESERVED';
COMMENT
ON VIEW view_fully_reserved_stock IS 'Variants that still have stock on hand but none available because it is fully reserved.';

CREATE
OR REPLACE VIEW view_stock_alerts AS
SELECT variant_id,
       product_id,
       sku,
       variant_status,
       total_quantity,
       reserved_quantity,
       available_quantity,
       stock_state,
       CASE
           WHEN stock_state IN ('NO_INVENTORY', 'OUT_OF_STOCK') THEN 'HIGH'
           WHEN stock_state = 'FULLY_RESERVED' THEN 'MEDIUM'
           WHEN stock_state = 'LOW_STOCK' THEN 'LOW'
           ELSE 'NONE'
           END AS severity
FROM view_variant_stock_status
WHERE stock_state <> 'IN_STOCK';
COMMENT
ON VIEW view_stock_alerts IS 'Unified stock exception view for replenishment, reservation, and exception management.';

CREATE
OR REPLACE VIEW view_current_warehouse_stock AS
SELECT w.id                                               AS warehouse_id,
       w.name                                             AS warehouse_name,
       p.id                                               AS product_id,
       p.name                                             AS product_name,
       pv.id                                              AS variant_id,
       pv.sku,
       b.name                                             AS brand_name,
       pv.status                                          AS variant_status,
       COALESCE(SUM(i.quantity), 0)                       AS total_quantity,
       COALESCE(SUM(i.reserved_quantity), 0)              AS reserved_quantity,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0) AS available_quantity,
       COUNT(DISTINCT i.bin_id)                           AS bin_count
FROM inventory i
         JOIN product_variants pv ON pv.id = i.product_variant_id
         JOIN products p ON p.id = pv.product_id
         JOIN brands b ON b.id = pv.brand_id
         JOIN bins bin ON bin.id = i.bin_id
         JOIN locations l ON l.id = bin.location_id
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
GROUP BY w.id, w.name,
         p.id, p.name,
         pv.id, pv.sku,
         b.name,
         pv.status;
COMMENT
ON VIEW view_current_warehouse_stock IS 'Current stock by warehouse, product, and variant with bin coverage metrics.';

CREATE
OR REPLACE VIEW view_warehouse_stock_summary AS
SELECT w.id                                               AS warehouse_id,
       w.name                                             AS warehouse_name,
       COALESCE(SUM(i.quantity), 0)                       AS total_quantity,
       COALESCE(SUM(i.reserved_quantity), 0)              AS reserved_quantity,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0) AS available_quantity,
       COUNT(DISTINCT i.product_variant_id)               AS stocked_variants,
       COUNT(DISTINCT b.id)                               AS bins_with_stock
FROM warehouses w
         LEFT JOIN sections s ON s.warehouse_id = w.id
         LEFT JOIN locations l ON l.section_id = s.id
         LEFT JOIN bins b ON b.location_id = l.id
         LEFT JOIN inventory i ON i.bin_id = b.id
GROUP BY w.id, w.name;
COMMENT
ON VIEW view_warehouse_stock_summary IS 'Warehouse-level stock totals, variant coverage, and stock-bearing bin counts.';

CREATE
OR REPLACE VIEW view_stock_by_section AS
SELECT w.id                                               AS warehouse_id,
       w.name                                             AS warehouse_name,
       s.id                                               AS section_id,
       s.name                                             AS section_name,
       COALESCE(SUM(i.quantity), 0)                       AS total_quantity,
       COALESCE(SUM(i.reserved_quantity), 0)              AS reserved_quantity,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0) AS available_quantity,
       COUNT(DISTINCT b.id)                               AS bin_count
FROM sections s
         JOIN warehouses w ON w.id = s.warehouse_id
         LEFT JOIN locations l ON l.section_id = s.id
         LEFT JOIN bins b ON b.location_id = l.id
         LEFT JOIN inventory i ON i.bin_id = b.id
GROUP BY w.id, w.name, s.id, s.name;
COMMENT
ON VIEW view_stock_by_section IS 'Stock totals aggregated by warehouse section for zone-level planning and replenishment.';

CREATE
OR REPLACE VIEW view_stock_by_location AS
SELECT w.id                                               AS warehouse_id,
       w.name                                             AS warehouse_name,
       s.id                                               AS section_id,
       s.name                                             AS section_name,
       l.id                                               AS location_id,
       l.location_code,
       l.row_number,
       l.column_number,
       l.level_number,
       COALESCE(SUM(i.quantity), 0)                       AS total_quantity,
       COALESCE(SUM(i.reserved_quantity), 0)              AS reserved_quantity,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0) AS available_quantity
FROM locations l
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
         LEFT JOIN bins b ON b.location_id = l.id
         LEFT JOIN inventory i ON i.bin_id = b.id
GROUP BY w.id, w.name,
         s.id, s.name,
         l.id, l.location_code, l.row_number, l.column_number, l.level_number;
COMMENT
ON VIEW view_stock_by_location IS 'Stock totals at the location coordinate level for warehouse floor-plan reporting.';

CREATE
OR REPLACE VIEW view_warehouse_bin_map AS
SELECT w.id                                AS warehouse_id,
       w.name                              AS warehouse_name,
       s.id                                AS section_id,
       s.name                              AS section_name,
       l.id                                AS location_id,
       l.location_code,
       b.id                                AS bin_id,
       b.bin_code,
       b.capacity,
       COALESCE(inv.total_quantity, 0)     AS total_quantity,
       COALESCE(inv.reserved_quantity, 0)  AS reserved_quantity,
       COALESCE(inv.available_quantity, 0) AS available_quantity
FROM warehouses w
         JOIN sections s ON s.warehouse_id = w.id
         JOIN locations l ON l.section_id = s.id
         LEFT JOIN bins b ON b.location_id = l.id
         LEFT JOIN (SELECT bin_id,
                           SUM(quantity)                     AS total_quantity,
                           SUM(reserved_quantity)            AS reserved_quantity,
                           SUM(quantity - reserved_quantity) AS available_quantity
                    FROM inventory
                    GROUP BY bin_id) inv ON inv.bin_id = b.id;
COMMENT
ON VIEW view_warehouse_bin_map IS 'Physical warehouse map with bin codes, capacity, and current stock totals.';

CREATE
OR REPLACE VIEW view_empty_bins AS
SELECT b.id   AS bin_id,
       b.bin_code,
       b.capacity,
       l.id   AS location_id,
       l.location_code,
       s.id   AS section_id,
       s.name AS section_name,
       w.id   AS warehouse_id,
       w.name AS warehouse_name
FROM bins b
         JOIN locations l ON l.id = b.location_id
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
         LEFT JOIN inventory i ON i.bin_id = b.id
GROUP BY b.id, b.bin_code, b.capacity, l.id, l.location_code, s.id, s.name, w.id, w.name
HAVING COALESCE(SUM(i.quantity), 0) = 0;
COMMENT
ON VIEW view_empty_bins IS 'Bins with no stock on hand, useful for slotting and utilization planning.';

CREATE
OR REPLACE VIEW view_locations_without_bins AS
SELECT l.id   AS location_id,
       l.location_code,
       l.row_number,
       l.column_number,
       l.level_number,
       s.id   AS section_id,
       s.name AS section_name,
       w.id   AS warehouse_id,
       w.name AS warehouse_name
FROM locations l
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
         LEFT JOIN bins b ON b.location_id = l.id
WHERE b.id IS NULL;
COMMENT
ON VIEW view_locations_without_bins IS 'Locations that have no bin assigned yet.';

CREATE
OR REPLACE VIEW view_bin_utilization AS
SELECT b.id                                                                           AS bin_id,
       b.bin_code,
       b.capacity,
       COALESCE(SUM(i.quantity), 0)                                                   AS current_quantity,
       COALESCE(SUM(i.reserved_quantity), 0)                                          AS reserved_quantity,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0)                             AS available_quantity,
       ROUND(COALESCE(SUM(i.quantity) ::numeric / NULLIF(b.capacity, 0) * 100, 0), 2) AS occupancy_pct
FROM bins b
         LEFT JOIN inventory i ON i.bin_id = b.id
GROUP BY b.id, b.bin_code, b.capacity;
COMMENT
ON VIEW view_bin_utilization IS 'Bin occupancy metrics for slotting, replenishment, and capacity planning.';

CREATE
OR REPLACE VIEW view_bin_capacity_alerts AS
SELECT *,
       CASE
           WHEN occupancy_pct >= 100 THEN 'CRITICAL'
           WHEN occupancy_pct >= 90 THEN 'HIGH'
           WHEN occupancy_pct >= 75 THEN 'MEDIUM'
           ELSE 'OK'
           END AS capacity_alert
FROM view_bin_utilization
WHERE occupancy_pct >= 75;
COMMENT
ON VIEW view_bin_capacity_alerts IS 'Bins nearing capacity or already full, useful for re-slotting and space management.';

CREATE
OR REPLACE VIEW view_stock_value_by_variant AS
SELECT pv.id                                                         AS variant_id,
       pv.sku,
       pv.price,
       COALESCE(SUM(i.quantity), 0)                                  AS total_qty,
       COALESCE(SUM(i.reserved_quantity), 0)                         AS reserved_qty,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0)            AS available_qty,
       COALESCE(SUM(i.quantity - i.reserved_quantity) * pv.price, 0) AS available_value,
       COALESCE(SUM(i.quantity) * pv.price, 0)                       AS gross_value
FROM product_variants pv
         LEFT JOIN inventory i ON i.product_variant_id = pv.id
GROUP BY pv.id, pv.sku, pv.price;
COMMENT
ON VIEW view_stock_value_by_variant IS 'Variant-level stock valuation using both gross and available inventory values.';

CREATE
OR REPLACE VIEW view_stock_value_by_warehouse AS
SELECT w.id                                                            AS warehouse_id,
       w.name                                                          AS warehouse_name,
       COALESCE(SUM((i.quantity - i.reserved_quantity) * pv.price), 0) AS available_stock_value,
       COALESCE(SUM(i.quantity * pv.price), 0)                         AS gross_stock_value
FROM inventory i
         JOIN product_variants pv ON pv.id = i.product_variant_id
         JOIN bins b ON b.id = i.bin_id
         JOIN locations l ON l.id = b.location_id
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
GROUP BY w.id, w.name;
COMMENT
ON VIEW view_stock_value_by_warehouse IS 'Warehouse-level valuation of gross and available stock for finance and management reporting.';

CREATE
OR REPLACE VIEW view_stock_by_category AS
SELECT c.id                                               AS category_id,
       c.name                                             AS category_name,
       w.id                                               AS warehouse_id,
       w.name                                             AS warehouse_name,
       COALESCE(SUM(i.quantity), 0)                       AS total_quantity,
       COALESCE(SUM(i.reserved_quantity), 0)              AS reserved_quantity,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0) AS available_quantity
FROM inventory i
         JOIN product_variants pv ON pv.id = i.product_variant_id
         JOIN products p ON p.id = pv.product_id
         JOIN product_categories pc ON pc.product_id = p.id
         JOIN categories c ON c.id = pc.category_id
         JOIN bins b ON b.id = i.bin_id
         JOIN locations l ON l.id = b.location_id
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
GROUP BY c.id, c.name, w.id, w.name;
COMMENT
ON VIEW view_stock_by_category IS 'Category-driven stock totals split by warehouse for merchandising and replenishment.';

-- ---------------------------------------------------------------------------
-- 3) INVENTORY MOVEMENTS / TRANSACTIONS
-- ---------------------------------------------------------------------------

CREATE
OR REPLACE VIEW view_inventory_movements_detailed AS
SELECT im.id                                                   AS movement_id,
       im.created_at,
       im.product_variant_id,
       pv.sku,
       p.name                                                  AS product_name,
       b.name                                                  AS brand_name,
       im.quantity,
       im.from_bin_id,
       from_bin.bin_code                                       AS from_bin_code,
       from_loc.location_code                                  AS from_location_code,
       from_sec.name                                           AS from_section_name,
       from_wh.name                                            AS from_warehouse_name,
       im.to_bin_id,
       to_bin.bin_code                                         AS to_bin_code,
       to_loc.location_code                                    AS to_location_code,
       to_sec.name                                             AS to_section_name,
       to_wh.name                                              AS to_warehouse_name,
       it.id                                                   AS transaction_id,
       it.transaction_type,
       CONCAT_WS(' ', creator.first_name, creator.last_name)   AS created_by,
       CONCAT_WS(' ', updater.first_name, updater.last_name)   AS last_updated_by,
       CONCAT_WS(' ', acceptor.first_name, acceptor.last_name) AS accepted_by,
       CONCAT_WS(' ', packer.first_name, packer.last_name)     AS packed_by
FROM inventory_movements im
         JOIN product_variants pv ON pv.id = im.product_variant_id
         JOIN products p ON p.id = pv.product_id
         JOIN brands b ON b.id = pv.brand_id
         JOIN inventory_transactions it ON it.id = im.inventory_transactions_id
         JOIN employees creator ON creator.id = it.created_by_employee
         LEFT JOIN employees updater ON updater.id = it.last_updated_by
         LEFT JOIN employees acceptor ON acceptor.id = it.accepted_by
         LEFT JOIN employees packer ON packer.id = it.packed_by
         LEFT JOIN bins from_bin ON from_bin.id = im.from_bin_id
         LEFT JOIN locations from_loc ON from_loc.id = from_bin.location_id
         LEFT JOIN sections from_sec ON from_sec.id = from_loc.section_id
         LEFT JOIN warehouses from_wh ON from_wh.id = from_sec.warehouse_id
         LEFT JOIN bins to_bin ON to_bin.id = im.to_bin_id
         LEFT JOIN locations to_loc ON to_loc.id = to_bin.location_id
         LEFT JOIN sections to_sec ON to_sec.id = to_loc.section_id
         LEFT JOIN warehouses to_wh ON to_wh.id = to_sec.warehouse_id;
COMMENT
ON VIEW view_inventory_movements_detailed IS 'Detailed movement ledger with product, bin, warehouse, and employee context.';

CREATE
OR REPLACE VIEW view_inventory_movement_timeline AS
SELECT im.id                                                 AS movement_id,
       im.created_at,
       it.id                                                 AS transaction_id,
       it.transaction_type,
       CASE
           WHEN im.from_bin_id IS NULL AND im.to_bin_id IS NOT NULL THEN 'RECEIPT'
           WHEN im.from_bin_id IS NOT NULL AND im.to_bin_id IS NULL THEN 'DISPATCH'
           WHEN im.from_bin_id IS NOT NULL AND im.to_bin_id IS NOT NULL THEN 'TRANSFER'
           ELSE 'UNKNOWN'
           END                                               AS movement_kind,
       pv.id                                                 AS variant_id,
       pv.sku,
       p.name                                                AS product_name,
       im.quantity,
       fb.bin_code                                           AS from_bin_code,
       tb.bin_code                                           AS to_bin_code,
       CONCAT_WS(' ', creator.first_name, creator.last_name) AS created_by
FROM inventory_movements im
         JOIN inventory_transactions it ON it.id = im.inventory_transactions_id
         JOIN employees creator ON creator.id = it.created_by_employee
         JOIN product_variants pv ON pv.id = im.product_variant_id
         JOIN products p ON p.id = pv.product_id
         LEFT JOIN bins fb ON fb.id = im.from_bin_id
         LEFT JOIN bins tb ON tb.id = im.to_bin_id;
COMMENT
ON VIEW view_inventory_movement_timeline IS 'Timeline-friendly movement view with a business classification for receipts, dispatches, and transfers.';

CREATE
OR REPLACE VIEW view_inventory_movements_by_day AS
SELECT im.created_at::date AS movement_date, it.transaction_type,
       COUNT(*)         AS movement_count,
       SUM(im.quantity) AS total_quantity_moved
FROM inventory_movements im
         JOIN inventory_transactions it ON it.id = im.inventory_transactions_id
GROUP BY im.created_at::date, it.transaction_type;
COMMENT
ON VIEW view_inventory_movements_by_day IS 'Daily movement rollup by transaction type for trend analysis.';

CREATE
OR REPLACE VIEW view_inventory_movements_by_type AS
SELECT it.transaction_type,
       COUNT(*)           AS movement_count,
       SUM(im.quantity)   AS total_quantity_moved,
       MIN(im.created_at) AS first_movement_at,
       MAX(im.created_at) AS last_movement_at
FROM inventory_movements im
         JOIN inventory_transactions it ON it.id = im.inventory_transactions_id
GROUP BY it.transaction_type;
COMMENT
ON VIEW view_inventory_movements_by_type IS 'Movement summary by transaction type for operational throughput reporting.';

CREATE
OR REPLACE VIEW view_transactions_full AS
SELECT it.id                                                   AS transaction_id,
       it.transaction_type,
       it.created_at,
       CONCAT_WS(' ', creator.first_name, creator.last_name)   AS created_by,
       CONCAT_WS(' ', updater.first_name, updater.last_name)   AS last_updated_by,
       CONCAT_WS(' ', acceptor.first_name, acceptor.last_name) AS accepted_by,
       CONCAT_WS(' ', packer.first_name, packer.last_name)     AS packed_by,
       dt.supplier_company,
       dt.delivery_note,
       st.shipment_number,
       st.destination_adress
FROM inventory_transactions it
         JOIN employees creator ON creator.id = it.created_by_employee
         LEFT JOIN employees updater ON updater.id = it.last_updated_by
         LEFT JOIN employees acceptor ON acceptor.id = it.accepted_by
         LEFT JOIN employees packer ON packer.id = it.packed_by
         LEFT JOIN delivery_transactions dt ON dt.inventory_transactions_id = it.id
         LEFT JOIN shipment_transactions st ON st.inventory_transactions_id = it.id;
COMMENT
ON VIEW view_transactions_full IS 'Full transaction header view with creator, approver, packer, and subtype details.';

CREATE
OR REPLACE VIEW view_delivery_transactions_detail AS
SELECT it.id                                                   AS transaction_id,
       it.transaction_type,
       it.created_at,
       dt.inventory_transactions_id,
       dt.supplier_company,
       dt.delivery_note,
       CONCAT_WS(' ', creator.first_name, creator.last_name)   AS created_by,
       CONCAT_WS(' ', updater.first_name, updater.last_name)   AS last_updated_by,
       CONCAT_WS(' ', acceptor.first_name, acceptor.last_name) AS accepted_by,
       CONCAT_WS(' ', packer.first_name, packer.last_name)     AS packed_by
FROM delivery_transactions dt
         JOIN inventory_transactions it ON it.id = dt.inventory_transactions_id
         JOIN employees creator ON creator.id = it.created_by_employee
         LEFT JOIN employees updater ON updater.id = it.last_updated_by
         LEFT JOIN employees acceptor ON acceptor.id = it.accepted_by
         LEFT JOIN employees packer ON packer.id = it.packed_by;
COMMENT
ON VIEW view_delivery_transactions_detail IS 'Delivery-specific transaction detail for inbound goods processing and auditing.';

CREATE
OR REPLACE VIEW view_shipment_transactions_detail AS
SELECT it.id                                                   AS transaction_id,
       it.transaction_type,
       it.created_at,
       st.inventory_transactions_id,
       st.shipment_number,
       st.destination_adress,
       CONCAT_WS(' ', creator.first_name, creator.last_name)   AS created_by,
       CONCAT_WS(' ', updater.first_name, updater.last_name)   AS last_updated_by,
       CONCAT_WS(' ', acceptor.first_name, acceptor.last_name) AS accepted_by,
       CONCAT_WS(' ', packer.first_name, packer.last_name)     AS packed_by
FROM shipment_transactions st
         JOIN inventory_transactions it ON it.id = st.inventory_transactions_id
         JOIN employees creator ON creator.id = it.created_by_employee
         LEFT JOIN employees updater ON updater.id = it.last_updated_by
         LEFT JOIN employees acceptor ON acceptor.id = it.accepted_by
         LEFT JOIN employees packer ON packer.id = it.packed_by;
COMMENT
ON VIEW view_shipment_transactions_detail IS 'Shipment-specific transaction detail for outbound goods processing and auditing.';

CREATE
OR REPLACE VIEW view_transaction_type_summary AS
SELECT tt.code            AS transaction_type,
       tt.description,
       COUNT(it.id)       AS transaction_count,
       MIN(it.created_at) AS first_transaction_at,
       MAX(it.created_at) AS last_transaction_at
FROM transaction_types tt
         LEFT JOIN inventory_transactions it ON it.transaction_type = tt.code
GROUP BY tt.code, tt.description;
COMMENT
ON VIEW view_transaction_type_summary IS 'Transaction type usage summary for process visibility and workload analysis.';

-- ---------------------------------------------------------------------------
-- 4) EMPLOYEES / ORGANIZATION / RBAC
-- ---------------------------------------------------------------------------

CREATE
OR REPLACE VIEW view_employees_with_manager AS
SELECT e.id                                      AS employee_id,
       e.employee_number,
       e.first_name,
       e.last_name,
       e.email,
       e.job_title,
       e.employment_status,
       CONCAT_WS(' ', m.first_name, m.last_name) AS manager_name,
       e.hired_at,
       e.terminated_at
FROM employees e
         LEFT JOIN employees m ON m.id = e.manager_id;
COMMENT
ON VIEW view_employees_with_manager IS 'Employee directory with manager name for org-chart and supervision reporting.';

CREATE
OR REPLACE VIEW view_active_employees AS
SELECT e.id                             AS employee_id,
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
WHERE e.terminated_at IS NULL
GROUP BY e.id, e.employee_number, e.first_name, e.last_name, e.email, e.phone,
         e.job_title, e.employment_status, e.hired_at;
COMMENT
ON VIEW view_active_employees IS 'Currently active employees with warehouse and role coverage counts.';

CREATE
OR REPLACE VIEW view_inactive_employees AS
SELECT e.id                                      AS employee_id,
       e.employee_number,
       e.first_name,
       e.last_name,
       e.email,
       e.phone,
       e.job_title,
       e.employment_status,
       e.hired_at,
       e.terminated_at,
       CONCAT_WS(' ', m.first_name, m.last_name) AS manager_name
FROM employees e
         LEFT JOIN employees m ON m.id = e.manager_id
WHERE e.terminated_at IS NOT NULL;
COMMENT
ON VIEW view_inactive_employees IS 'Former employees and their termination dates for HR and audit reporting.';

CREATE
OR REPLACE VIEW view_employee_assignment_history AS
SELECT ewa.id AS assignment_id,
       e.id   AS employee_id,
       e.employee_number,
       e.first_name,
       e.last_name,
       w.id   AS warehouse_id,
       w.name AS warehouse_name,
       ewa.start_date,
       ewa.end_date,
       ewa.is_primary,
       ewa.notes,
       ewa.created_at,
       ewa.updated_at
FROM employee_warehouse_assignments ewa
         JOIN employees e ON e.id = ewa.employee_id
         JOIN warehouses w ON w.id = ewa.warehouse_id;
COMMENT
ON VIEW view_employee_assignment_history IS 'Complete employee-to-warehouse assignment history with timestamps and notes.';

CREATE
OR REPLACE VIEW view_employee_current_warehouse AS
SELECT e.id   AS employee_id,
       e.employee_number,
       e.first_name,
       e.last_name,
       w.id   AS warehouse_id,
       w.name AS warehouse_name,
       ewa.start_date,
       ewa.end_date,
       ewa.is_primary
FROM employee_warehouse_assignments ewa
         JOIN employees e ON e.id = ewa.employee_id
         JOIN warehouses w ON w.id = ewa.warehouse_id
WHERE ewa.end_date IS NULL;
COMMENT
ON VIEW view_employee_current_warehouse IS 'Current employee warehouse assignments, including primary assignment flag.';

CREATE
OR REPLACE VIEW view_role_permission_matrix AS
SELECT r.id   AS role_id,
       r.name AS role_name,
       p.id   AS permission_id,
       p.name AS permission_name
FROM roles r
         LEFT JOIN permissions_roles pr ON pr.roles_id = r.id
         LEFT JOIN permissions p ON p.id = pr.permissions_id;
COMMENT
ON VIEW view_role_permission_matrix IS 'Role-to-permission matrix for RBAC administration and audits.';

CREATE
OR REPLACE VIEW view_employee_permissions AS
SELECT DISTINCT e.id   AS employee_id,
                e.employee_number,
                e.first_name,
                e.last_name,
                r.id   AS role_id,
                r.name AS role_name,
                p.id   AS permission_id,
                p.name AS permission_name
FROM employees e
         JOIN roles_employees re ON re.employees_id = e.id
         JOIN roles r ON r.id = re.roles_id
         JOIN permissions_roles pr ON pr.roles_id = r.id
         JOIN permissions p ON p.id = pr.permissions_id;
COMMENT
ON VIEW view_employee_permissions IS 'Effective employee permissions expanded through roles for authorization analysis.';

CREATE
OR REPLACE VIEW view_employee_role_summary AS
SELECT e.id                              AS employee_id,
       e.employee_number,
       e.first_name,
       e.last_name,
       COUNT(DISTINCT re.roles_id)       AS role_count,
       COUNT(DISTINCT pr.permissions_id) AS permission_count
FROM employees e
         LEFT JOIN roles_employees re ON re.employees_id = e.id
         LEFT JOIN permissions_roles pr ON pr.roles_id = re.roles_id
GROUP BY e.id, e.employee_number, e.first_name, e.last_name;
COMMENT
ON VIEW view_employee_role_summary IS 'Employee role and permission counts for fast RBAC overview.';

-- ---------------------------------------------------------------------------
-- 5) OPERATIONAL / EXCEPTION VIEWS
-- ---------------------------------------------------------------------------

CREATE
OR REPLACE VIEW view_bins_without_inventory AS
SELECT b.id   AS bin_id,
       b.bin_code,
       b.capacity,
       l.id   AS location_id,
       l.location_code,
       s.id   AS section_id,
       s.name AS section_name,
       w.id   AS warehouse_id,
       w.name AS warehouse_name
FROM bins b
         JOIN locations l ON l.id = b.location_id
         JOIN sections s ON s.id = l.section_id
         JOIN warehouses w ON w.id = s.warehouse_id
         LEFT JOIN inventory i ON i.bin_id = b.id
GROUP BY b.id, b.bin_code, b.capacity, l.id, l.location_code, s.id, s.name, w.id, w.name
HAVING COALESCE(SUM(i.quantity), 0) = 0;
COMMENT
ON VIEW view_bins_without_inventory IS 'Bins that currently hold no inventory, useful for slotting and capacity utilization.';

CREATE
OR REPLACE VIEW view_variants_without_stock AS
SELECT s.variant_id,
       s.product_id,
       s.sku,
       s.variant_status,
       s.total_quantity,
       s.reserved_quantity,
       s.available_quantity,
       s.stock_state
FROM view_variant_stock_status s
WHERE s.stock_state IN ('NO_INVENTORY', 'OUT_OF_STOCK');
COMMENT
ON VIEW view_variants_without_stock IS 'Variants with no stock available for sale or allocation.';

CREATE
OR REPLACE VIEW view_product_operational_dashboard AS
SELECT p.id                                      AS product_id,
       p.name                                    AS product_name,
       COALESCE(v.variant_count, 0)              AS variant_count,
       COALESCE(v.stocked_variant_count, 0)      AS stocked_variant_count,
       COALESCE(v.out_of_stock_variant_count, 0) AS out_of_stock_variant_count,
       COALESCE(v.low_stock_variant_count, 0)    AS low_stock_variant_count,
       COALESCE(v.total_available_quantity, 0)   AS total_available_quantity,
       COALESCE(v.total_available_value, 0)      AS total_available_value
FROM products p
         LEFT JOIN (SELECT pv.product_id,
                           COUNT(*)                                          AS variant_count,
                           COUNT(*)                                             FILTER (WHERE s.stock_state = 'IN_STOCK') AS stocked_variant_count, COUNT(*) FILTER (WHERE s.stock_state IN ('NO_INVENTORY', 'OUT_OF_STOCK')) AS out_of_stock_variant_count, COUNT(*) FILTER (WHERE s.stock_state = 'LOW_STOCK') AS low_stock_variant_count, SUM(COALESCE(s.available_quantity, 0)) AS total_available_quantity,
                           SUM(COALESCE(s.available_quantity, 0) * pv.price) AS total_available_value
                    FROM product_variants pv
                             JOIN view_variant_stock_status s ON s.variant_id = pv.id
                    GROUP BY pv.product_id) v ON v.product_id = p.id;
COMMENT
ON VIEW view_product_operational_dashboard IS 'Product-level operational snapshot with stock counts and value for management dashboards.';

COMMIT;
