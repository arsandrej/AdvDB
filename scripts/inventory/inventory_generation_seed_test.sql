SET client_min_messages = warning;

-- =========================================================
-- 1) Helpers
-- =========================================================

CREATE OR REPLACE FUNCTION random_int(min_val INT, max_val INT)
    RETURNS INT
    LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN floor(random() * (max_val - min_val + 1) + min_val)::INT;
END;
$$;

CREATE OR REPLACE FUNCTION random_timestamp_between(p_start DATE, p_end DATE)
    RETURNS TIMESTAMP
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_seconds NUMERIC;
BEGIN
    v_seconds := EXTRACT(EPOCH FROM ((p_end + 1) - p_start));
    RETURN p_start::timestamp + (random() * v_seconds) * INTERVAL '1 second';
END;
$$;

CREATE OR REPLACE FUNCTION get_random_employee_for_role(
    p_role_id BIGINT,
    p_time TIMESTAMP
)
    RETURNS BIGINT
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_employee_id BIGINT;
BEGIN
    SELECT e.id
    INTO v_employee_id
    FROM employees e
             JOIN roles_employees re
                  ON re.employees_id = e.id
    WHERE re.roles_id = p_role_id
      AND e.hired_at <= p_time
      AND (e.terminated_at IS NULL OR e.terminated_at >= p_time)
    ORDER BY random()
    LIMIT 1;

    RETURN v_employee_id;
END;
$$;

CREATE OR REPLACE FUNCTION get_available_stock(p_variant BIGINT, p_bin BIGINT)
    RETURNS INT
    LANGUAGE plpgsql
AS
$$
DECLARE
    v INT;
BEGIN
    SELECT quantity
    INTO v
    FROM inventory
    WHERE product_variant_id = p_variant
      AND bin_id = p_bin
        FOR UPDATE;

    RETURN COALESCE(v, 0);
END;
$$;

-- =========================================================
-- 2) Inventory movement trigger
-- =========================================================

CREATE OR REPLACE FUNCTION trg_movement_maintain_inventory()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF NEW.from_bin_id IS NOT NULL THEN
        UPDATE inventory
        SET quantity   = quantity - NEW.quantity,
            updated_at = NEW.created_at
        WHERE product_variant_id = NEW.product_variant_id
          AND bin_id = NEW.from_bin_id;
    END IF;

    IF NEW.to_bin_id IS NOT NULL THEN
        INSERT INTO inventory (product_variant_id,
                               bin_id,
                               quantity,
                               reserved_quantity,
                               updated_at,
                               status)
        VALUES (NEW.product_variant_id,
                NEW.to_bin_id,
                NEW.quantity,
                0,
                NEW.created_at,
                'ACTIVE')
        ON CONFLICT (product_variant_id, bin_id)
            DO UPDATE SET quantity   = inventory.quantity + NEW.quantity,
                          updated_at = NEW.created_at;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_movements_after_insert ON inventory_movements;

CREATE TRIGGER trg_inventory_movements_after_insert
    AFTER INSERT
    ON inventory_movements
    FOR EACH ROW
EXECUTE FUNCTION trg_movement_maintain_inventory();

-- =========================================================
-- 3) Seed inventory if missing
--    One starting row per product variant if it has none yet
-- =========================================================

CREATE OR REPLACE PROCEDURE initialize_inventory_safe()
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_var BIGINT;
    v_bin BIGINT;
    v_cnt INT;
BEGIN
    FOR v_var IN
        SELECT id FROM product_variants ORDER BY id
        LOOP
            SELECT COUNT(*)
            INTO v_cnt
            FROM inventory
            WHERE product_variant_id = v_var;

            IF v_cnt = 0 THEN
                SELECT id
                INTO v_bin
                FROM bins
                ORDER BY random()
                LIMIT 1;

                INSERT INTO inventory (product_variant_id,
                                       bin_id,
                                       quantity,
                                       reserved_quantity,
                                       status)
                VALUES (v_var,
                        v_bin,
                        random_int(500, 2000),
                        0,
                        'ACTIVE');
            END IF;
        END LOOP;
END;
$$;

-- =========================================================
-- 4) Transaction builder
--    - created_by_employee must be role 5
--    - packed_by must be role 4
--    - accepted_by must be role 12
--    - all must be active at p_time
-- =========================================================

CREATE OR REPLACE FUNCTION create_inventory_transaction_safe(
    p_type TEXT,
    p_time TIMESTAMP,
    p_movements JSONB
)
    RETURNS BIGINT
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_txn         BIGINT;
    v_m           JSONB;
    v_var         BIGINT;
    v_from        BIGINT;
    v_to          BIGINT;
    v_qty         INT;
    v_avail       INT;
    v_created_by  BIGINT;
    v_packed_by   BIGINT;
    v_accepted_by BIGINT;
    v_note        TEXT;
    v_supplier    TEXT;
    v_destination TEXT;
BEGIN
    v_created_by := get_random_employee_for_role(5, p_time);
    v_packed_by := get_random_employee_for_role(4, p_time);
    v_accepted_by := get_random_employee_for_role(12, p_time);

    IF v_created_by IS NULL OR v_packed_by IS NULL OR v_accepted_by IS NULL THEN
        RETURN NULL;
    END IF;

    v_note := format('Auto-generated %s transaction at %s', p_type, to_char(p_time, 'YYYY-MM-DD HH24:MI:SS'));

    INSERT INTO inventory_transactions (transaction_type,
                                        created_by_employee,
                                        notes,
                                        created_at,
                                        last_updated_by,
                                        accepted_by,
                                        packed_by)
    VALUES (p_type,
            v_created_by,
            v_note,
            p_time,
            v_created_by,
            v_accepted_by,
            v_packed_by)
    RETURNING id INTO v_txn;

    FOR v_m IN
        SELECT * FROM jsonb_array_elements(p_movements)
        LOOP
            v_var := (v_m ->> 'product_variant_id')::BIGINT;
            v_from := NULLIF(v_m ->> 'from_bin_id', '')::BIGINT;
            v_to := NULLIF(v_m ->> 'to_bin_id', '')::BIGINT;
            v_qty := (v_m ->> 'quantity')::INT;

            IF v_from IS NOT NULL THEN
                v_avail := get_available_stock(v_var, v_from);

                IF v_avail <= 0 THEN
                    RAISE EXCEPTION 'Insufficient stock for variant %, bin % at %', v_var, v_from, p_time;
                END IF;

                v_qty := LEAST(v_qty, v_avail);
            END IF;

            INSERT INTO inventory_movements (product_variant_id,
                                             from_bin_id,
                                             to_bin_id,
                                             quantity,
                                             created_at,
                                             inventory_transactions_id)
            VALUES (v_var,
                    v_from,
                    v_to,
                    v_qty,
                    p_time,
                    v_txn);
        END LOOP;

    IF p_type = 'RECEIPT' THEN
        v_supplier := (ARRAY [
            'Acme Logistics',
            'Northwind Supply',
            'BlueRiver Trading',
            'Continental Freight',
            'Evergreen Wholesale'
            ])[random_int(1, 5)];

        INSERT INTO delivery_transactions (inventory_transactions_id,
                                           delivery_note,
                                           supplier_company)
        VALUES (v_txn,
                v_note,
                v_supplier);

    ELSIF p_type = 'SHIPMENT' THEN
        v_destination := (ARRAY [
            'Skopje Central',
            'Belgrade North Hub',
            'Sofia Distribution Center',
            'Vienna Freight Terminal',
            'Zagreb Logistics Park'
            ])[random_int(1, 5)];

        INSERT INTO shipment_transactions (inventory_transactions_id,
                                           shipment_number,
                                           destination_adress)
        VALUES (v_txn,
                v_txn,
                v_destination);
    END IF;

    RETURN v_txn;
END;
$$;

-- =========================================================
-- 5) Main generator
--    Generates exactly target successful inventory movements
-- =========================================================

CREATE OR REPLACE PROCEDURE generate_inventory_history(
    start_date DATE,
    end_date DATE,
    min_movements BIGINT DEFAULT 10000000,
    max_movements BIGINT DEFAULT 30000000
)
    LANGUAGE plpgsql
AS
$$
DECLARE
    target           BIGINT;
    total            BIGINT := 0;
    v_time           TIMESTAMP;
    v_type           TEXT;
    v_r              DOUBLE PRECISION;
    v_txn            BIGINT;
    v_var            BIGINT;
    v_from           BIGINT;
    v_to             BIGINT;
    v_qty            INT;
    v_avail          INT;
    v_bins_count     INT;
    v_variants_count INT;
    v_pick_attempts  INT;
BEGIN
    IF min_movements > max_movements THEN
        RAISE EXCEPTION 'min_movements must be <= max_movements';
    END IF;

    PERFORM setseed(0.42);
    target := random_int(min_movements::INT, max_movements::INT);

    SELECT COUNT(*) INTO v_bins_count FROM bins;
    SELECT COUNT(*) INTO v_variants_count FROM product_variants;

    IF v_bins_count < 2 THEN
        RAISE EXCEPTION 'At least 2 bins are required';
    END IF;

    IF v_variants_count = 0 THEN
        RAISE EXCEPTION 'No product_variants found';
    END IF;

    RAISE NOTICE 'Target movements: %', target;

    WHILE total < target
        LOOP
            v_time := random_timestamp_between(start_date, end_date);
            v_r := random();

            IF v_r < 0.45 THEN
                v_type := 'RECEIPT';
            ELSIF v_r < 0.70 THEN
                v_type := 'SHIPMENT';
            ELSE
                v_type := 'TRANSFER';
            END IF;

            IF v_type = 'RECEIPT' THEN
                SELECT id
                INTO v_var
                FROM product_variants
                ORDER BY random()
                LIMIT 1;

                SELECT id
                INTO v_to
                FROM bins
                ORDER BY random()
                LIMIT 1;

                v_qty := random_int(10, 500);

                SELECT create_inventory_transaction_safe(
                               'RECEIPT',
                               v_time,
                               jsonb_build_array(
                                       jsonb_build_object(
                                               'product_variant_id', v_var,
                                               'from_bin_id', NULL,
                                               'to_bin_id', v_to,
                                               'quantity', v_qty
                                       )
                               )
                       )
                INTO v_txn;

            ELSE
                SELECT product_variant_id, bin_id, quantity
                INTO v_var, v_from, v_avail
                FROM inventory
                WHERE quantity > 0
                ORDER BY random()
                LIMIT 1;

                IF NOT FOUND THEN
                    CONTINUE;
                END IF;

                v_qty := LEAST(random_int(1, 300), v_avail);

                IF v_type = 'SHIPMENT' THEN
                    SELECT create_inventory_transaction_safe(
                                   'SHIPMENT',
                                   v_time,
                                   jsonb_build_array(
                                           jsonb_build_object(
                                                   'product_variant_id', v_var,
                                                   'from_bin_id', v_from,
                                                   'to_bin_id', NULL,
                                                   'quantity', v_qty
                                           )
                                   )
                           )
                    INTO v_txn;

                ELSE
                    v_pick_attempts := 0;
                    LOOP
                        v_pick_attempts := v_pick_attempts + 1;

                        SELECT id
                        INTO v_to
                        FROM bins
                        ORDER BY random()
                        LIMIT 1;

                        EXIT WHEN v_to IS NOT NULL AND v_to <> v_from;

                        IF v_pick_attempts > 20 THEN
                            v_txn := NULL;
                            EXIT;
                        END IF;
                    END LOOP;

                    IF v_txn IS NULL AND v_pick_attempts > 20 THEN
                        CONTINUE;
                    END IF;

                    SELECT create_inventory_transaction_safe(
                                   'TRANSFER',
                                   v_time,
                                   jsonb_build_array(
                                           jsonb_build_object(
                                                   'product_variant_id', v_var,
                                                   'from_bin_id', v_from,
                                                   'to_bin_id', v_to,
                                                   'quantity', v_qty
                                           )
                                   )
                           )
                    INTO v_txn;
                END IF;
            END IF;

            IF v_txn IS NOT NULL THEN
                total := total + 1;
            END IF;

            IF total > 0 AND total % 50000 = 0 THEN
                COMMIT;
                RAISE NOTICE 'Progress: % / %', total, target;
            END IF;
        END LOOP;

    COMMIT;
    RAISE NOTICE 'DONE. Total movements: %', total;
END;
$$;

-- =========================================================
-- 6) Validation
-- =========================================================

CREATE OR REPLACE PROCEDURE validate_transaction_employee_roles()
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_bad BIGINT;
BEGIN
    SELECT COUNT(*)
    INTO v_bad
    FROM inventory_transactions t
    WHERE NOT EXISTS (SELECT 1
                      FROM employees e
                               JOIN roles_employees re
                                    ON re.employees_id = e.id
                                        AND re.roles_id = 5
                      WHERE e.id = t.created_by_employee
                        AND e.hired_at <= t.created_at
                        AND (e.terminated_at IS NULL OR e.terminated_at >= t.created_at))
       OR NOT EXISTS (SELECT 1
                      FROM employees e
                               JOIN roles_employees re
                                    ON re.employees_id = e.id
                                        AND re.roles_id = 4
                      WHERE e.id = t.packed_by
                        AND e.hired_at <= t.created_at
                        AND (e.terminated_at IS NULL OR e.terminated_at >= t.created_at))
       OR NOT EXISTS (SELECT 1
                      FROM employees e
                               JOIN roles_employees re
                                    ON re.employees_id = e.id
                                        AND re.roles_id = 12
                      WHERE e.id = t.accepted_by
                        AND e.hired_at <= t.created_at
                        AND (e.terminated_at IS NULL OR e.terminated_at >= t.created_at))
       OR (
        t.transaction_type = 'RECEIPT'
            AND NOT EXISTS (SELECT 1
                            FROM delivery_transactions d
                            WHERE d.inventory_transactions_id = t.id)
        )
       OR (
        t.transaction_type = 'SHIPMENT'
            AND NOT EXISTS (SELECT 1
                            FROM shipment_transactions s
                            WHERE s.inventory_transactions_id = t.id)
        );

    IF v_bad = 0 THEN
        RAISE NOTICE 'TRANSACTION EMPLOYEE ROLE VALIDATION PASSED';
    ELSE
        RAISE WARNING 'TRANSACTION EMPLOYEE ROLE VALIDATION FAILED: % invalid rows', v_bad;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE validate_inventory_consistency()
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_bad BIGINT;
BEGIN
    WITH net AS (SELECT product_variant_id, bin_id, SUM(qty) AS q
                 FROM (SELECT product_variant_id, to_bin_id AS bin_id, quantity AS qty
                       FROM inventory_movements
                       WHERE to_bin_id IS NOT NULL

                       UNION ALL

                       SELECT product_variant_id, from_bin_id AS bin_id, -quantity AS qty
                       FROM inventory_movements
                       WHERE from_bin_id IS NOT NULL) x
                 GROUP BY product_variant_id, bin_id)
    SELECT COUNT(*)
    INTO v_bad
    FROM net n
             JOIN inventory i
                  ON i.product_variant_id = n.product_variant_id
                      AND i.bin_id = n.bin_id
    WHERE i.quantity < n.q;

    IF v_bad = 0 THEN
        RAISE NOTICE 'INVENTORY CONSISTENCY VALIDATION PASSED';
    ELSE
        RAISE WARNING 'INVENTORY CONSISTENCY VALIDATION FAILED: % issues', v_bad;
    END IF;
END;
$$;

-- =========================================================
-- 7) Run
-- =========================================================

CALL initialize_inventory_safe();

CALL generate_inventory_history(
        '2022-01-01',
        '2023-12-31',
        10000000,
        30000000
     );

CALL validate_transaction_employee_roles();
CALL validate_inventory_consistency();