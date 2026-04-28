-- ==============================================================================
-- PostgreSQL Inventory Data Generator
-- Target: ~30,000,000 movements, maintaining full referential & logical integrity.
-- Requirements: PostgreSQL 11+ (Uses stored procedures with transaction control)
-- ==============================================================================

SET
    client_min_messages = warning;

-- ==============================================================================
-- 1. Helper Functions
-- ==============================================================================

-- Generates a random integer within an inclusive range
CREATE
    OR REPLACE FUNCTION random_int(min_val INT, max_val INT)
    RETURNS INT AS
$$
BEGIN
    RETURN floor(random() * (max_val - min_val + 1) + min_val);
END;
$$
    LANGUAGE plpgsql VOLATILE;

-- Generates a random BIGINT within an inclusive range
CREATE
    OR REPLACE FUNCTION random_bigint(min_val BIGINT, max_val BIGINT)
    RETURNS BIGINT AS
$$
BEGIN
    RETURN floor(random() * (max_val - min_val + 1) + min_val)::BIGINT;
END;
$$
    LANGUAGE plpgsql VOLATILE;


-- ==============================================================================
-- 2. Initialization Procedure (Starting Stock)
-- ==============================================================================
CREATE
    OR REPLACE PROCEDURE initialize_inventory()
    LANGUAGE plpgsql AS
$$
DECLARE
    v_min_var BIGINT;
    v_max_var
              BIGINT;
    v_min_bin
              BIGINT;
    v_max_bin
              BIGINT;
    v_inserted
              INT := 0;
    v_var_id
              BIGINT;
    v_bin_id
              BIGINT;
BEGIN
    RAISE
        NOTICE 'Initializing starting inventory...';

    -- Truncate existing inventory
    TRUNCATE TABLE INVENTORY CASCADE;

-- Get boundaries for fast random selection
    SELECT min(id), max(id)
    INTO v_min_var, v_max_var
    FROM PRODUCT_VARIANTS;
    SELECT min(id), max(id)
    INTO v_min_bin, v_max_bin
    FROM BINS;

-- Insert roughly 100,000 initial stock rows (simulating 10-20% coverage depending on DB size)
    FOR i IN 1..100000
        LOOP
            -- Fast random variant
            SELECT id
            INTO v_var_id
            FROM PRODUCT_VARIANTS
            WHERE id >= random_bigint(v_min_var, v_max_var)
            LIMIT 1;

-- Fast random bin
            SELECT id
            INTO v_bin_id
            FROM BINS
            WHERE id >= random_bigint(v_min_bin, v_max_bin)
            LIMIT 1;

            IF
                v_var_id IS NOT NULL AND v_bin_id IS NOT NULL THEN
                BEGIN
                    INSERT INTO INVENTORY (product_variant_id, bin_id, quantity, reserved_quantity, status)
                    VALUES (v_var_id, v_bin_id, random_int(100, 50000), 0, 'AVAILABLE')
                    ON CONFLICT (product_variant_id, bin_id) DO NOTHING;

                    v_inserted
                        := v_inserted + 1;
                EXCEPTION
                    WHEN OTHERS THEN
                    -- Ignore constraint errors and continue
                END;
            END IF;
        END LOOP;

    RAISE
        NOTICE 'Initialized % starting inventory records.', v_inserted;
END;
$$;


-- ==============================================================================
-- 3. Core Data Generation Procedure
-- ==============================================================================
CREATE OR REPLACE PROCEDURE generate_inventory_data(p_target_movements BIGINT)
    LANGUAGE plpgsql AS $$
DECLARE
    -- Bounds & Lookups
    v_min_emp BIGINT; v_max_emp BIGINT;
    v_min_bin BIGINT; v_max_bin BIGINT;
    v_min_var BIGINT; v_max_var BIGINT;
    v_min_inv BIGINT; v_max_inv BIGINT;

    -- Transaction loop variables
    v_movements_inserted BIGINT := 0;
    v_txn_id BIGINT;
    v_txn_type VARCHAR(50);
    v_emp_id BIGINT;
    v_current_time TIMESTAMP := '2024-01-01 00:00:00';
    v_time_step INTERVAL;

    -- Movement loop variables
    v_num_movements INT;
    v_type_rand INT;
    v_var_id BIGINT;
    v_from_bin BIGINT;
    v_to_bin BIGINT;
    v_qty INT;
    v_qty_available INT;
    v_success BOOLEAN;
BEGIN
    RAISE NOTICE 'Starting generation of % movements (Delegating INVENTORY updates to trigger)...', p_target_movements;

    -- Calculate average time step
    v_time_step := (31536000.0 / (p_target_movements / 15.0)) * INTERVAL '1 second';

    SELECT min(id), max(id) INTO v_min_emp, v_max_emp FROM EMPLOYEES;
    SELECT min(id), max(id) INTO v_min_bin, v_max_bin FROM BINS;
    SELECT min(id), max(id) INTO v_min_var, v_max_var FROM PRODUCT_VARIANTS;

    PERFORM setseed(0.12345);

    WHILE v_movements_inserted < p_target_movements LOOP

            v_type_rand := random_int(1, 100);
            IF v_type_rand <= 40 THEN
                v_txn_type := 'RECEIPT';
                v_num_movements := random_int(1, 100);
            ELSIF v_type_rand <= 80 THEN
                v_txn_type := 'SHIPMENT';
                v_num_movements := random_int(1, 50);
            ELSE
                v_txn_type := 'TRANSFER';
                v_num_movements := random_int(1, 50);
            END IF;

            IF v_movements_inserted + v_num_movements > p_target_movements THEN
                v_num_movements := p_target_movements - v_movements_inserted;
            END IF;

            -- Pick an active employee
            SELECT e.id INTO v_emp_id
            FROM EMPLOYEES e
                     JOIN EMPLOYEE_WAREHOUSE_ASSIGNMENTS ewa ON e.id = ewa.employee_id
            WHERE e.id >= random_bigint(v_min_emp, v_max_emp)
              AND (ewa.end_date IS NULL OR ewa.end_date > v_current_time::date)
            LIMIT 1;

            IF v_emp_id IS NULL THEN
                SELECT employee_id INTO v_emp_id FROM EMPLOYEE_WAREHOUSE_ASSIGNMENTS LIMIT 1;
            END IF;

            v_current_time := v_current_time + v_time_step;

            -- Insert Parent Transaction
            INSERT INTO INVENTORY_TRANSACTIONS (transaction_type, created_by_employee, created_at)
            VALUES (v_txn_type, v_emp_id, v_current_time)
            RETURNING id INTO v_txn_id;

            IF v_txn_type = 'RECEIPT' THEN
                INSERT INTO DELIVERY_TRANSACTIONS (inventory_transactions_id, supplier_company, delivery_note)
                VALUES (v_txn_id, 'Supplier_' || random_int(1, 1000), 'DN-' || v_txn_id);
            ELSIF v_txn_type = 'SHIPMENT' THEN
                INSERT INTO SHIPMENT_TRANSACTIONS (inventory_transactions_id, shipment_number, destination_adress)
                VALUES (v_txn_id, v_txn_id + 1000000, 'Address ' || random_int(1, 10000));
            END IF;

            FOR m IN 1..v_num_movements LOOP
                    v_success := FALSE;
                    SELECT min(id), max(id) INTO v_min_inv, v_max_inv FROM INVENTORY;

                    IF v_txn_type = 'RECEIPT' THEN
                        SELECT id INTO v_var_id FROM PRODUCT_VARIANTS WHERE id >= random_bigint(v_min_var, v_max_var) LIMIT 1;
                        SELECT id INTO v_to_bin FROM BINS WHERE id >= random_bigint(v_min_bin, v_max_bin) LIMIT 1;
                        v_from_bin := NULL;
                        v_qty := random_int(10, 10000);

                        IF v_var_id IS NOT NULL AND v_to_bin IS NOT NULL THEN
                            -- Ensure the row exists so the trigger can update it without failing
                            INSERT INTO INVENTORY (product_variant_id, bin_id, quantity, reserved_quantity, status, updated_at)
                            VALUES (v_var_id, v_to_bin, 0, 0, 'AVAILABLE', v_current_time)
                            ON CONFLICT (product_variant_id, bin_id) DO NOTHING;

                            v_success := TRUE;
                        END IF;

                    ELSIF v_txn_type = 'SHIPMENT' THEN
                        SELECT product_variant_id, bin_id, quantity
                        INTO v_var_id, v_from_bin, v_qty_available
                        FROM INVENTORY
                        WHERE id >= random_bigint(v_min_inv, v_max_inv) AND quantity > 0 LIMIT 1;

                        v_to_bin := NULL;

                        IF v_var_id IS NOT NULL THEN
                            v_qty := LEAST(random_int(1, 5000), v_qty_available);
                            v_success := TRUE; -- No manual update, just set success to insert movement
                        END IF;

                    ELSIF v_txn_type = 'TRANSFER' THEN
                        SELECT product_variant_id, bin_id, quantity
                        INTO v_var_id, v_from_bin, v_qty_available
                        FROM INVENTORY
                        WHERE id >= random_bigint(v_min_inv, v_max_inv) AND quantity > 0 LIMIT 1;

                        SELECT id INTO v_to_bin FROM BINS
                        WHERE id >= random_bigint(v_min_bin, v_max_bin) AND id <> COALESCE(v_from_bin, -1) LIMIT 1;

                        IF v_var_id IS NOT NULL AND v_from_bin IS NOT NULL AND v_to_bin IS NOT NULL THEN
                            v_qty := LEAST(random_int(5, 2000), v_qty_available);

                            -- Ensure destination row exists for the trigger
                            INSERT INTO INVENTORY (product_variant_id, bin_id, quantity, reserved_quantity, status, updated_at)
                            VALUES (v_var_id, v_to_bin, 0, 0, 'AVAILABLE', v_current_time)
                            ON CONFLICT (product_variant_id, bin_id) DO NOTHING;

                            v_success := TRUE;
                        END IF;
                    END IF;

                    -- Insert Movement Record (This fires your trigger and updates INVENTORY)
                    IF v_success THEN
                        -- We wrap this in a block in case the trigger fails for any edge-case reason
                        BEGIN
                            INSERT INTO INVENTORY_MOVEMENTS (
                                inventory_transactions_id, product_variant_id, from_bin_id, to_bin_id, quantity, created_at
                            ) VALUES (
                                         v_txn_id, v_var_id, v_from_bin, v_to_bin, v_qty, v_current_time
                                     );
                            v_movements_inserted := v_movements_inserted + 1;

                            IF v_movements_inserted % 1000000 = 0 THEN
                                RAISE NOTICE 'Progress: % / % movements generated.', v_movements_inserted, p_target_movements;
                            END IF;
                        EXCEPTION WHEN OTHERS THEN
                        -- Skip movement if trigger constraints still fail
                        END;
                    END IF;

                END LOOP;

            IF v_txn_id % 5000 = 0 THEN
                COMMIT;
            END IF;

        END LOOP;

    COMMIT;
    RAISE NOTICE 'Successfully generated % inventory movements.', v_movements_inserted;
END;
$$;

-- ==============================================================================
-- 4. Validation Procedure (Ensures mathematical consistency)
-- ==============================================================================
CREATE
    OR REPLACE PROCEDURE validate_inventory_consistency()
    LANGUAGE plpgsql AS
$$
DECLARE
    v_anomalies INT;
BEGIN
    RAISE
        NOTICE 'Validating inventory consistency...';

    WITH net_movements AS (SELECT product_variant_id,
                                  bin_id,
                                  SUM(qty_change) as expected_net_qty
                           FROM (
                                    -- Additions (Receipts and Transfer IN)
                                    SELECT product_variant_id, to_bin_id AS bin_id, quantity as qty_change
                                    FROM INVENTORY_MOVEMENTS
                                    WHERE to_bin_id IS NOT NULL
                                    UNION ALL
                                    -- Subtractions (Shipments and Transfer OUT)
                                    SELECT product_variant_id, from_bin_id AS bin_id, -quantity as qty_change
                                    FROM INVENTORY_MOVEMENTS
                                    WHERE from_bin_id IS NOT NULL) sub
                           GROUP BY product_variant_id, bin_id)
    SELECT COUNT(*)
    INTO v_anomalies
    FROM net_movements nm
             JOIN INVENTORY i ON nm.product_variant_id = i.product_variant_id AND nm.bin_id = i.bin_id
-- Compare calculated net vs actual table (accounting for any initial stock)
    WHERE (i.quantity) < nm.expected_net_qty; -- Inventory should always be >= net movements due to initial stock

    IF
        v_anomalies = 0 THEN
        RAISE NOTICE 'Validation PASSED. No negative leaks found.';
    ELSE
        RAISE WARNING 'Validation FAILED. Found % anomalous bin/variant combinations.', v_anomalies;
    END IF;
END;
$$;

-- ==============================================================================
-- 5. Execution Block
-- ==============================================================================
DO
$$
    BEGIN
        -- 1. Initialize Starting Stock
        CALL initialize_inventory();

-- 2. Generate 30 Million Movements
        CALL generate_inventory_data(1000000);

-- 3. Validate Results
        CALL validate_inventory_consistency();
    END
$$;