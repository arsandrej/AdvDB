CREATE
    EXTENSION IF NOT EXISTS timescaledb;

-- Run this first as a benchmark (before hypertable conversion)
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_variant_id,
       SUM(quantity)
FROM inventory_movements
WHERE created_at BETWEEN '2025-01-01' AND '2025-03-31'
GROUP BY product_variant_id;


-- Make sure extension exists
SELECT extname
FROM pg_extension
WHERE extname = 'timescaledb';

ALTER TABLE inventory_movements
    DROP CONSTRAINT IF EXISTS inventory_movements_pkey;

ALTER TABLE delivery_transactions
    DROP CONSTRAINT fk_delivery_transactions_transaction;

ALTER TABLE shipment_transactions
    DROP CONSTRAINT fk_shipment_transactions_transaction;

ALTER TABLE inventory_movements
    DROP CONSTRAINT fk_inventory_movements_transaction;

ALTER TABLE inventory_transactions
    DROP CONSTRAINT IF EXISTS inventory_transactions_pkey;

ALTER TABLE inventory_movements
    ADD PRIMARY KEY (created_at, id);

ALTER TABLE inventory_transactions
    ADD PRIMARY KEY (created_at, id);


ALTER TABLE inventory_transactions
    RENAME TO inventory_transactions_old;

CREATE TABLE inventory_transactions
(
    LIKE inventory_transactions_old INCLUDING ALL
);

-- Create hypertables
SELECT create_hypertable(
               'inventory_transactions',
               'created_at',
               chunk_time_interval => INTERVAL '1 month',
               migrate_data => FALSE
       );

INSERT INTO inventory_transactions
SELECT *
FROM inventory_transactions_old
ORDER BY created_at;


ALTER TABLE inventory_movements
    RENAME TO inventory_movements_old;

CREATE TABLE inventory_movements
(
    LIKE inventory_movements_old INCLUDING ALL
);

SELECT create_hypertable(
               'inventory_movements',
               'created_at',
               chunk_time_interval => INTERVAL '1 month',
               migrate_data => FALSE
       );

INSERT INTO inventory_movements
SELECT *
FROM inventory_movements_old;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_inventory_transactions_created_at
    ON inventory_transactions (created_at, id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_inventory_movements_created_at
    ON inventory_movements (created_at, id);

-- Check hypertables
SELECT *
FROM timescaledb_information.hypertables;


-- OLAP LAYER
DROP materialized VIEW cube_movements_daily;
CREATE MATERIALIZED VIEW cube_movements_daily
    WITH (timescaledb.continuous) AS
SELECT pv.product_id,
       pv.brand_id,
       w.id                                         AS warehouse_id,
       time_bucket('1 day', mv.created_at)          AS day,

       SUM(
               CASE
                   WHEN mv.from_bin_id IS NOT NULL THEN -mv.quantity
                   ELSE 0
                   END
                   +
               CASE
                   WHEN mv.to_bin_id IS NOT NULL THEN mv.quantity
                   ELSE 0
                   END
       )                                            AS total_moved,

       COUNT(*)                                     AS movement_count,
       COUNT(DISTINCT mv.inventory_transactions_id) AS transaction_count

FROM inventory_movements mv
         JOIN product_variants pv ON mv.product_variant_id = pv.id
         LEFT JOIN bins b_from ON mv.from_bin_id = b_from.id
         LEFT JOIN bins b_to ON mv.to_bin_id = b_to.id
         LEFT JOIN locations l ON COALESCE(b_from.location_id, b_to.location_id) = l.id
         LEFT JOIN sections s ON l.section_id = s.id
         LEFT JOIN warehouses w ON s.warehouse_id = w.id

GROUP BY pv.product_id,
         pv.brand_id,
         w.id,
         time_bucket('1 day', mv.created_at);


CREATE MATERIALIZED VIEW cube_movements_monthly
    WITH (timescaledb.continuous) AS
SELECT product_id,
       brand_id,
       warehouse_id,
       time_bucket('1 month', day) AS month,

       SUM(total_moved)            AS total_moved,
       SUM(movement_count)         AS movement_count,
       SUM(transaction_count)      AS transaction_count

FROM cube_movements_daily
GROUP BY product_id,
         brand_id,
         warehouse_id,
         time_bucket('1 month', day)
WITH NO DATA;

-- Automatic refresh policies

SELECT add_continuous_aggregate_policy(
               'cube_movements_outbound_daily',
               start_offset => INTERVAL '3 days',
               end_offset => INTERVAL '1 hour',
               schedule_interval => INTERVAL '1 hour'
       );
SELECT add_continuous_aggregate_policy(
               'cube_movements_inbound_daily',
               start_offset => INTERVAL '3 days',
               end_offset => INTERVAL '1 hour',
               schedule_interval => INTERVAL '1 hour'
       );

CALL refresh_continuous_aggregate(
  'cube_movements_monthly',
  NULL,
  NULL
);

-- REPORTS

-- 1. Top 25% products by total moved quantity (warehouse 1, Q1 2025)
WITH product_agg AS (SELECT p.name               AS product_name,
                            b.name               AS brand_name,
                            SUM(cmm.total_moved) AS total_qty
                     FROM cube_movements_monthly cmm
                              JOIN products p ON cmm.product_id = p.id
                              JOIN brands b ON cmm.brand_id = b.id
                     WHERE cmm.warehouse_id = 1
                       AND cmm.month >= '2025-01-01'
                       AND cmm.month < '2025-04-01'
                     GROUP BY p.name, b.name),
     quartiles AS (SELECT *,
                          NTILE(4) OVER (ORDER BY total_qty DESC) AS quartile
                   FROM product_agg)
SELECT *
FROM quartiles
WHERE quartile = 1
ORDER BY total_qty DESC
LIMIT 10;


-- 2. Bottom 25% warehouses by inventory turnover (last 6 months)
WITH inventory_by_product AS (SELECT pv.product_id,
                                     SUM(i.quantity) AS total_on_hand
                              FROM inventory i
                                       JOIN product_variants pv ON i.product_variant_id = pv.id
                              GROUP BY pv.product_id),
     warehouse_turnover AS (SELECT w.name                                  AS warehouse,
                                   SUM(cmm.total_moved)
                                       / NULLIF(SUM(ibp.total_on_hand), 0) AS turnover_ratio
                            FROM cube_movements_monthly cmm
                                     JOIN warehouses w ON cmm.warehouse_id = w.id
                                     LEFT JOIN inventory_by_product ibp
                                               ON ibp.product_id = cmm.product_id
                            WHERE cmm.month >= CURRENT_DATE - INTERVAL '6 months'
                            GROUP BY w.id, w.name),
     quartiles AS (SELECT *,
                          NTILE(4) OVER (ORDER BY turnover_ratio ASC) AS quartile
                   FROM warehouse_turnover)
SELECT *
FROM quartiles
WHERE quartile = 1;
