-- =============================================================================
-- COMPLETE INVENTORY DATA GENERATION – FINAL FIXED SCRIPT
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 2. Trigger: maintains inventory without violating CHECK constraints
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_movement_maintain_inventory()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    -- Outgoing goods: plain UPDATE (avoids any negative INSERT)
    IF NEW.from_bin_id IS NOT NULL THEN
        UPDATE inventory
        SET quantity   = quantity - NEW.quantity,
            updated_at = NEW.created_at
        WHERE product_variant_id = NEW.product_variant_id
          AND bin_id = NEW.from_bin_id;
    END IF;

    -- Incoming goods: INSERT … ON CONFLICT (positive quantity, always safe)
    IF NEW.to_bin_id IS NOT NULL THEN
        INSERT INTO inventory (product_variant_id, bin_id, quantity, reserved_quantity, updated_at, status)
        VALUES (NEW.product_variant_id, NEW.to_bin_id, NEW.quantity, 0, NEW.created_at, 'ACTIVE')
        ON CONFLICT (product_variant_id, bin_id) DO UPDATE
            SET quantity   = inventory.quantity + NEW.quantity,
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

-- -----------------------------------------------------------------------------
-- 3. Safe stock checker (optional, but used in generation)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_available_stock(
    p_product_variant_id BIGINT,
    p_bin_id BIGINT
) RETURNS INT
    LANGUAGE plpgsql
AS
$$
DECLARE
    avail INT;
BEGIN
    SELECT quantity
    INTO avail
    FROM inventory
    WHERE product_variant_id = p_product_variant_id
      AND bin_id = p_bin_id
        FOR UPDATE;
    RETURN COALESCE(avail, 0);
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. Core transaction builder
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_inventory_transaction_safe(
    p_transaction_type VARCHAR(50),
    p_employee_id BIGINT,
    p_created_at TIMESTAMP,
    p_movements JSONB,
    p_notes TEXT DEFAULT NULL,
    p_delivery_note TEXT DEFAULT NULL,
    p_supplier_company TEXT DEFAULT NULL,
    p_shipment_number BIGINT DEFAULT NULL,
    p_destination_address TEXT DEFAULT NULL
)
    RETURNS BIGINT
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_txn_id   BIGINT;
    v_movement JSONB;
    v_variant  BIGINT;
    v_from     BIGINT;
    v_to       BIGINT;
    v_qty      INT;
    v_avail    INT;
BEGIN
    INSERT INTO inventory_transactions (transaction_type,
                                        created_by_employee,
                                        notes,
                                        created_at)
    VALUES (p_transaction_type,
            p_employee_id,
            p_notes,
            p_created_at)
    RETURNING id INTO v_txn_id;

    IF p_transaction_type = 'RECEIPT' THEN
        INSERT INTO delivery_transactions (delivery_note,
                                           supplier_company,
                                           inventory_transactions_id)
        VALUES (p_delivery_note,
                p_supplier_company,
                v_txn_id);
    ELSIF p_transaction_type = 'SHIPMENT' THEN
        INSERT INTO shipment_transactions (shipment_number,
                                           destination_adress,
                                           inventory_transactions_id)
        VALUES (p_shipment_number,
                p_destination_address,
                v_txn_id);
    END IF;

    FOR v_movement IN SELECT * FROM jsonb_array_elements(p_movements)
        LOOP
            v_variant := (v_movement ->> 'product_variant_id')::BIGINT;
            v_from := NULLIF(v_movement ->> 'from_bin_id', '')::BIGINT;
            v_to := NULLIF(v_movement ->> 'to_bin_id', '')::BIGINT;
            v_qty := (v_movement ->> 'quantity')::INT;

            IF v_from IS NOT NULL THEN
                v_avail := get_available_stock(v_variant, v_from);
                IF v_avail <= 0 THEN CONTINUE; END IF;
                v_qty := LEAST(v_qty, v_avail);
            END IF;

            INSERT INTO inventory_movements (product_variant_id,
                                             from_bin_id,
                                             to_bin_id,
                                             quantity,
                                             created_at,
                                             inventory_transactions_id)
            VALUES (v_variant,
                    v_from,
                    v_to,
                    v_qty,
                    p_created_at,
                    v_txn_id);
        END LOOP;

    RETURN v_txn_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. Main generation procedure (uses cardinality, not array_length)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE generate_inventory_history(
    start_date DATE,
    end_date DATE,
    movements_target BIGINT DEFAULT 30000000
)
    LANGUAGE plpgsql
AS
$$
DECLARE
    cur_date                  DATE;
    day_movements             BIGINT := 0;
    total_movements           BIGINT := 0;
    days_total                INT;
    daily_mov_target          BIGINT;
    emp_ids                   BIGINT[];
    all_variants              BIGINT[];
    all_bins                  BIGINT[];
    v_employee                BIGINT;
    v_variant                 BIGINT;
    v_from_bin                BIGINT;
    v_to_bin                  BIGINT;
    v_qty                     INT;
    v_avail                   INT;
    receipts_per_day          INT;
    shipments_per_day         INT;
    transfers_per_day         INT;
    max_qty_per_move CONSTANT INT    := 500;
    i                         INT;
BEGIN
    -- Active employees
    emp_ids := ARRAY(SELECT DISTINCT ewa.employee_id
                     FROM employee_warehouse_assignments ewa
                     WHERE ewa.end_date IS NULL);
    IF emp_ids IS NULL OR cardinality(emp_ids) = 0 THEN
        RAISE EXCEPTION 'No active employees found in EMPLOYEE_WAREHOUSE_ASSIGNMENTS';
    END IF;

    -- Product variants and bins
    all_variants := ARRAY(SELECT id FROM product_variants ORDER BY id);
    all_bins := ARRAY(SELECT id FROM bins ORDER BY id);
    IF all_variants IS NULL OR cardinality(all_variants) = 0 THEN
        RAISE EXCEPTION 'PRODUCT_VARIANTS table is empty';
    END IF;
    IF all_bins IS NULL OR cardinality(all_bins) = 0 THEN
        RAISE EXCEPTION 'BINS table is empty';
    END IF;

    days_total := end_date - start_date + 1;
    daily_mov_target := movements_target / days_total;
    IF daily_mov_target < 1 THEN daily_mov_target := 1; END IF;

    -- -------------------------------------------------------------------------
    -- Seed initial inventory (one receipt per variant)
    -- -------------------------------------------------------------------------
    RAISE NOTICE 'Seeding initial inventory...';
    FOR i IN 1..cardinality(all_variants)
        LOOP
            v_variant := all_variants[i];
            v_to_bin := all_bins[floor(random() * cardinality(all_bins) + 1)::INT];
            v_qty := 100 + floor(random() * 1000)::INT;
            v_employee := emp_ids[floor(random() * cardinality(emp_ids) + 1)::INT];

            PERFORM create_inventory_transaction_safe(
                    'RECEIPT',
                    v_employee,
                    (start_date - 1) + time '12:00:00',
                    jsonb_build_array(
                            jsonb_build_object(
                                    'product_variant_id', v_variant,
                                    'from_bin_id', NULL,
                                    'to_bin_id', v_to_bin,
                                    'quantity', v_qty
                            )
                    ),
                    'Initial stock load',
                    'INIT-001',
                    'InHouse Supply'
                    );
        END LOOP;
    COMMIT;

    -- -------------------------------------------------------------------------
    -- Daily operations
    -- -------------------------------------------------------------------------
    cur_date := start_date;
    WHILE cur_date <= end_date
        LOOP
            RAISE NOTICE 'Day %', cur_date;
            day_movements := 0;

            receipts_per_day := GREATEST(ceil(random() * 0.3 * daily_mov_target)::INT, 10);
            shipments_per_day := GREATEST(ceil(random() * 0.5 * daily_mov_target)::INT, 10);
            transfers_per_day := GREATEST(ceil(random() * 0.4 * daily_mov_target)::INT, 10);

            -- RECEIPTS
            FOR i IN 1..receipts_per_day
                LOOP
                    v_employee := emp_ids[floor(random() * cardinality(emp_ids) + 1)::INT];
                    v_variant := all_variants[floor(random() * cardinality(all_variants) + 1)::INT];
                    v_to_bin := all_bins[floor(random() * cardinality(all_bins) + 1)::INT];
                    v_qty := 10 + floor(random() * max_qty_per_move)::INT;

                    PERFORM create_inventory_transaction_safe(
                            'RECEIPT',
                            v_employee,
                            cur_date + time '10:00:00' + (random() * interval '8 hours'),
                            jsonb_build_array(
                                    jsonb_build_object(
                                            'product_variant_id', v_variant,
                                            'from_bin_id', NULL,
                                            'to_bin_id', v_to_bin,
                                            'quantity', v_qty
                                    )
                            ),
                            NULL,
                            'DN-' || cur_date || '-' || i,
                            'Supplier ' || (1 + floor(random() * 100))::TEXT
                            );
                    day_movements := day_movements + 1;
                END LOOP;

            -- SHIPMENTS
            FOR i IN 1..shipments_per_day
                LOOP
                    v_employee := emp_ids[floor(random() * cardinality(emp_ids) + 1)::INT];
                    v_variant := all_variants[floor(random() * cardinality(all_variants) + 1)::INT];

                    SELECT bin_id, quantity
                    INTO v_from_bin, v_avail
                    FROM inventory
                    WHERE product_variant_id = v_variant
                      AND quantity > 0
                    ORDER BY random()
                    LIMIT 1;

                    IF FOUND THEN
                        v_qty := LEAST(
                                ceil(v_avail * (0.05 + random() * 0.9))::INT,
                                max_qty_per_move
                                 );
                        v_qty := GREATEST(v_qty, 1);

                        PERFORM create_inventory_transaction_safe(
                                'SHIPMENT',
                                v_employee,
                                cur_date + time '10:00:00' + (random() * interval '8 hours'),
                                jsonb_build_array(
                                        jsonb_build_object(
                                                'product_variant_id', v_variant,
                                                'from_bin_id', v_from_bin,
                                                'to_bin_id', NULL,
                                                'quantity', v_qty
                                        )
                                ),
                                'Shipment from stock',
                                NULL,
                                NULL,
                                (100000 + floor(random() * 900000))::BIGINT,
                                'Address ' || (1 + floor(random() * 500))::TEXT
                                );
                        day_movements := day_movements + 1;
                    END IF;
                END LOOP;

            -- TRANSFERS
            FOR i IN 1..transfers_per_day
                LOOP
                    v_employee := emp_ids[floor(random() * cardinality(emp_ids) + 1)::INT];
                    v_variant := all_variants[floor(random() * cardinality(all_variants) + 1)::INT];

                    SELECT bin_id, quantity
                    INTO v_from_bin, v_avail
                    FROM inventory
                    WHERE product_variant_id = v_variant
                      AND quantity > 0
                    ORDER BY random()
                    LIMIT 1;

                    IF FOUND THEN
                        LOOP
                            v_to_bin := all_bins[floor(random() * cardinality(all_bins) + 1)::INT];
                            EXIT WHEN v_to_bin IS DISTINCT FROM v_from_bin;
                        END LOOP;

                        v_qty := LEAST(
                                ceil(v_avail * (0.05 + random() * 0.9))::INT,
                                max_qty_per_move
                                 );
                        v_qty := GREATEST(v_qty, 1);

                        PERFORM create_inventory_transaction_safe(
                                'TRANSFER',
                                v_employee,
                                cur_date + time '10:00:00' + (random() * interval '8 hours'),
                                jsonb_build_array(
                                        jsonb_build_object(
                                                'product_variant_id', v_variant,
                                                'from_bin_id', v_from_bin,
                                                'to_bin_id', v_to_bin,
                                                'quantity', v_qty
                                        )
                                ),
                                'Internal transfer'
                                );
                        day_movements := day_movements + 1;
                    END IF;
                END LOOP;

            total_movements := total_movements + day_movements;
            COMMIT;

            cur_date := cur_date + 1;
        END LOOP;

    RAISE NOTICE 'Generation complete. Total movements inserted: %', total_movements;
END;
$$;

-- =============================================================================
-- 6. RUN (uncomment the appropriate line)
-- =============================================================================
-- Small test (10 000 movements over 1 year):
--CALL generate_inventory_history('2022-01-01', '2023-01-01', 10000);

-- Full 30‑million run (2 years):
CALL generate_inventory_history('2022-01-01', '2023-12-31', 30000000);