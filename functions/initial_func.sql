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
-- 6. PRODUCT CATALOG PROCEDURES (BASIC CREATE/UPDATE)
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


-- ====================================================================
-- ====================================================================
-- Sets variant status
-- ====================================================================
CREATE OR REPLACE PROCEDURE set_variant_status(
    p_variant_id BIGINT,
    p_new_status VARCHAR(50)
)
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_current_status VARCHAR(50);
    v_sku            VARCHAR(63);
    v_reserved_bins  INT;
BEGIN
    -- Validate status value
    IF p_new_status NOT IN ('active', 'pre-order', 'discontinued') THEN
        RAISE EXCEPTION
            'Invalid status "%". Must be "active", "pre-order", or "discontinued".',
            p_new_status;
    END IF;

    -- Check variant exists
    SELECT status, sku
    INTO v_current_status, v_sku
    FROM PRODUCT_VARIANTS
    WHERE id = p_variant_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Variant with id=% does not exist', p_variant_id;
    END IF;

    -- Already at requested status — nothing to do
    IF v_current_status = p_new_status THEN
        RAISE NOTICE 'Variant id=% (sku=%) is already "%" — no change made',
            p_variant_id, v_sku, p_new_status;
        RETURN;
    END IF;

    -- Update the status
    UPDATE PRODUCT_VARIANTS
    SET status = p_new_status
    WHERE id = p_variant_id;

    -- If discontinuing, clear reserved_quantity across all bins
    -- Reserved stock can't be fulfilled on a discontinued item
    IF p_new_status = 'discontinued' THEN
        SELECT COUNT(*)
        INTO v_reserved_bins
        FROM INVENTORY
        WHERE product_variant_id = p_variant_id
          AND reserved_quantity > 0;

        IF v_reserved_bins > 0 THEN
            UPDATE INVENTORY
            SET reserved_quantity = 0,
                updated_at        = CURRENT_TIMESTAMP
            WHERE product_variant_id = p_variant_id
              AND reserved_quantity > 0;

            RAISE NOTICE 'Cleared reserved_quantity in % bin(s) for variant id=% (sku=%)',
                v_reserved_bins, p_variant_id, v_sku;
        END IF;
    END IF;

    RAISE NOTICE 'Status of variant id=% (sku=%) has changed from "%" to "%"',
        p_variant_id, v_sku, v_current_status, p_new_status;
END;
$$;

-- ====================================================================
-- ======= Procedure for soft delete/discontinue product ==============
-- ==== Changes status to discontinued on all variants of a product ===
-- ====================================================================
--TODO: nema potreba od ova
CREATE OR REPLACE PROCEDURE discontinue_product(
    p_product_id BIGINT
)
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_product_name   VARCHAR(63);
    v_total_variants INT;
    v_already_disc   INT;
    v_variant_id     BIGINT;
BEGIN
    -- Check product exists
    SELECT name
    INTO v_product_name
    FROM PRODUCTS
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product with id=% does not exist', p_product_id;
    END IF;

    -- Count variants and variants that are already discontinued
    SELECT COUNT(*),
           COUNT(*) FILTER (WHERE status = 'discontinued')
    INTO v_total_variants, v_already_disc
    FROM PRODUCT_VARIANTS
    WHERE product_id = p_product_id;

    IF v_total_variants = 0 THEN
        RAISE NOTICE 'Product id=% (%) has no variants — nothing to discontinue',
            p_product_id, v_product_name;
        RETURN;
    END IF;

    IF v_total_variants = v_already_disc THEN
        RAISE NOTICE 'Product id=% (%) — all % variant(s) already discontinued — no change made',
            p_product_id, v_product_name, v_total_variants;
        RETURN;
    END IF;

    -- Call discontinue_variant for each active variant for our product
    -- clearing logic is reused and notices are raised per variant
    FOR v_variant_id IN
        SELECT id
        FROM PRODUCT_VARIANTS
        WHERE product_id = p_product_id
          AND status <> 'discontinued'
        LOOP
            CALL set_variant_status(v_variant_id, 'discontinued');
        END LOOP;

    RAISE NOTICE 'Product id=% ("%") — % of % variant(s) discontinued (% were already discontinued)',
        p_product_id, v_product_name,
        v_total_variants - v_already_disc,
        v_total_variants,
        v_already_disc;
END;
$$;


-- =========================================================================
-- === Trigger that blocks inventory movements on discontinued variants ===
-- =========================================================================
-- ========== trigger block discontinued movements
-- ==========================================================================
--TODO: dali sakame sepak da pravime movements na discontinued product variant
CREATE OR REPLACE FUNCTION fn_block_discontinued_movement()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_status VARCHAR(50);
    v_sku    VARCHAR(63);
BEGIN
    SELECT status, sku
    INTO v_status, v_sku
    FROM PRODUCT_VARIANTS
    WHERE id = NEW.product_variant_id;

    IF v_status = 'discontinued' THEN
        RAISE EXCEPTION
            'Cannot record movement for discontinued variant id=% (sku=%). '
                'Reactivate the variant first if this movement is intentional.',
            NEW.product_variant_id, v_sku;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_discontinued_movement ON INVENTORY_MOVEMENTS;

CREATE TRIGGER trg_block_discontinued_movement
    BEFORE INSERT
    ON INVENTORY_MOVEMENTS
    FOR EACH ROW
EXECUTE FUNCTION fn_block_discontinued_movement();

