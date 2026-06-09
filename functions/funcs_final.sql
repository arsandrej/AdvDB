-- =============================================================================
-- 5. INVENTORY OPERATION PROCEDURES
-- =============================================================================

-- 5a. Receive a delivery from a supplier
CREATE OR REPLACE FUNCTION receive_delivery(
    p_supplier_company TEXT,
    p_delivery_note TEXT,
    p_created_by_employee BIGINT,
    p_items movement_item[]
)
    RETURNS BIGINT AS
$$
DECLARE
v_transaction_id BIGINT;
    item             movement_item;
BEGIN
    -- Create the transaction header
INSERT INTO INVENTORY_TRANSACTIONS (transaction_type, created_by_employee, notes)
VALUES ('RECEIPT', p_created_by_employee, 'Delivery receipt')
    RETURNING id INTO v_transaction_id;

-- Create delivery-specific record
INSERT INTO DELIVERY_TRANSACTIONS (inventory_transactions_id, supplier_company, delivery_note)
VALUES (v_transaction_id, p_supplier_company, p_delivery_note);

-- Insert a movement for each item (from_bin_id must be NULL, to_bin_id required)
FOREACH item IN ARRAY p_items
        LOOP
            IF item.from_bin_id IS NOT NULL OR item.to_bin_id IS NULL THEN
                RAISE EXCEPTION 'Invalid delivery item: from_bin_id must be NULL and to_bin_id must be set';
            END IF;
            INSERT INTO INVENTORY_MOVEMENTS (product_variant_id, from_bin_id, to_bin_id, quantity,
                                         inventory_transactions_id)
            VALUES (item.product_variant_id, NULL, item.to_bin_id, item.quantity, v_transaction_id);
        END LOOP;
RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- 5b. Ship stock to a customer/destination
CREATE OR REPLACE FUNCTION ship_stock(
    p_destination_address TEXT,
    p_shipment_number BIGINT,
    p_created_by_employee BIGINT,
    p_items movement_item[]
)
    RETURNS BIGINT AS
$$
DECLARE
v_transaction_id BIGINT;
    item             movement_item;
BEGIN
INSERT INTO INVENTORY_TRANSACTIONS (transaction_type, created_by_employee, notes)
VALUES ('SHIPMENT', p_created_by_employee, 'Customer shipment')
    RETURNING id INTO v_transaction_id;

INSERT INTO SHIPMENT_TRANSACTIONS (inventory_transactions_id, destination_adress, shipment_number)
VALUES (v_transaction_id, p_destination_address, p_shipment_number);

-- For shipments, from_bin_id required, to_bin_id must be NULL
FOREACH item IN ARRAY p_items
        LOOP
            IF item.from_bin_id IS NULL OR item.to_bin_id IS NOT NULL THEN
                RAISE EXCEPTION 'Invalid shipment item: from_bin_id must be set and to_bin_id must be NULL';
            END IF;
            INSERT INTO INVENTORY_MOVEMENTS (product_variant_id, from_bin_id, to_bin_id, quantity,
                                 inventory_transactions_id)
            VALUES (item.product_variant_id, item.from_bin_id, NULL, item.quantity, v_transaction_id);
        END LOOP;

RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- 5c. Internal transfer between bins
CREATE OR REPLACE FUNCTION transfer_stock(
    p_created_by_employee BIGINT,
    p_items movement_item[]
)
    RETURNS BIGINT AS
$$
DECLARE
v_transaction_id BIGINT;
    item             movement_item;
BEGIN
INSERT INTO INVENTORY_TRANSACTIONS (transaction_type, created_by_employee, notes)
VALUES ('TRANSFER', p_created_by_employee, 'Internal transfer')
    RETURNING id INTO v_transaction_id;

-- Both bins must be provided and must differ (also enforced by CHECK constraint)
FOREACH item IN ARRAY p_items
        LOOP
            IF item.from_bin_id IS NULL OR item.to_bin_id IS NULL THEN
                RAISE EXCEPTION 'Invalid transfer item: both from_bin_id and to_bin_id must be set';
            END IF;
            INSERT INTO INVENTORY_MOVEMENTS (product_variant_id, from_bin_id, to_bin_id, quantity,
                                 inventory_transactions_id)
            VALUES (item.product_variant_id, item.from_bin_id, item.to_bin_id, item.quantity, v_transaction_id);
        END LOOP;

RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- 5d. Manual inventory adjustment / correction
CREATE OR REPLACE FUNCTION adjust_inventory(
    p_created_by_employee BIGINT,
    p_notes TEXT,
    p_items adjustment_item[]
)
    RETURNS BIGINT AS
$$
DECLARE
v_transaction_id BIGINT;
    item             adjustment_item;
BEGIN
INSERT INTO INVENTORY_TRANSACTIONS (transaction_type, created_by_employee, notes)
VALUES ('ADJUSTMENT', p_created_by_employee, p_notes)
    RETURNING id INTO v_transaction_id;

-- Convert positive/negative changes into appropriate movements
FOREACH item IN ARRAY p_items
        LOOP
            IF item.quantity_change > 0 THEN
                -- Add stock: movement from NULL to bin
                INSERT INTO INVENTORY_MOVEMENTS (product_variant_id, from_bin_id, to_bin_id, quantity,
                                                 inventory_transactions_id)
                VALUES (item.product_variant_id, NULL, item.bin_id, item.quantity_change, v_transaction_id);
            ELSIF item.quantity_change < 0 THEN
                -- Subtract stock: movement from bin to NULL
                INSERT INTO INVENTORY_MOVEMENTS (product_variant_id, from_bin_id, to_bin_id, quantity,
                                                 inventory_transactions_id)
                VALUES (item.product_variant_id, item.bin_id, NULL, ABS(item.quantity_change), v_transaction_id);
            ELSE
                RAISE NOTICE 'Zero adjustment ignored for variant % in bin %', item.product_variant_id, item.bin_id;
            END IF;
        END LOOP;

RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;



-- =============================================================================
-- 2. CUSTOM TYPES FOR PROCEDURE PARAMETERS
-- =============================================================================
-- Used for receipt, shipment and transfer operations
CREATE TYPE movement_item AS
    (
    product_variant_id BIGINT,
    from_bin_id        BIGINT,
    to_bin_id          BIGINT,
    quantity           INT
    );

-- Used for inventory adjustments (positive = add, negative = subtract)
CREATE TYPE adjustment_item AS
    (
    product_variant_id BIGINT,
    bin_id             BIGINT,
    quantity_change    INT
    );

-- =============================================================================
-- 3. UPDATED_AT TRIGGERS (BASIC)
-- =============================================================================
-- Generic trigger function
CREATE OR REPLACE FUNCTION update_timestamp()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables that have an updated_at column
CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE
    ON PRODUCTS
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_employees_updated_at
    BEFORE UPDATE
    ON EMPLOYEES
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_employee_warehouse_assignments_updated_at
    BEFORE UPDATE
    ON EMPLOYEE_WAREHOUSE_ASSIGNMENTS
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_roles_updated_at
    BEFORE UPDATE
    ON ROLES
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_permissions_updated_at
    BEFORE UPDATE
    ON PERMISSIONS
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- =============================================================================
-- 4. INVENTORY MOVEMENT TRIGGERS
-- =============================================================================

-- 4a. BEFORE INSERT: validate that the source bin has enough available stock
CREATE OR REPLACE FUNCTION validate_inventory_movement()
    RETURNS TRIGGER AS
$$
DECLARE
available INT;
BEGIN
    -- Only check when there is a source bin
    IF NEW.from_bin_id IS NOT NULL THEN
SELECT (quantity - reserved_quantity)
INTO available
FROM INVENTORY
WHERE product_variant_id = NEW.product_variant_id
  AND bin_id = NEW.from_bin_id
    FOR UPDATE; -- lock the row to prevent race conditions

IF NOT FOUND THEN
            RAISE EXCEPTION 'Insufficient stock: variant % has no inventory in bin %',
                NEW.product_variant_id, NEW.from_bin_id;
END IF;

        IF available < NEW.quantity THEN
            RAISE EXCEPTION 'Insufficient stock: variant % in bin % has % available, but % requested',
                NEW.product_variant_id, NEW.from_bin_id, available, NEW.quantity;
END IF;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_movement_before_insert
    BEFORE INSERT
    ON INVENTORY_MOVEMENTS
    FOR EACH ROW
    EXECUTE FUNCTION validate_inventory_movement();

-- 4b. AFTER INSERT: adjust inventory quantities automatically
CREATE OR REPLACE FUNCTION update_inventory_on_movement()
    RETURNS TRIGGER AS
$$
BEGIN
    -- Decrease source bin quantity
    IF NEW.from_bin_id IS NOT NULL THEN
UPDATE INVENTORY
SET quantity   = quantity - NEW.quantity,
    updated_at = CURRENT_TIMESTAMP
WHERE product_variant_id = NEW.product_variant_id
  AND bin_id = NEW.from_bin_id;
END IF;

    -- Increase destination bin quantity (create row if necessary)
    IF NEW.to_bin_id IS NOT NULL THEN
        INSERT INTO INVENTORY (product_variant_id, bin_id, quantity, reserved_quantity, status)
        VALUES (NEW.product_variant_id, NEW.to_bin_id, NEW.quantity, 0, 'AVAILABLE')
        ON CONFLICT (product_variant_id, bin_id) DO UPDATE
                                                               SET quantity   = INVENTORY.quantity + EXCLUDED.quantity,
                                                               updated_at = CURRENT_TIMESTAMP;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_movement_after_insert
    AFTER INSERT
    ON INVENTORY_MOVEMENTS
    FOR EACH ROW
    EXECUTE FUNCTION update_inventory_on_movement();





