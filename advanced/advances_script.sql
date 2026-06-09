CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS pg_cron;

--run this first as a benchmark
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_variant_id,
       SUM(quantity)
FROM inventory_movements
WHERE created_at BETWEEN '2025-01-01'
          AND '2025-03-31'
GROUP BY product_variant_id;


--make sure extention exists
SELECT extname
FROM pg_extension
WHERE extname='timescaledb';

--change pk
ALTER TABLE inventory_transactions DROP CONSTRAINT inventory_transactions_pkey;
ALTER TABLE inventory_transactions ADD PRIMARY KEY (id, created_at);

ALTER TABLE inventory_movements DROP CONSTRAINT inventory_movements_pkey;
ALTER TABLE inventory_movements ADD PRIMARY KEY (id, created_at);

--create hypertable
SELECT create_hypertable(
               'inventory_transactions',
               'created_at',
               chunk_time_interval => INTERVAL '1 month',
               migrate_data => TRUE
       );

SELECT create_hypertable(
               'inventory_movements',
               'created_at',
               chunk_time_interval => INTERVAL '1 month',
               migrate_data => TRUE
       );


--check
SELECT *
FROM timescaledb_information.hypertables;

--OLAP
-- Daily cube: movements per product variant, warehouse, day
CREATE MATERIALIZED VIEW cube_movements_daily
            WITH (timescaledb.continuous) AS
SELECT
    pv.product_id,
    pv.brand_id,
    COALESCE(w_from.id, w_to.id) AS warehouse_id,
    time_bucket('1 day', mv.created_at) AS day,
    SUM(mv.quantity) AS total_moved,
    COUNT(*) AS movement_count,
    COUNT(DISTINCT mv.inventory_transactions_id) AS transaction_count
FROM inventory_movements mv
         JOIN product_variants pv ON mv.product_variant_id = pv.id
         LEFT JOIN bins b_from ON mv.from_bin_id = b_from.id
         LEFT JOIN locations l_from ON b_from.location_id = l_from.id
         LEFT JOIN sections s_from ON l_from.section_id = s_from.id
         LEFT JOIN warehouses w_from ON s_from.warehouse_id = w_from.id
         LEFT JOIN bins b_to ON mv.to_bin_id = b_to.id
         LEFT JOIN locations l_to ON b_to.location_id = l_to.id
         LEFT JOIN sections s_to ON l_to.section_id = s_to.id
         LEFT JOIN warehouses w_to ON s_to.warehouse_id = w_to.id
GROUP BY pv.product_id, pv.brand_id,
         COALESCE(w_from.id, w_to.id),
         time_bucket('1 day', mv.created_at);



-- Monthly cube (aggregates the daily cube to save space)
CREATE MATERIALIZED VIEW cube_movements_monthly
WITH (timescaledb.continuous) AS
SELECT
    product_id,
    brand_id,
    warehouse_id,
    time_bucket('1 month', day) AS month,
    SUM(total_moved) AS total_moved,
    SUM(movement_count) AS movement_count,
    SUM(transaction_count) AS transaction_count
FROM cube_movements_daily
GROUP BY product_id, brand_id, warehouse_id, time_bucket('1 month', day);

-- Simple attribute cube (materialized view, not continuous)
CREATE MATERIALIZED VIEW cube_product_attributes AS
SELECT
    pv.product_id,
    a.name AS attribute_name,
    av.value AS attribute_value,
    COUNT(*) OVER (PARTITION BY pv.product_id) AS attr_count
FROM product_variants pv
         JOIN variant_attributes va ON pv.id = va.product_variant_id
         JOIN attributes a ON va.attribute_id = a.id
         JOIN attribute_values av ON va.attribute_value_id = av.id;


--automatic refresh policy

SELECT add_continuous_aggregate_policy('cube_movements_daily',
                                       start_offset => INTERVAL '3 days',
                                       end_offset => INTERVAL '1 hour',
                                       schedule_interval => INTERVAL '1 hour');


SELECT add_continuous_aggregate_policy('cube_movements_monthly',
                                       start_offset => INTERVAL '3 months',
                                       end_offset => INTERVAL '1 day',
                                       schedule_interval => INTERVAL '1 day');


SELECT cron.schedule('refresh-attributes', '0 2 * * *',
                     'REFRESH MATERIALIZED VIEW CONCURRENTLY cube_product_attributes');


--reports using the cubes

--1.Top 25% products by total moved quantity
WITH product_agg AS (
    SELECT
        p.name AS product_name,
        b.name AS brand_name,
        SUM(cmm.total_moved) AS total_qty
    FROM cube_movements_monthly cmm
             JOIN products p ON cmm.product_id = p.id
             JOIN brands b ON cmm.brand_id = b.id
    WHERE cmm.warehouse_id = 1
      AND cmm.month >= '2025-01-01' AND cmm.month < '2025-04-01'
    GROUP BY p.name, b.name
),
     quartiles AS (
         SELECT *,
                NTILE(4) OVER (ORDER BY total_qty DESC) AS quartile
         FROM product_agg
     )
SELECT product_name, brand_name, total_qty
FROM quartiles
WHERE quartile = 1
ORDER BY total_qty DESC
LIMIT 10;

--2. Bottom 25% warehouses by inventory (last 6 months)
WITH warehouse_turnover AS (
    SELECT
        w.name AS warehouse,
        SUM(cmm.total_moved) / NULLIF(SUM(i.quantity), 0) AS turnover_ratio
    FROM cube_movements_monthly cmm
             JOIN warehouses w ON cmm.warehouse_id = w.id
             LEFT JOIN inventory i ON i.product_variant_id = cmm.product_id  -- approximate
    WHERE cmm.month >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY w.id, w.name
),
     quartiles AS (
         SELECT *, NTILE(4) OVER (ORDER BY turnover_ratio ASC) AS quartile
         FROM warehouse_turnover
     )
SELECT warehouse, turnover_ratio
FROM quartiles
WHERE quartile = 1;


--3.top 25% products with attribute 'color' = 'red'
WITH red_products AS (
    SELECT product_id
    FROM cube_product_attributes
    WHERE attribute_name = 'color' AND attribute_value = 'red'
),
     product_sales AS (
         SELECT cmm.product_id, SUM(total_moved) AS sales
         FROM cube_movements_monthly cmm
         WHERE cmm.month >= '2025-01-01'
         GROUP BY cmm.product_id
     )
SELECT ps.product_id, ps.sales
FROM product_sales ps
         JOIN red_products rp ON ps.product_id = rp.product_id
ORDER BY ps.sales DESC
LIMIT (SELECT COUNT(*) * 0.25 FROM red_products);  -- top quartile

--performance test


--1.withought cube
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_variant_id, SUM(quantity)
FROM inventory_movements
WHERE created_at BETWEEN '2025-01-01' AND '2025-03-31'
GROUP BY product_variant_id;


--2.after cube
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, SUM(total_moved)
FROM cube_movements_monthly
WHERE month BETWEEN '2025-01-01' AND '2025-03-31'
GROUP BY product_id;



