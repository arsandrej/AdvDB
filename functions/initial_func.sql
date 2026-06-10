-- =============================================================================
-- 0. ONE-TIME SETUP: DUMMY EMPLOYEE FOR CANCELLATION MARKER
-- =============================================================================
-- This employee represents a system cancellation and is never a real person.
-- The ID -1 will be used as a sentinel value in accepted_by.
INSERT INTO EMPLOYEES (id, employee_number, first_name, last_name, email, job_title, employment_status, hired_at)
VALUES (-1, 'CANCELLATION', 'System', 'Cancellation', 'no-reply@system.local', 'System Account', 'INACTIVE',
        CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- 1. CUSTOM TYPES
-- =============================================================================
CREATE TYPE movement_item AS
(
    product_variant_id BIGINT,
    from_bin_id        BIGINT,
    to_bin_id          BIGINT,
    quantity           INT
);

CREATE TYPE adjustment_item AS
(
    product_variant_id BIGINT,
    bin_id             BIGINT,
    quantity_change    INT
);

-- =============================================================================
-- 2. UPDATED_AT TRIGGERS (unchanged)
-- =============================================================================
CREATE OR REPLACE FUNCTION update_timestamp()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_products_updated_at ON PRODUCTS;
CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE
    ON PRODUCTS
    FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_employees_updated_at ON EMPLOYEES;
CREATE TRIGGER trg_employees_updated_at
    BEFORE UPDATE
    ON EMPLOYEES
    FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_employee_warehouse_assignments_updated_at ON EMPLOYEE_WAREHOUSE_ASSIGNMENTS;
CREATE TRIGGER trg_employee_warehouse_assignments_updated_at
    BEFORE UPDATE
    ON EMPLOYEE_WAREHOUSE_ASSIGNMENTS
    FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_roles_updated_at ON ROLES;
CREATE TRIGGER trg_roles_updated_at
    BEFORE UPDATE
    ON ROLES
    FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_permissions_updated_at ON PERMISSIONS;
CREATE TRIGGER trg_permissions_updated_at
    BEFORE UPDATE
    ON PERMISSIONS
    FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- =============================================================================
-- 5. APPROVAL Procedure (consumes reserved stock)
-- =============================================================================
CREATE OR REPLACE PROCEDURE  approve_inventory_transaction(
    p_transaction_id BIGINT,
    p_approving_employee_id BIGINT
)
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_rec RECORD;
BEGIN
    -- Must be pending (accepted_by IS NULL)
    IF NOT EXISTS (SELECT 1
                   FROM INVENTORY_TRANSACTIONS
                   WHERE id = p_transaction_id
                     AND accepted_by IS NULL) THEN
        RAISE EXCEPTION 'Transaction % does not exist or is already approved/cancelled', p_transaction_id;
    END IF;

    FOR v_rec IN
        SELECT id, product_variant_id, from_bin_id, to_bin_id, quantity
        FROM INVENTORY_MOVEMENTS
        WHERE inventory_transactions_id = p_transaction_id
        ORDER BY id
            FOR UPDATE OF INVENTORY_MOVEMENTS
        LOOP
            -- Source bin: decrease quantity and reserved_quantity
            IF v_rec.from_bin_id IS NOT NULL THEN
                UPDATE INVENTORY
                SET quantity          = quantity - v_rec.quantity,
                    reserved_quantity = reserved_quantity - v_rec.quantity,
                    updated_at        = CURRENT_TIMESTAMP
                WHERE product_variant_id = v_rec.product_variant_id
                  AND bin_id = v_rec.from_bin_id
                  AND reserved_quantity >= v_rec.quantity;
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Reservation inconsistency for variant % bin % in transaction %',
                        v_rec.product_variant_id, v_rec.from_bin_id, p_transaction_id;
                END IF;
            END IF;

            -- Destination bin: increase quantity
            IF v_rec.to_bin_id IS NOT NULL THEN
                INSERT INTO INVENTORY (product_variant_id, bin_id, quantity, reserved_quantity, status)
                VALUES (v_rec.product_variant_id, v_rec.to_bin_id, v_rec.quantity, 0, 'AVAILABLE')
                ON CONFLICT (product_variant_id, bin_id) DO UPDATE
                    SET quantity   = INVENTORY.quantity + EXCLUDED.quantity,
                        updated_at = CURRENT_TIMESTAMP;
            END IF;
        END LOOP;

    -- Mark transaction as approved
    UPDATE INVENTORY_TRANSACTIONS
    SET accepted_by     = p_approving_employee_id,
        last_updated_by = p_approving_employee_id
    WHERE id = p_transaction_id;
END;
$$;

-- =============================================================================
-- 6. CANCELLATION PROCEDURE (marks as cancelled using accepted_by = -1)
-- =============================================================================
-- Note: accepted_by = -1 is a sentinel value representing a cancelled transaction.
-- The dummy employee with id = -1 must exist (see setup at top of file).
CREATE OR REPLACE PROCEDURE cancel_pending_transaction(
    p_transaction_id BIGINT,
    p_cancelled_by_employee BIGINT
)
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_rec RECORD;
BEGIN
    -- Only pending transactions (accepted_by IS NULL) can be cancelled
    IF NOT EXISTS (SELECT 1
                   FROM INVENTORY_TRANSACTIONS
                   WHERE id = p_transaction_id
                     AND accepted_by IS NULL) THEN
        RAISE EXCEPTION 'Transaction % cannot be cancelled (not pending or already approved/cancelled)', p_transaction_id;
    END IF;

    -- Release reservations for all movements with a source bin
    FOR v_rec IN
        SELECT product_variant_id, from_bin_id, quantity
        FROM INVENTORY_MOVEMENTS
        WHERE inventory_transactions_id = p_transaction_id
          AND from_bin_id IS NOT NULL
        LOOP
            UPDATE INVENTORY
            SET reserved_quantity = reserved_quantity - v_rec.quantity,
                updated_at        = CURRENT_TIMESTAMP
            WHERE product_variant_id = v_rec.product_variant_id
              AND bin_id = v_rec.from_bin_id
              AND reserved_quantity >= v_rec.quantity;
            IF NOT FOUND THEN
                RAISE WARNING 'Failed to release reservation for variant % bin % (quantity %) in transaction %',
                    v_rec.product_variant_id, v_rec.from_bin_id, v_rec.quantity, p_transaction_id;
            END IF;
        END LOOP;

    -- Mark transaction as cancelled using sentinel employee -1
    UPDATE INVENTORY_TRANSACTIONS
    SET accepted_by     = -1,
        last_updated_by = p_cancelled_by_employee,
        notes           = COALESCE(notes, '') || E'\n[CANCELLED by employee ' || p_cancelled_by_employee || ' at ' ||
                          CURRENT_TIMESTAMP || ']'
    WHERE id = p_transaction_id;
END;
$$;

-- =============================================================================
-- 7. CREATION FUNCTIONS (pending, with stock reservation)
-- =============================================================================

-- 7a. Receive a delivery (no reservation)
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
    INSERT INTO INVENTORY_TRANSACTIONS (transaction_type, created_by_employee, notes, accepted_by)
    VALUES ('RECEIPT', p_created_by_employee, 'Delivery receipt', NULL)
    RETURNING id INTO v_transaction_id;

    INSERT INTO DELIVERY_TRANSACTIONS (inventory_transactions_id, supplier_company, delivery_note)
    VALUES (v_transaction_id, p_supplier_company, p_delivery_note);

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

-- 7b. Ship stock (reserve from source bin)
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
    v_available      INT;
BEGIN
    INSERT INTO INVENTORY_TRANSACTIONS (transaction_type, created_by_employee, notes, accepted_by)
    VALUES ('SHIPMENT', p_created_by_employee, 'Customer shipment', NULL)
    RETURNING id INTO v_transaction_id;

    INSERT INTO SHIPMENT_TRANSACTIONS (inventory_transactions_id, destination_adress, shipment_number)
    VALUES (v_transaction_id, p_destination_address, p_shipment_number);

    FOREACH item IN ARRAY p_items
        LOOP
            IF item.from_bin_id IS NULL OR item.to_bin_id IS NOT NULL THEN
                RAISE EXCEPTION 'Invalid shipment item: from_bin_id must be set and to_bin_id must be NULL';
            END IF;

            UPDATE INVENTORY
            SET reserved_quantity = reserved_quantity + item.quantity,
                updated_at        = CURRENT_TIMESTAMP
            WHERE product_variant_id = item.product_variant_id
              AND bin_id = item.from_bin_id
              AND (quantity - reserved_quantity) >= item.quantity
            RETURNING (quantity - reserved_quantity + item.quantity) INTO v_available;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Insufficient stock for variant % in bin % (need %)',
                    item.product_variant_id, item.from_bin_id, item.quantity;
            END IF;

            INSERT INTO INVENTORY_MOVEMENTS (product_variant_id, from_bin_id, to_bin_id, quantity,
                                             inventory_transactions_id)
            VALUES (item.product_variant_id, item.from_bin_id, NULL, item.quantity, v_transaction_id);
        END LOOP;

    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- 7c. Internal transfer (reserve from source bin)
CREATE OR REPLACE FUNCTION transfer_stock(
    p_created_by_employee BIGINT,
    p_items movement_item[]
)
    RETURNS BIGINT AS
$$
DECLARE
    v_transaction_id BIGINT;
    item             movement_item;
    v_available      INT;
BEGIN
    INSERT INTO INVENTORY_TRANSACTIONS (transaction_type, created_by_employee, notes, accepted_by)
    VALUES ('TRANSFER', p_created_by_employee, 'Internal transfer', NULL)
    RETURNING id INTO v_transaction_id;

    FOREACH item IN ARRAY p_items
        LOOP
            IF item.from_bin_id IS NULL OR item.to_bin_id IS NULL THEN
                RAISE EXCEPTION 'Invalid transfer item: both from_bin_id and to_bin_id must be set';
            END IF;

            UPDATE INVENTORY
            SET reserved_quantity = reserved_quantity + item.quantity,
                updated_at        = CURRENT_TIMESTAMP
            WHERE product_variant_id = item.product_variant_id
              AND bin_id = item.from_bin_id
              AND (quantity - reserved_quantity) >= item.quantity
            RETURNING (quantity - reserved_quantity + item.quantity) INTO v_available;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Insufficient stock for variant % in bin % (need %)',
                    item.product_variant_id, item.from_bin_id, item.quantity;
            END IF;

            INSERT INTO INVENTORY_MOVEMENTS (product_variant_id, from_bin_id, to_bin_id, quantity,
                                             inventory_transactions_id)
            VALUES (item.product_variant_id, item.from_bin_id, item.to_bin_id, item.quantity, v_transaction_id);
        END LOOP;

    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- 7d. Manual inventory adjustment (reserve for negative changes)
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
    v_available      INT;
BEGIN
    INSERT INTO INVENTORY_TRANSACTIONS (transaction_type, created_by_employee, notes, accepted_by)
    VALUES ('ADJUSTMENT', p_created_by_employee, p_notes, NULL)
    RETURNING id INTO v_transaction_id;

    FOREACH item IN ARRAY p_items
        LOOP
            IF item.quantity_change > 0 THEN
                INSERT INTO INVENTORY_MOVEMENTS (product_variant_id, from_bin_id, to_bin_id, quantity,
                                                 inventory_transactions_id)
                VALUES (item.product_variant_id, NULL, item.bin_id, item.quantity_change, v_transaction_id);
            ELSIF item.quantity_change < 0 THEN
                UPDATE INVENTORY
                SET reserved_quantity = reserved_quantity + ABS(item.quantity_change),
                    updated_at        = CURRENT_TIMESTAMP
                WHERE product_variant_id = item.product_variant_id
                  AND bin_id = item.bin_id
                  AND (quantity - reserved_quantity) >= ABS(item.quantity_change)
                RETURNING (quantity - reserved_quantity + ABS(item.quantity_change)) INTO v_available;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Insufficient stock for variant % in bin % (need %)',
                        item.product_variant_id, item.bin_id, ABS(item.quantity_change);
                END IF;

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
--  PRODUCT CATALOG PROCEDURES (BASIC CREATE/UPDATE)
-- =============================================================================

-- Products
CREATE OR REPLACE FUNCTION create_product(p_name TEXT, p_description TEXT DEFAULT NULL)
    RETURNS BIGINT AS
$$
INSERT INTO PRODUCTS (name, description)
VALUES (p_name, p_description)
RETURNING id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION update_product(p_id BIGINT, p_name TEXT, p_description TEXT DEFAULT NULL)
    RETURNS VOID AS
$$
UPDATE PRODUCTS
SET name        = p_name,
    description = p_description
WHERE id = p_id;
$$ LANGUAGE sql;

-- Categories
CREATE OR REPLACE FUNCTION create_category(p_name TEXT, p_parent_id BIGINT DEFAULT NULL)
    RETURNS BIGINT AS
$$
INSERT INTO CATEGORIES (name, parent_id)
VALUES (p_name, p_parent_id)
RETURNING id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION update_category(p_id BIGINT, p_name TEXT, p_parent_id BIGINT DEFAULT NULL)
    RETURNS VOID AS
$$
UPDATE CATEGORIES
SET name      = p_name,
    parent_id = p_parent_id
WHERE id = p_id;
$$ LANGUAGE sql;

-- Assign/remove product categories
CREATE OR REPLACE FUNCTION assign_product_category(p_product_id BIGINT, p_category_id BIGINT)
    RETURNS VOID AS
$$
INSERT INTO PRODUCT_CATEGORIES (product_id, category_id)
VALUES (p_product_id, p_category_id);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION remove_product_category(p_product_id BIGINT, p_category_id BIGINT)
    RETURNS VOID AS
$$
DELETE
FROM PRODUCT_CATEGORIES
WHERE product_id = p_product_id
  AND category_id = p_category_id;
$$ LANGUAGE sql;

-- Attributes
CREATE OR REPLACE FUNCTION create_attribute(p_name TEXT, p_data_type TEXT, p_unit TEXT DEFAULT NULL,
                                            p_is_variant BOOLEAN DEFAULT FALSE)
    RETURNS BIGINT AS
$$
INSERT INTO ATTRIBUTES (name, data_type, unit, is_variant_attribute)
VALUES (p_name, p_data_type, p_unit, p_is_variant)
RETURNING id;
$$ LANGUAGE sql;

-- Attribute values
CREATE OR REPLACE FUNCTION add_attribute_value(p_attribute_id BIGINT, p_value TEXT)
    RETURNS BIGINT AS
$$
INSERT INTO ATTRIBUTE_VALUES (attribute_id, value)
VALUES (p_attribute_id, p_value)
RETURNING id;
$$ LANGUAGE sql;

-- Product variants
CREATE OR REPLACE FUNCTION create_product_variant(
    p_product_id BIGINT,
    p_sku TEXT,
    p_brand_id BIGINT,
    p_barcode TEXT DEFAULT NULL,
    p_price NUMERIC(10, 2) DEFAULT 20,
    p_weight NUMERIC(10, 2) DEFAULT NULL,
    p_status TEXT DEFAULT 'ACTIVE'
)
    RETURNS BIGINT AS
$$
INSERT INTO PRODUCT_VARIANTS (product_id, sku, brand_id, barcode, price, weight, status)
VALUES (p_product_id, p_sku, p_brand_id, p_barcode, p_price, p_weight, p_status)
RETURNING id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION update_product_variant(
    p_variant_id BIGINT,
    p_sku TEXT,
    p_brand_id BIGINT,
    p_barcode TEXT DEFAULT NULL,
    p_price NUMERIC(10, 2) DEFAULT 20,
    p_weight NUMERIC(10, 2) DEFAULT NULL,
    p_status TEXT DEFAULT 'ACTIVE'
)
    RETURNS VOID AS
$$
UPDATE PRODUCT_VARIANTS
SET sku      = p_sku,
    brand_id = p_brand_id,
    barcode  = p_barcode,
    price    = p_price,
    weight   = p_weight,
    status   = p_status
WHERE id = p_variant_id;
$$ LANGUAGE sql;

-- Variant attributes
CREATE OR REPLACE FUNCTION assign_variant_attribute(p_variant_id BIGINT, p_attribute_value_id BIGINT)
    RETURNS VOID AS
$$
DECLARE
    v_attribute_id BIGINT;
BEGIN
    SELECT attribute_id INTO v_attribute_id FROM ATTRIBUTE_VALUES WHERE id = p_attribute_value_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Attribute value with id % does not exist', p_attribute_value_id;
    END IF;
    INSERT INTO VARIANT_ATTRIBUTES (product_variant_id, attribute_value_id, attribute_id)
    VALUES (p_variant_id, p_attribute_value_id, v_attribute_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remove_variant_attribute(p_variant_id BIGINT, p_attribute_value_id BIGINT)
    RETURNS VOID AS
$$
DELETE
FROM VARIANT_ATTRIBUTES
WHERE product_variant_id = p_variant_id
  AND attribute_value_id = p_attribute_value_id;
$$ LANGUAGE sql;

