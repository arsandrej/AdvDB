-- =============================================================================
-- SAFE BACKFILL FOR accepted_by, packed_by, last_updated_by
-- =============================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 2. CREATE COVERAGE EMPLOYEES (ONE ACCEPTED + ONE PACKED PER WAREHOUSE)
--    Using DYNAMIC date range from actual transaction data.
-- -------------------------------------------------------------------------
DO
$$
    DECLARE
        wh               RECORD;
        accepted_role_id INT;
        packed_role_id   INT;
        emp_id           BIGINT;
        min_date         DATE;
        max_date         DATE;
        hire_date        DATE;
        end_date         DATE;
        emp_counter      INT    := 0;
        first_names      TEXT[] := ARRAY ['James','Mary','John','Patricia','Robert','Jennifer','Michael','Linda','William','Elizabeth','David','Susan','Joseph','Jessica','Thomas','Sarah','Charles','Karen','Christopher','Nancy','Daniel','Lisa','Matthew','Betty','Anthony','Helen','Donald','Sandra','Mark','Donna','Paul','Carol','Steven','Ruth','Andrew','Sharon','Kenneth','Michelle','George','Laura','Joshua','Emily','Kevin','Deborah','Brian','Amanda','Edward','Melissa'];
        last_names       TEXT[] := ARRAY ['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson','White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson','Walker','Young','Allen','King','Wright','Scott','Torres','Nguyen','Hill','Flores','Green','Adams','Nelson','Baker','Hall','Rivera','Campbell','Mitchell','Carter','Roberts'];
        rand_first       TEXT;
        rand_last        TEXT;
        emp_number       TEXT;
        emp_email        TEXT;
    BEGIN
        -- Get role IDs
        SELECT id
        INTO accepted_role_id
        FROM ROLES
        WHERE name IN ('Warehouse Manager', 'Operations Supervisor', 'Admin')
        ORDER BY id
        LIMIT 1;
        SELECT id
        INTO packed_role_id
        FROM ROLES
        WHERE name IN ('Forklift Operator', 'Shipping Coordinator', 'Receiving Clerk', 'Inventory Analyst')
        ORDER BY id
        LIMIT 1;

        IF accepted_role_id IS NULL OR packed_role_id IS NULL THEN
            RAISE EXCEPTION 'Required roles missing. Please insert at least one accepted role and one packed role into ROLES table.';
        END IF;

        -- Dynamic date range from actual transactions
        SELECT MIN(created_at), MAX(created_at) INTO min_date, max_date FROM INVENTORY_TRANSACTIONS;
        IF min_date IS NULL THEN
            RAISE EXCEPTION 'No transactions found – nothing to backfill.';
        END IF;
        hire_date := min_date - 1; -- start one day before earliest transaction
        end_date := max_date + 1;
        -- end one day after latest transaction

        -- Get current max employee number with 'BF' prefix
        SELECT COALESCE(MAX(CAST(SUBSTRING(employee_number FROM '^BF([0-9]+)$') AS INTEGER)), 0)
        INTO emp_counter
        FROM EMPLOYEES
        WHERE employee_number LIKE 'BF%';

        FOR wh IN SELECT id FROM WAREHOUSES
            LOOP
                -- ----- Accepted employee -----
                emp_counter := emp_counter + 1;
                rand_first := first_names[1 + floor(random() * array_length(first_names, 1))];
                rand_last := last_names[1 + floor(random() * array_length(last_names, 1))];
                emp_number := 'BF' || LPAD(emp_counter::TEXT, 8, '0');
                emp_email := LOWER(rand_first) || '.' || LOWER(rand_last) || '.' || emp_counter || '@backfill.com';

                INSERT INTO EMPLOYEES (employee_number, first_name, last_name, email, phone, job_title,
                                       employment_status, hired_at, terminated_at, created_at, updated_at)
                VALUES (emp_number, rand_first, rand_last, emp_email, '000-000-0000', 'Warehouse Manager', 'active',
                        hire_date, NULL, hire_date, hire_date)
                RETURNING id INTO emp_id;

                INSERT INTO ROLES_EMPLOYEES (roles_id, employees_id) VALUES (accepted_role_id, emp_id);
                INSERT INTO EMPLOYEE_WAREHOUSE_ASSIGNMENTS (employee_id, warehouse_id, start_date, end_date, is_primary, notes)
                VALUES (emp_id, wh.id, hire_date, end_date, TRUE, 'Guaranteed coverage for accepted_by');

                -- ----- Packed employee -----
                emp_counter := emp_counter + 1;
                rand_first := first_names[1 + floor(random() * array_length(first_names, 1))];
                rand_last := last_names[1 + floor(random() * array_length(last_names, 1))];
                emp_number := 'BF' || LPAD(emp_counter::TEXT, 8, '0');
                emp_email := LOWER(rand_first) || '.' || LOWER(rand_last) || '.' || emp_counter || '@backfill.com';

                INSERT INTO EMPLOYEES (employee_number, first_name, last_name, email, phone, job_title,
                                       employment_status, hired_at, terminated_at, created_at, updated_at)
                VALUES (emp_number, rand_first, rand_last, emp_email, '000-000-0001', 'Forklift Operator', 'active',
                        hire_date, NULL, hire_date, hire_date)
                RETURNING id INTO emp_id;

                INSERT INTO ROLES_EMPLOYEES (roles_id, employees_id) VALUES (packed_role_id, emp_id);
                INSERT INTO EMPLOYEE_WAREHOUSE_ASSIGNMENTS (employee_id, warehouse_id, start_date, end_date, is_primary, notes)
                VALUES (emp_id, wh.id, hire_date, end_date, TRUE, 'Guaranteed coverage for packed_by');
            END LOOP;
    END
$$;

-- -------------------------------------------------------------------------
-- 3. BUILD ELIGIBLE EMPLOYEES PER (WAREHOUSE, DATE, ROLE)
-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS eligible_employee_rank;
CREATE TEMP TABLE eligible_employee_rank
(
    warehouse_id     BIGINT,
    transaction_date DATE,
    role_pool        TEXT,
    employee_id      BIGINT,
    rn               INT
);

WITH transaction_dates AS (SELECT DISTINCT created_at::DATE AS dt
                           FROM INVENTORY_TRANSACTIONS),
     accepted_roles AS (SELECT e.id
                        FROM EMPLOYEES e
                                 JOIN ROLES_EMPLOYEES re ON re.employees_id = e.id
                                 JOIN ROLES r ON r.id = re.roles_id
                        WHERE r.name IN ('Warehouse Manager', 'Operations Supervisor', 'Admin')),
     packed_roles AS (SELECT e.id
                      FROM EMPLOYEES e
                               JOIN ROLES_EMPLOYEES re ON re.employees_id = e.id
                               JOIN ROLES r ON r.id = re.roles_id
                      WHERE r.name IN
                            ('Forklift Operator', 'Shipping Coordinator', 'Receiving Clerk', 'Inventory Analyst')),
     assignments AS (SELECT ewa.employee_id,
                            ewa.warehouse_id,
                            ewa.start_date,
                            COALESCE(ewa.end_date, '9999-12-31') AS end_date
                     FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS ewa)
INSERT
INTO eligible_employee_rank
SELECT a.warehouse_id,
       td.dt,
       'accepted',
       a.employee_id,
       ROW_NUMBER() OVER (PARTITION BY a.warehouse_id, td.dt ORDER BY a.employee_id)
FROM assignments a
         JOIN transaction_dates td ON td.dt BETWEEN a.start_date AND a.end_date
WHERE a.employee_id IN (SELECT employee_id FROM accepted_roles)
UNION ALL
SELECT a.warehouse_id,
       td.dt,
       'packed',
       a.employee_id,
       ROW_NUMBER() OVER (PARTITION BY a.warehouse_id, td.dt ORDER BY a.employee_id)
FROM assignments a
         JOIN transaction_dates td ON td.dt BETWEEN a.start_date AND a.end_date
WHERE a.employee_id IN (SELECT employee_id FROM packed_roles);

CREATE INDEX idx_eligible_lookup ON eligible_employee_rank (warehouse_id, transaction_date, role_pool, rn);

-- -------------------------------------------------------------------------
-- 4. MAP EACH TRANSACTION TO A SINGLE WAREHOUSE (WITH PROPER FALLBACK)
-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS transaction_warehouse;
CREATE TEMP TABLE transaction_warehouse
(
    transaction_id   BIGINT PRIMARY KEY,
    warehouse_id     BIGINT,
    transaction_date DATE
);

INSERT INTO transaction_warehouse (transaction_id, warehouse_id, transaction_date)
SELECT it.id,
       COALESCE(
               ( -- Preferred: warehouse from to_bin (most frequent)
                   SELECT w.id
                   FROM INVENTORY_MOVEMENTS im
                            JOIN BINS b ON b.id = im.to_bin_id
                            JOIN LOCATIONS l ON l.id = b.location_id
                            JOIN SECTIONS s ON s.id = l.section_id
                            JOIN WAREHOUSES w ON w.id = s.warehouse_id
                   WHERE im.inventory_transactions_id = it.id
                   GROUP BY w.id
                   ORDER BY COUNT(*) DESC, w.id
                   LIMIT 1),
               ( -- Fallback: warehouse from from_bin (any)
                   SELECT w.id
                   FROM INVENTORY_MOVEMENTS im
                            JOIN BINS b ON b.id = im.from_bin_id
                            JOIN LOCATIONS l ON l.id = b.location_id
                            JOIN SECTIONS s ON s.id = l.section_id
                            JOIN WAREHOUSES w ON w.id = s.warehouse_id
                   WHERE im.inventory_transactions_id = it.id
                   LIMIT 1),
               ( -- Final fallback: first warehouse in system
                   SELECT id
                   FROM WAREHOUSES
                   ORDER BY id
                   LIMIT 1)
       ) AS warehouse_id,
       it.created_at::DATE
FROM INVENTORY_TRANSACTIONS it
WHERE it.accepted_by IS NULL
   OR it.packed_by IS NULL;

-- Additional index for keyset pagination (primary key already indexed)
CREATE INDEX IF NOT EXISTS idx_tw_id ON transaction_warehouse (transaction_id);

-- -------------------------------------------------------------------------
-- 5. UPDATE USING KEYSET PAGINATION (NO OFFSET)
-- -------------------------------------------------------------------------
DO
$$
    DECLARE
        batch_size CONSTANT INT    := 500000;
        last_id             BIGINT := 0;
        rows_updated        INT;
        total_rows          BIGINT;
        batch_num           INT    := 0;
    BEGIN
        SELECT COUNT(*) INTO total_rows FROM transaction_warehouse;
        RAISE NOTICE 'Starting backfill for % transactions', total_rows;

        LOOP
            -- Create a temp table for one batch of IDs
            CREATE TEMP TABLE batch_ids AS
            SELECT transaction_id, warehouse_id, transaction_date
            FROM transaction_warehouse
            WHERE transaction_id > last_id
            ORDER BY transaction_id
            LIMIT batch_size;

            -- Exit if no rows
            GET DIAGNOSTICS rows_updated = ROW_COUNT;
            EXIT WHEN rows_updated = 0;

            -- Perform the update using the temp table
            WITH eligible_counts AS (SELECT b.transaction_id,
                                            (SELECT COUNT(*)
                                             FROM eligible_employee_rank e
                                             WHERE e.warehouse_id = b.warehouse_id
                                               AND e.transaction_date = b.transaction_date
                                               AND e.role_pool = 'accepted') AS accepted_cnt,
                                            (SELECT COUNT(*)
                                             FROM eligible_employee_rank e
                                             WHERE e.warehouse_id = b.warehouse_id
                                               AND e.transaction_date = b.transaction_date
                                               AND e.role_pool = 'packed')   AS packed_cnt
                                     FROM batch_ids b),
                 selected AS (SELECT b.transaction_id,
                                     CASE
                                         WHEN ec.accepted_cnt = 0 THEN NULL
                                         ELSE (SELECT employee_id
                                               FROM eligible_employee_rank e
                                               WHERE e.warehouse_id = b.warehouse_id
                                                 AND e.transaction_date = b.transaction_date
                                                 AND e.role_pool = 'accepted'
                                                 AND e.rn = ((b.transaction_id % ec.accepted_cnt) + 1)
                                               LIMIT 1)
                                         END AS new_accepted_by,
                                     CASE
                                         WHEN ec.packed_cnt = 0 THEN NULL
                                         ELSE (SELECT employee_id
                                               FROM eligible_employee_rank e
                                               WHERE e.warehouse_id = b.warehouse_id
                                                 AND e.transaction_date = b.transaction_date
                                                 AND e.role_pool = 'packed'
                                                 AND e.rn = (((b.transaction_id * 317) % ec.packed_cnt) + 1)
                                               LIMIT 1)
                                         END AS new_packed_by
                              FROM batch_ids b
                                       JOIN eligible_counts ec ON ec.transaction_id = b.transaction_id)
            UPDATE INVENTORY_TRANSACTIONS it
            SET accepted_by     = s.new_accepted_by,
                packed_by       = s.new_packed_by,
                last_updated_by = s.new_accepted_by
            FROM selected s
            WHERE it.id = s.transaction_id;

            -- Get the largest ID from this batch for the next iteration
            SELECT MAX(transaction_id) INTO last_id FROM batch_ids;

            -- Clean up the temp table
            DROP TABLE batch_ids;

            batch_num := batch_num + 1;
            RAISE NOTICE 'Batch % (up to ID %) updated % rows', batch_num, last_id, rows_updated;
        END LOOP;
    END
$$;
-- -------------------------------------------------------------------------
-- 6. VERIFICATION
-- -------------------------------------------------------------------------
SELECT 'Remaining NULL accepted_by' AS metric, COUNT(*)
FROM INVENTORY_TRANSACTIONS
WHERE accepted_by IS NULL
UNION ALL
SELECT 'Remaining NULL packed_by', COUNT(*)
FROM INVENTORY_TRANSACTIONS
WHERE packed_by IS NULL
UNION ALL
SELECT 'Transactions with accepted = packed', COUNT(*)
FROM INVENTORY_TRANSACTIONS
WHERE accepted_by = packed_by
  AND accepted_by IS NOT NULL
UNION ALL
SELECT 'last_updated_by still NULL', COUNT(*)
FROM INVENTORY_TRANSACTIONS
WHERE last_updated_by IS NULL;

COMMIT;