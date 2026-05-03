sql
-- =============================================================================
-- FINAL INVENTORY GENERATOR (SAFE + REALISTIC + CONTROLLED VOLUME)
-- =============================================================================

SET client_min_messages = warning;

-- =============================================================================
-- 1. Helpers
-- =============================================================================

CREATE OR REPLACE FUNCTION random_int(min_val INT, max_val INT)
RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
    RETURN floor(random() * (max_val - min_val + 1) + min_val);
END;
$$;

-- =============================================================================
-- 2. Trigger (same as before)
-- =============================================================================

CREATE OR REPLACE FUNCTION trg_movement_maintain_inventory()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.from_bin_id IS NOT NULL THEN
        UPDATE inventory
        SET quantity = quantity - NEW.quantity,
            updated_at = NEW.created_at
        WHERE product_variant_id = NEW.product_variant_id
          AND bin_id = NEW.from_bin_id;
    END IF;

    IF NEW.to_bin_id IS NOT NULL THEN
        INSERT INTO inventory (product_variant_id, bin_id, quantity, reserved_quantity, updated_at, status)
        VALUES (NEW.product_variant_id, NEW.to_bin_id, NEW.quantity, 0, NEW.created_at, 'ACTIVE')
        ON CONFLICT (product_variant_id, bin_id)
        DO UPDATE SET
            quantity = inventory.quantity + NEW.quantity,
            updated_at = NEW.created_at;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_movements_after_insert ON inventory_movements;

CREATE TRIGGER trg_inventory_movements_after_insert
AFTER INSERT ON inventory_movements
FOR EACH ROW
EXECUTE FUNCTION trg_movement_maintain_inventory();

-- =============================================================================
-- 3. Safe stock checker
-- =============================================================================

CREATE OR REPLACE FUNCTION get_available_stock(p_variant BIGINT, p_bin BIGINT)
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE v INT;
BEGIN
    SELECT quantity INTO v
    FROM inventory
    WHERE product_variant_id = p_variant
      AND bin_id = p_bin
    FOR UPDATE;

    RETURN COALESCE(v, 0);
END;
$$;

-- =============================================================================
-- 4. Transaction builder (SAFE)
-- =============================================================================

CREATE OR REPLACE FUNCTION create_inventory_transaction_safe(
    p_type TEXT,
    p_employee BIGINT,
    p_time TIMESTAMP,
    p_movements JSONB
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_txn BIGINT;
    v_m JSONB;
    v_var BIGINT;
    v_from BIGINT;
    v_to BIGINT;
    v_qty INT;
    v_avail INT;
BEGIN
    INSERT INTO inventory_transactions (transaction_type, created_by_employee, created_at)
    VALUES (p_type, p_employee, p_time)
    RETURNING id INTO v_txn;

    FOR v_m IN SELECT * FROM jsonb_array_elements(p_movements)
    LOOP
        v_var := (v_m->>'product_variant_id')::BIGINT;
        v_from := NULLIF(v_m->>'from_bin_id','')::BIGINT;
        v_to := NULLIF(v_m->>'to_bin_id','')::BIGINT;
        v_qty := (v_m->>'quantity')::INT;

        IF v_from IS NOT NULL THEN
            v_avail := get_available_stock(v_var, v_from);
            IF v_avail <= 0 THEN CONTINUE; END IF;
            v_qty := LEAST(v_qty, v_avail);
        END IF;

        INSERT INTO inventory_movements(
            product_variant_id,
            from_bin_id,
            to_bin_id,
            quantity,
            created_at,
            inventory_transactions_id
        )
        VALUES (v_var, v_from, v_to, v_qty, p_time, v_txn);
    END LOOP;

    RETURN v_txn;
END;
$$;

-- =============================================================================
-- 5. Initialization
-- =============================================================================

CREATE OR REPLACE PROCEDURE initialize_inventory_safe()
LANGUAGE plpgsql
AS $$
DECLARE
    v_var BIGINT;
    v_bin BIGINT;
BEGIN
    FOR v_var IN SELECT id FROM product_variants LOOP
        SELECT id INTO v_bin FROM bins ORDER BY random() LIMIT 1;

        INSERT INTO inventory(product_variant_id, bin_id, quantity, reserved_quantity, status)
        VALUES (v_var, v_bin, random_int(500,2000), 0, 'ACTIVE')
        ON CONFLICT (product_variant_id, bin_id)
        DO UPDATE SET quantity = inventory.quantity + EXCLUDED.quantity;
    END LOOP;

    COMMIT;
END;
$$;

-- =============================================================================
-- 6. MAIN GENERATOR
-- =============================================================================

CREATE OR REPLACE PROCEDURE generate_inventory_history(
    start_date DATE,
    end_date DATE,
    min_movements BIGINT DEFAULT 10000000,
    max_movements BIGINT DEFAULT 30000000
)
LANGUAGE plpgsql
AS $$
DECLARE
    total BIGINT := 0;
    target BIGINT;
    cur_date DATE;

    emp_ids BIGINT[];
    variants BIGINT[];
    bins BIGINT[];

    v_emp BIGINT;
    v_var BIGINT;
    v_from BIGINT;
    v_to BIGINT;
    v_qty INT;
    v_avail INT;

    receipts INT;
    shipments INT;
    transfers INT;
BEGIN
    PERFORM setseed(0.42);

    target := random_int(min_movements::INT, max_movements::INT);

    RAISE NOTICE 'Target movements: %', target;

    emp_ids := ARRAY(SELECT DISTINCT employee_id FROM employee_warehouse_assignments WHERE end_date IS NULL);
    variants := ARRAY(SELECT id FROM product_variants);
    bins := ARRAY(SELECT id FROM bins);

    cur_date := start_date;

    WHILE cur_date <= end_date AND total < target LOOP

        receipts := random_int(50,150);
        shipments := random_int(100,300);
        transfers := random_int(100,250);

        -- RECEIPTS
        FOR i IN 1..receipts LOOP
            v_emp := emp_ids[random_int(1,cardinality(emp_ids))];
            v_var := variants[random_int(1,cardinality(variants))];
            v_to := bins[random_int(1,cardinality(bins))];
            v_qty := random_int(10,500);

            PERFORM create_inventory_transaction_safe(
                'RECEIPT',
                v_emp,
                cur_date + random()*interval '1 day',
                jsonb_build_array(jsonb_build_object(
                    'product_variant_id', v_var,
                    'from_bin_id', NULL,
                    'to_bin_id', v_to,
                    'quantity', v_qty
                ))
            );

            total := total + 1;
        END LOOP;

        -- SHIPMENTS
        FOR i IN 1..shipments LOOP
            v_emp := emp_ids[random_int(1,cardinality(emp_ids))];
            v_var := variants[random_int(1,cardinality(variants))];

            SELECT bin_id, quantity INTO v_from, v_avail
            FROM inventory
            WHERE product_variant_id = v_var AND quantity > 0
            ORDER BY random() LIMIT 1;

            IF FOUND THEN
                v_qty := LEAST(random_int(1,300), v_avail);

                PERFORM create_inventory_transaction_safe(
                    'SHIPMENT',
                    v_emp,
                    cur_date + random()*interval '1 day',
                    jsonb_build_array(jsonb_build_object(
                        'product_variant_id', v_var,
                        'from_bin_id', v_from,
                        'to_bin_id', NULL,
                        'quantity', v_qty
                    ))
                );

                total := total + 1;
            END IF;
        END LOOP;

        -- TRANSFERS
        FOR i IN 1..transfers LOOP
            v_emp := emp_ids[random_int(1,cardinality(emp_ids))];
            v_var := variants[random_int(1,cardinality(variants))];

            SELECT bin_id, quantity INTO v_from, v_avail
            FROM inventory
            WHERE product_variant_id = v_var AND quantity > 0
            ORDER BY random() LIMIT 1;

            IF FOUND THEN
                LOOP
                    v_to := bins[random_int(1,cardinality(bins))];
                    EXIT WHEN v_to <> v_from;
                END LOOP;

                v_qty := LEAST(random_int(1,300), v_avail);

                PERFORM create_inventory_transaction_safe(
                    'TRANSFER',
                    v_emp,
                    cur_date + random()*interval '1 day',
                    jsonb_build_array(jsonb_build_object(
                        'product_variant_id', v_var,
                        'from_bin_id', v_from,
                        'to_bin_id', v_to,
                        'quantity', v_qty
                    ))
                );

                total := total + 1;
            END IF;
        END LOOP;

        IF total % 50000 = 0 THEN
            COMMIT;
            RAISE NOTICE 'Progress: % / %', total, target;
        END IF;

        cur_date := cur_date + 1;
    END LOOP;

    COMMIT;
    RAISE NOTICE 'DONE. Total movements: %', total;
END;
$$;

-- =============================================================================
-- 7. VALIDATION
-- =============================================================================

CREATE OR REPLACE PROCEDURE validate_inventory_consistency()
LANGUAGE plpgsql
AS $$
DECLARE v INT;
BEGIN
    WITH net AS (
        SELECT product_variant_id, bin_id, SUM(qty) AS q
        FROM (
            SELECT product_variant_id, to_bin_id AS bin_id, quantity AS qty FROM inventory_movements WHERE to_bin_id IS NOT NULL
            UNION ALL
            SELECT product_variant_id, from_bin_id AS bin_id, -quantity FROM inventory_movements WHERE from_bin_id IS NOT NULL
        ) x
        GROUP BY product_variant_id, bin_id
    )
    SELECT COUNT(*) INTO v
    FROM net n
    JOIN inventory i USING(product_variant_id, bin_id)
    WHERE i.quantity < n.q;

    IF v = 0 THEN
        RAISE NOTICE 'VALIDATION PASSED';
    ELSE
        RAISE WARNING 'VALIDATION FAILED: % issues', v;
    END IF;
END;
$$;

-- =============================================================================
-- 8. RUN
-- =============================================================================

DO $$
BEGIN
    CALL initialize_inventory_safe();

    CALL generate_inventory_history('2022-01-01','2023-12-31',10000000,30000000);

    CALL validate_inventory_consistency();
END;
$$;

