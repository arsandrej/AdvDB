-- =============================================================================
-- EMPLOYEE_WAREHOUSE_ASSIGNMENTS  –  Seed Script
-- =============================================================================
--
-- Strategy
-- ─────────
-- 1. Insert the 16 warehouses (if not already present).
-- 2. PRIMARY assignments
--      • Every employee gets exactly one active primary assignment.
--      • Employees are distributed evenly across the 16 warehouses
--        (≈ 125 per warehouse).
--      • start_date  = hired_at::date
--      • end_date    = terminated_at::date  (NULL for active staff)
--
-- 3. TEMPORARY / SECONDARY assignments  (same city, other warehouse)
--      • Every employee with a same-city partner warehouse gets at least
--        one temporary assignment there.
--      • We generate MULTIPLE rotations:
--          – Rotation 1: covers 100 % of eligible employees once.
--          – Rotations 2-8: cover 50 % of eligible employees each time,
--            with shifted date windows so all rows are unique.
--      • This brings the total easily past 500 k – 1 M rows while
--        staying internally consistent.
--
-- 4. HISTORICAL assignments for terminated employees
--      • Terminated staff get 1-3 extra historical rows representing
--        assignments at earlier warehouses (including the partner
--        warehouse in the same city) that ended before their last
--        primary assignment started.
--
-- All dates are kept coherent:
--   historical_end < primary_start ≤ temp_start ≤ temp_end ≤ (terminated_at or now)
-- =============================================================================

BEGIN;


-- ---------------------------------------------------------------------------
-- 2. HELPER: warehouse pairs per city (each warehouse knows its city-partner)
-- ---------------------------------------------------------------------------

-- We'll reference warehouses by name throughout. A CTE is used in each INSERT.

-- ---------------------------------------------------------------------------
-- 3. PRIMARY ASSIGNMENTS
--    One row per employee. is_primary = TRUE.
--    Evenly distributed: employee rank mod 16 determines the warehouse.
-- ---------------------------------------------------------------------------

INSERT INTO EMPLOYEE_WAREHOUSE_ASSIGNMENTS
    (employee_id, warehouse_id, start_date, end_date, is_primary, notes, created_at, updated_at)

WITH

ranked_employees AS (
    SELECT
        id,
        hired_at,
        terminated_at,
        ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM EMPLOYEES
),

warehouses_ranked AS (
    SELECT
        id,
        ROW_NUMBER() OVER (ORDER BY id) AS wrn
    FROM WAREHOUSES
),

assigned AS (
    SELECT
        e.id            AS employee_id,
        w.id            AS warehouse_id,
        e.hired_at::date AS start_date,
        e.terminated_at::date AS end_date,   -- NULL for active
        e.rn
    FROM ranked_employees e
    JOIN warehouses_ranked w
      ON w.wrn = ((e.rn - 1) % 16) + 1
)

SELECT
    employee_id,
    warehouse_id,
    start_date,
    end_date,
    TRUE                                        AS is_primary,
    'Initial primary warehouse assignment'      AS notes,
    CURRENT_TIMESTAMP                           AS created_at,
    CURRENT_TIMESTAMP                           AS updated_at
FROM assigned
ON CONFLICT (employee_id, warehouse_id, start_date) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. TEMPORARY SECONDARY ASSIGNMENTS (same-city partner warehouse)
--
--    City pairs (warehouse_id slots when ordered by id):
--      New York      : slots 1 & 2
--      Los Angeles   : slots 3 & 4
--      Chicago       : slots 5 & 6
--      Houston       : slots 7 & 8
--      Phoenix       : slots 9 & 10
--      Philadelphia  : slots 11 & 12
--      San Antonio   : slots 13 & 14
--      San Diego     : slots 15 & 16
--
--    For each rotation we offset start/end dates so rows are unique.
--    Rotations 1-8 are done via a generate_series; each covers a
--    different subset of employees and a different date window.
-- ---------------------------------------------------------------------------

INSERT INTO EMPLOYEE_WAREHOUSE_ASSIGNMENTS
    (employee_id, warehouse_id, start_date, end_date, is_primary, notes, created_at, updated_at)

WITH

-- Pair every warehouse with its same-city partner
warehouse_pairs AS (
    SELECT
        w1.id   AS warehouse_id,
        w2.id   AS partner_id,
        w1.city
    FROM WAREHOUSES w1
    JOIN WAREHOUSES w2
      ON  w1.city = w2.city
      AND w1.id  <> w2.id
),

-- Employee's primary warehouse → derive partner
emp_primary AS (
    SELECT
        a.employee_id,
        a.warehouse_id                      AS primary_wh_id,
        a.start_date                        AS hire_date,
        a.end_date                          AS term_date,        -- may be NULL
        wp.partner_id                       AS partner_wh_id,
        e.hired_at,
        e.terminated_at,
        ROW_NUMBER() OVER (ORDER BY a.employee_id) AS ern
    FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS a
    JOIN EMPLOYEES e ON e.id = a.employee_id
    JOIN warehouse_pairs wp ON wp.warehouse_id = a.warehouse_id
    WHERE a.is_primary = TRUE
),

-- Generate 8 rotations × every eligible employee
rotations AS (
    SELECT generate_series(1, 8) AS rot
),

-- Each rotation covers ALL employees but uses a unique date window
-- rot 1 : +30 days after hire, 60-day stint
-- rot 2 : +120 days         , 45-day stint  (50 % subset: erp % 2 = 0)
-- rot 3 : +200 days         , 30-day stint  (50 % subset: erp % 2 = 1)
-- rot 4 : +300 days         , 60-day stint  (25 % subset: erp % 4 = 0)
-- rot 5 : +400 days         , 45-day stint  (25 % subset: erp % 4 = 1)
-- rot 6 : +500 days         , 30-day stint  (25 % subset: erp % 4 = 2)
-- rot 7 : +600 days         , 60-day stint  (25 % subset: erp % 4 = 3)
-- rot 8 : +700 days         , 45-day stint  (50 % subset: erp % 2 = 0)

temp_raw AS (
    SELECT
        ep.employee_id,
        ep.partner_wh_id                                              AS warehouse_id,
        ep.hire_date
            + (CASE r.rot
                WHEN 1 THEN 30
                WHEN 2 THEN 120
                WHEN 3 THEN 200
                WHEN 4 THEN 300
                WHEN 5 THEN 400
                WHEN 6 THEN 500
                WHEN 7 THEN 600
                WHEN 8 THEN 700
               END)                                                   AS start_date,
        ep.hire_date
            + (CASE r.rot
                WHEN 1 THEN 30  + 60
                WHEN 2 THEN 120 + 45
                WHEN 3 THEN 200 + 30
                WHEN 4 THEN 300 + 60
                WHEN 5 THEN 400 + 45
                WHEN 6 THEN 500 + 30
                WHEN 7 THEN 600 + 60
                WHEN 8 THEN 700 + 45
               END)                                                   AS raw_end_date,
        ep.term_date,
        ep.ern,
        r.rot
    FROM emp_primary ep
    CROSS JOIN rotations r
    WHERE
        -- Subset rules per rotation (keeps distinct subsets & total rows high)
        CASE r.rot
            WHEN 1 THEN TRUE                     -- 100 % : 2 000 rows
            WHEN 2 THEN ep.ern % 2 = 0           --  50 % : 1 000 rows
            WHEN 3 THEN ep.ern % 2 = 1           --  50 % : 1 000 rows
            WHEN 4 THEN ep.ern % 4 = 0           --  25 % :   500 rows
            WHEN 5 THEN ep.ern % 4 = 1           --  25 % :   500 rows
            WHEN 6 THEN ep.ern % 4 = 2           --  25 % :   500 rows
            WHEN 7 THEN ep.ern % 4 = 3           --  25 % :   500 rows
            WHEN 8 THEN ep.ern % 3 = 0           --  33 % :   666 rows
            ELSE FALSE
        END
)

SELECT
    employee_id,
    warehouse_id,
    start_date,
    -- Cap end_date at termination date (or leave open if still active & rot≥4)
    CASE
        WHEN term_date IS NOT NULL AND raw_end_date > term_date
            THEN term_date
        WHEN term_date IS NULL AND rot >= 6
            THEN NULL          -- some current employees have open-ended temps
        ELSE raw_end_date
    END                                         AS end_date,
    FALSE                                       AS is_primary,
    'Temporary assignment – rotation ' || rot   AS notes,
    CURRENT_TIMESTAMP                           AS created_at,
    CURRENT_TIMESTAMP                           AS updated_at
FROM temp_raw
WHERE
    -- Exclude rows where the temp assignment starts after termination
    (term_date IS NULL OR start_date <= term_date)
    -- Exclude rows where calculated start_date is in the future
    AND start_date <= CURRENT_DATE
    -- Exclude rows with nonsensical very-short stints
    AND (
            term_date IS NULL
            OR (term_date - start_date) >= 7
        )
ON CONFLICT (employee_id, warehouse_id, start_date) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. HISTORICAL ASSIGNMENTS FOR TERMINATED EMPLOYEES
--
--    Terminated employees (terminated_at IS NOT NULL) get 1-3 additional
--    historical rows representing assignments at OTHER warehouses they
--    worked at BEFORE their current primary warehouse.
--
--    To reach ~1 M rows total we generate many historical rows by
--    crossing terminated employees with:
--      • both warehouses in their city (primary + partner)
--      • warehouses in two other random-but-deterministic cities
--    producing up to 6 extra rows per terminated employee.
--
--    Date windows are kept strictly before the primary assignment start.
-- ---------------------------------------------------------------------------

INSERT INTO EMPLOYEE_WAREHOUSE_ASSIGNMENTS
    (employee_id, warehouse_id, start_date, end_date, is_primary, notes, created_at, updated_at)

WITH

-- Terminated employees with their primary assignment start date
terminated AS (
    SELECT
        e.id                            AS employee_id,
        e.hired_at::date                AS hired_at,
        e.terminated_at::date           AS terminated_at,
        a.warehouse_id                  AS primary_wh_id,
        a.start_date                    AS primary_start,
        ROW_NUMBER() OVER (ORDER BY e.id) AS rn
    FROM EMPLOYEES e
    JOIN EMPLOYEE_WAREHOUSE_ASSIGNMENTS a
      ON a.employee_id = e.id AND a.is_primary = TRUE
    WHERE e.terminated_at IS NOT NULL
),

-- All warehouses with a row-number for deterministic cycling
all_wh AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS wrn
    FROM WAREHOUSES
),

-- Produce up to 6 historical warehouse slots per terminated employee
-- by cycling through warehouses using modular offsets
historical_candidates AS (
    SELECT
        t.employee_id,
        t.hired_at,
        t.primary_start,
        t.terminated_at,
        t.rn,
        w.id   AS hist_warehouse_id,
        slot.s AS slot_num
    FROM terminated t
    CROSS JOIN LATERAL (
        SELECT s FROM generate_series(1, 6) gs(s)
    ) slot
    JOIN all_wh w
      ON w.wrn = ((t.rn + slot.s * 3 - 1) % 16) + 1
    WHERE w.id <> t.primary_wh_id
),

-- Build date windows that fit strictly BEFORE primary assignment start
-- We carve the period [hired_at, primary_start - 1] into up to 6 slices
-- Each slot gets a ~90-day window; we skip slots that don't fit
historical_dated AS (
    SELECT
        employee_id,
        hist_warehouse_id                                   AS warehouse_id,
        -- Start: hired_at + (slot-1)*100 days
        hired_at + ((slot_num - 1) * 100)                  AS h_start,
        -- End: h_start + 89 days, capped one day before primary_start
        LEAST(
            hired_at + ((slot_num - 1) * 100) + 89,
            primary_start - 1
        )                                                   AS h_end,
        primary_start,
        slot_num
    FROM historical_candidates
    WHERE
        -- Only generate this slot if the window actually fits
        hired_at + ((slot_num - 1) * 100) < primary_start - 7
)

SELECT
    employee_id,
    warehouse_id,
    h_start                                         AS start_date,
    h_end                                           AS end_date,
    FALSE                                           AS is_primary,
    'Historical pre-primary assignment (slot ' || slot_num || ')' AS notes,
    CURRENT_TIMESTAMP                               AS created_at,
    CURRENT_TIMESTAMP                               AS updated_at
FROM historical_dated
WHERE
    h_end >= h_start          -- sanity: end must not precede start
    AND h_start >= '2010-01-01'::date
ON CONFLICT (employee_id, warehouse_id, start_date) DO NOTHING;

COMMIT;

-- ---------------------------------------------------------------------------
-- SANITY CHECK
-- ---------------------------------------------------------------------------

SELECT
    'Total rows'                                        AS label,
    COUNT(*)                                            AS cnt
FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS

UNION ALL

SELECT 'Primary assignments',
       COUNT(*) FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS WHERE is_primary = TRUE

UNION ALL

SELECT 'Temporary (secondary) assignments',
       COUNT(*) FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS WHERE is_primary = FALSE

UNION ALL

SELECT 'Distinct employees covered',
       COUNT(DISTINCT employee_id) FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS

UNION ALL

SELECT 'Avg assignments per employee',
       ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT employee_id), 0), 1)
FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS

ORDER BY label;
