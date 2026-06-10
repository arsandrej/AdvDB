INSERT INTO TRANSACTION_TYPES (code, description)
VALUES
    ('RECEIPT', 'Stock receipt'),
    ('SHIPMENT', 'Customer shipment'),
    ('TRANSFER', 'Internal transfer'),
    ('ADJUSTMENT', 'Manual adjustment');



-- Warehouse
INSERT INTO WAREHOUSES (name, address, city, country)
VALUES ('Main Warehouse', 'Street 1', 'Skopje', 'MK');

-- Section
INSERT INTO SECTIONS (warehouse_id, name, description)
VALUES (1, 'Section A', 'Main section');

-- Location
INSERT INTO LOCATIONS (section_id, row_number, column_number, level_number, location_code)
VALUES (1, 1, 1, 1, 'LOC-A-1');

-- Bins
INSERT INTO BINS (location_id, bin_code, capacity)
VALUES
    (1, 'BIN-A-1', 100),
    (1, 'BIN-A-2', 100),
    (1, 'BIN-B-1', 100);


INSERT INTO EMPLOYEES (
    employee_number,
    first_name,
    last_name,
    email,
    job_title,
    employment_status,
    hired_at
)
VALUES
    ('E001','Alice','Manager','alice@company.com','Manager','ACTIVE',NOW()),
    ('E002','Bob','Operator','bob@company.com','Worker','ACTIVE',NOW());

INSERT INTO BRANDS (name)
VALUES ('Acme'), ('Globex');

INSERT INTO PRODUCTS (name, description)
VALUES ('Laptop', 'Gaming laptop'),
       ('Mouse', 'Wireless mouse');

INSERT INTO PRODUCT_VARIANTS (product_id, sku, brand_id, barcode, price, weight, status)
VALUES
    (1, 'LAP-001', 1, '111111', 1200.00, 2.5, 'ACTIVE'),
    (2, 'MOU-001', 2, '222222', 25.00, 0.2, 'ACTIVE');


INSERT INTO INVENTORY (product_variant_id, bin_id, quantity, reserved_quantity, status)
VALUES
    (1, 1, 10, 0, 'AVAILABLE'),
    (2, 1, 50, 0, 'AVAILABLE');


DO $$
    DECLARE v_tx BIGINT;
    BEGIN
        v_tx := receive_delivery(
                'Supplier Inc',
                'DN-001',
                1,
                ARRAY[
                    ROW(1, NULL, 2, 5)::movement_item,
                    ROW(2, NULL, 2, 10)::movement_item
                    ]
                );

        RAISE NOTICE 'RECEIPT TX: %', v_tx;
    END $$;

DO $$
    DECLARE v_tx BIGINT;
    BEGIN
        v_tx := ship_stock(
                'Customer Berlin',
                10001,
                2,
                ARRAY[
                    ROW(1, 1, NULL, 3)::movement_item,
                    ROW(2, 1, NULL, 5)::movement_item
                    ]
                );

        RAISE NOTICE 'SHIPMENT TX: %', v_tx;
    END $$;

DO $$
    BEGIN
        call pack_shipment(
                5,2
                );

    END $$;



DO $$
    DECLARE v_tx BIGINT;
    BEGIN
        v_tx := transfer_stock(
                2,
                ARRAY[
                    ROW(1, 1, 3, 2)::movement_item
                    ]
                );

        RAISE NOTICE 'TRANSFER TX: %', v_tx;
    END $$;

DO $$
    DECLARE v_tx BIGINT;
    BEGIN
        v_tx := adjust_inventory(
                1,
                'Damage correction',
                ARRAY[
                    ROW(2, 1, -5)::adjustment_item,
                    ROW(1, 1, 3)::adjustment_item
                    ]
                );

        RAISE NOTICE 'ADJUSTMENT TX: %', v_tx;
    END $$;

DO $$
    DECLARE r RECORD;
    BEGIN
        FOR r IN
            SELECT id FROM INVENTORY_TRANSACTIONS WHERE status = 'PENDING' ORDER BY id
            LOOP
                CALL approve_inventory_transaction(r.id, 1);
                RAISE NOTICE 'APPROVED TX %', r.id;
            END LOOP;
    END $$;

DO $$
    DECLARE r RECORD;
    BEGIN
        SELECT id INTO r
        FROM INVENTORY_TRANSACTIONS
        WHERE status = 'PENDING'
        ORDER BY id DESC
        LIMIT 1;

        IF r.id IS NOT NULL THEN
            CALL cancel_pending_transaction(r.id, 2);
            RAISE NOTICE 'CANCELLED TX %', r.id;
        END IF;
    END $$;

SELECT * FROM INVENTORY ORDER BY product_variant_id, bin_id;

SELECT * FROM INVENTORY_TRANSACTIONS ORDER BY id;

SELECT * FROM INVENTORY_MOVEMENTS ORDER BY id;





























-- =============================================================================
-- SAMPLE USAGE OF ALL PROCEDURES & FUNCTIONS (using dummy data)
-- =============================================================================

-- 1. Insert basic reference data
INSERT INTO BRANDS (name)
VALUES ('brand1')
ON CONFLICT (name) DO NOTHING;

-- 2. Product catalog: create a product, a variant, categories, attributes
-- Product
SELECT create_product('product1', 'Description of product1') AS new_product_id;
-- returns ID

-- We'll store the product ID in a variable for later use (or look it up)
DO
$$
    DECLARE
        v_product_id BIGINT;
    BEGIN
        v_product_id := create_product('product2', 'Second product for testing');
        RAISE NOTICE 'Created product2 with id %', v_product_id;
    END
$$;

-- For simplicity, we use a specific product ID = 1 (assuming sequence starting at 1)
-- Let's work with product ID returned from first create. In a real test, you can capture it.
-- We'll assume product_id = 1 after the first insert.
-- But we can just use a hardcoded ID if it's a test with no prior data:
-- We'll use (SELECT id FROM PRODUCTS WHERE name = 'product1') as a reliable way.

-- Variant
SELECT create_product_variant(
               (SELECT id FROM PRODUCTS WHERE name = 'product1'),
               'sku1',
               (SELECT id FROM BRANDS WHERE name = 'brand1'),
               'barcode1',
               99.99,
               0.5,
               'ACTIVE'
       ) AS variant1_id;

-- Categories (parent/child for depth)
SELECT create_category('category1', NULL) AS cat1_id;
SELECT create_category('category2', (SELECT id FROM CATEGORIES WHERE name = 'category1')) AS cat2_id;

-- Assign product to categories
SELECT assign_product_category((SELECT id FROM PRODUCTS WHERE name = 'product1'),
                               (SELECT id FROM CATEGORIES WHERE name = 'category1'));
SELECT assign_product_category((SELECT id FROM PRODUCTS WHERE name = 'product1'),
                               (SELECT id FROM CATEGORIES WHERE name = 'category2'));

-- Attributes and values
SELECT create_attribute('attribute1', 'varchar', 'kg', false) AS attr1_id;
SELECT create_attribute('attribute2', 'numeric', NULL, true) AS attr2_id;

SELECT add_attribute_value((SELECT id FROM ATTRIBUTES WHERE name = 'attribute1'), 'value1') AS val1_id;
SELECT add_attribute_value((SELECT id FROM ATTRIBUTES WHERE name = 'attribute1'), 'value2') AS val2_id;
SELECT add_attribute_value((SELECT id FROM ATTRIBUTES WHERE name = 'attribute2'), '100') AS val3_id;

-- Assign attribute values to variant
SELECT assign_variant_attribute(
               (SELECT id FROM PRODUCT_VARIANTS WHERE sku = 'sku1'),
               (SELECT id FROM ATTRIBUTE_VALUES WHERE value = 'value1')
       );
SELECT assign_variant_attribute(
               (SELECT id FROM PRODUCT_VARIANTS WHERE sku = 'sku1'),
               (SELECT id FROM ATTRIBUTE_VALUES WHERE value = '100')
       );

-- 3. Warehouse setup: warehouse, section, location, bins
INSERT INTO WAREHOUSES (name, city, country)
VALUES ('warehouse1', 'city1', 'country1');
INSERT INTO SECTIONS (warehouse_id, name)
VALUES ((SELECT id FROM WAREHOUSES WHERE name = 'warehouse1'), 'section1');
INSERT INTO LOCATIONS (section_id, row_number, column_number, level_number, location_code)
VALUES ((SELECT id FROM SECTIONS WHERE name = 'section1'), 1, 1, 1, 'loc-1-1-1');
INSERT INTO BINS (location_id, bin_code, capacity)
VALUES ((SELECT id FROM LOCATIONS WHERE location_code = 'loc-1-1-1'), 'bin1', 100);
INSERT INTO BINS (location_id, bin_code, capacity)
VALUES ((SELECT id FROM LOCATIONS WHERE location_code = 'loc-1-1-1'), 'bin2', 200);

-- 4. Employee (needed for created_by_employee)
INSERT INTO EMPLOYEES (employee_number, first_name, last_name, email, job_title, employment_status, hired_at)
VALUES ('EMP001', 'John', 'Doe', 'john.doe@example.com', 'Warehouse Worker', 'ACTIVE', '2024-01-01');

-- 5. Inventory operations

-- 5a. Receive delivery into bin1
DO
$$
    DECLARE
        v_txn_id     BIGINT;
        v_variant_id BIGINT;
        v_bin1_id    BIGINT;
        v_emp_id     BIGINT;
    BEGIN
        SELECT id INTO v_variant_id FROM PRODUCT_VARIANTS WHERE sku = 'sku1';
        SELECT id INTO v_bin1_id FROM BINS WHERE bin_code = 'bin1';
        SELECT id INTO v_emp_id FROM EMPLOYEES WHERE employee_number = 'EMP001';

        v_txn_id := receive_delivery(
                'Supplier Co.',
                'Delivery note 001',
                v_emp_id,
                ARRAY [
                    (v_variant_id, NULL::BIGINT, v_bin1_id, 50)::movement_item
                    ]
                    );
        RAISE NOTICE 'Receipt transaction ID: %', v_txn_id;
    END
$$;

-- Check inventory after receipt
SELECT product_variant_id, bin_id, quantity
FROM INVENTORY;

-- 5b. Transfer stock from bin1 to bin2
DO
$$
    DECLARE
        v_txn_id     BIGINT;
        v_variant_id BIGINT;
        v_bin1_id    BIGINT;
        v_bin2_id    BIGINT;
        v_emp_id     BIGINT;
    BEGIN
        SELECT id INTO v_variant_id FROM PRODUCT_VARIANTS WHERE sku = 'sku1';
        SELECT id INTO v_bin1_id FROM BINS WHERE bin_code = 'bin1';
        SELECT id INTO v_bin2_id FROM BINS WHERE bin_code = 'bin2';
        SELECT id INTO v_emp_id FROM EMPLOYEES WHERE employee_number = 'EMP001';

        v_txn_id := transfer_stock(
                v_emp_id,
                ARRAY [
                    (v_variant_id, v_bin1_id, v_bin2_id, 20)::movement_item
                    ]
                    );
        RAISE NOTICE 'Transfer transaction ID: %', v_txn_id;
    END
$$;

-- Check inventory after transfer
SELECT product_variant_id, bin_id, quantity
FROM INVENTORY;

-- 5c. Ship stock out of bin2
DO
$$
    DECLARE
        v_txn_id     BIGINT;
        v_variant_id BIGINT;
        v_bin2_id    BIGINT;
        v_emp_id     BIGINT;
    BEGIN
        SELECT id INTO v_variant_id FROM PRODUCT_VARIANTS WHERE sku = 'sku1';
        SELECT id INTO v_bin2_id FROM BINS WHERE bin_code = 'bin2';
        SELECT id INTO v_emp_id FROM EMPLOYEES WHERE employee_number = 'EMP001';

        v_txn_id := ship_stock(
                '123 Customer St, City',
                1001,
                v_emp_id,
                ARRAY [
                    (v_variant_id, v_bin2_id, NULL::BIGINT, 10)::movement_item
                    ]
                    );
        RAISE NOTICE 'Shipment transaction ID: %', v_txn_id;
    END
$$;

-- Check inventory after shipment
SELECT product_variant_id, bin_id, quantity
FROM INVENTORY;

-- 5d. Manual adjustment (add 5 to bin1, remove 2 from bin2)
DO
$$
    DECLARE
        v_txn_id     BIGINT;
        v_variant_id BIGINT;
        v_bin1_id    BIGINT;
        v_bin2_id    BIGINT;
        v_emp_id     BIGINT;
    BEGIN
        SELECT id INTO v_variant_id FROM PRODUCT_VARIANTS WHERE sku = 'sku1';
        SELECT id INTO v_bin1_id FROM BINS WHERE bin_code = 'bin1';
        SELECT id INTO v_bin2_id FROM BINS WHERE bin_code = 'bin2';
        SELECT id INTO v_emp_id FROM EMPLOYEES WHERE employee_number = 'EMP001';

        v_txn_id := adjust_inventory(
                v_emp_id,
                'Cycle count correction',
                ARRAY [
                    (v_variant_id, v_bin1_id, 5)::adjustment_item, -- add 5
                    (v_variant_id, v_bin2_id, -2)::adjustment_item -- subtract 2
                    ]
                    );
        RAISE NOTICE 'Adjustment transaction ID: %', v_txn_id;
    END
$$;

-- Final inventory state
SELECT product_variant_id, bin_id, quantity
FROM INVENTORY;

-- (Optional) Demonstrate insufficient stock validation:
-- DO $$
-- BEGIN
--     PERFORM transfer_stock(
--         (SELECT id FROM EMPLOYEES WHERE employee_number = 'EMP001'),
--         ARRAY[
--             ( (SELECT id FROM PRODUCT_VARIANTS WHERE sku = 'sku1'),
--               (SELECT id FROM BINS WHERE bin_code = 'bin2'),
--               (SELECT id FROM BINS WHERE bin_code = 'bin1'),
--               100 )::movement_item   -- too much
--         ]
--     );
-- EXCEPTION WHEN OTHERS THEN
--     RAISE NOTICE 'Expected error: %', SQLERRM;
-- END $$;