-- =============================================================================
-- Employee Functions
-- =============================================================================

-- Hire or rehire an employee
CREATE OR REPLACE FUNCTION hire_employee(
    p_employee_number TEXT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_email TEXT,
    p_phone TEXT DEFAULT NULL,
    p_job_title TEXT DEFAULT 'Job',
    p_employment_status TEXT DEFAULT 'active',
    p_hired_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    p_manager_id BIGINT DEFAULT NULL
)
    RETURNS BIGINT AS
$$
DECLARE
    v_existing_employee_id BIGINT;
    v_status_lower         TEXT;
BEGIN
    -- Normalize status to lowercase
    v_status_lower := LOWER(TRIM(p_employment_status));
    IF v_status_lower NOT IN ('active', 'on_leave', 'terminated') THEN
        RAISE EXCEPTION 'Invalid employment_status: %. Allowed: active, on_leave, terminated', p_employment_status;
    END IF;

    -- Check manager existence and self‑management (only if manager_id provided)
    IF p_manager_id IS NOT NULL THEN
        IF p_manager_id = (SELECT id FROM employees WHERE employee_number = p_employee_number) THEN
            RAISE EXCEPTION 'Employee cannot be their own manager';
        END IF;
        PERFORM 1 FROM employees WHERE id = p_manager_id AND employment_status != 'terminated';
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Manager with id % does not exist or is terminated', p_manager_id;
        END IF;
    END IF;

    -- Check if employee already exists (by employee_number or email)
    SELECT id
    INTO v_existing_employee_id
    FROM employees
    WHERE employee_number = p_employee_number
       OR email = p_email;

    IF FOUND THEN
        -- Reactivate terminated employee
        UPDATE employees
        SET first_name        = p_first_name,
            last_name         = p_last_name,
            email             = p_email,
            phone             = p_phone,
            job_title         = p_job_title,
            employment_status = v_status_lower,
            hired_at          = p_hired_at,
            terminated_at     = NULL,
            manager_id        = p_manager_id,
            updated_at        = CURRENT_TIMESTAMP
        WHERE id = v_existing_employee_id
          AND employment_status = 'terminated';
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Employee with number % or email % already exists but is not terminated. Cannot rehire.',
                p_employee_number, p_email;
        END IF;
        RETURN v_existing_employee_id;
    ELSE
        -- Insert new employee
        INSERT INTO employees (employee_number, first_name, last_name, email, phone,
                               job_title, employment_status, hired_at, manager_id)
        VALUES (p_employee_number, p_first_name, p_last_name, p_email, p_phone,
                p_job_title, v_status_lower, p_hired_at, p_manager_id)
        RETURNING id INTO v_existing_employee_id;
        RETURN v_existing_employee_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Update basic employee info (excluding termination fields)
CREATE OR REPLACE FUNCTION update_employee(
    p_employee_id BIGINT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_email TEXT,
    p_phone TEXT DEFAULT NULL,
    p_job_title TEXT DEFAULT 'Job',
    p_employment_status TEXT DEFAULT 'active',
    p_manager_id BIGINT DEFAULT NULL
)
    RETURNS VOID AS
$$
DECLARE
    v_current_status TEXT;
    v_status_lower   TEXT;
BEGIN
    -- Get current status
    SELECT employment_status INTO v_current_status FROM employees WHERE id = p_employee_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee with id % does not exist', p_employee_id;
    END IF;

    -- Cannot update a terminated employee (except to reactivate via hire_employee)
    IF v_current_status = 'terminated' THEN
        RAISE EXCEPTION 'Cannot update a terminated employee.';
    END IF;

    -- Validate new status
    v_status_lower := LOWER(TRIM(p_employment_status));
    IF v_status_lower NOT IN ('active', 'on_leave', 'terminated') THEN
        RAISE EXCEPTION 'Invalid employment_status: %. Allowed: active, on_leave, terminated', p_employment_status;
    END IF;

    -- Manager self‑check
    IF p_manager_id IS NOT NULL AND p_manager_id = p_employee_id THEN
        RAISE EXCEPTION 'Employee cannot be their own manager';
    END IF;

    -- Update
    UPDATE employees
    SET first_name        = p_first_name,
        last_name         = p_last_name,
        email             = p_email,
        phone             = p_phone,
        job_title         = p_job_title,
        employment_status = v_status_lower,
        manager_id        = p_manager_id,
        updated_at        = CURRENT_TIMESTAMP
    WHERE id = p_employee_id;
END;
$$ LANGUAGE plpgsql;

-- Terminate an employee and close all active warehouse assignments
CREATE OR REPLACE FUNCTION terminate_employee(
    p_employee_id BIGINT,
    p_terminated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
    RETURNS VOID AS
$$
DECLARE
    v_current_status TEXT;
BEGIN
    SELECT employment_status INTO v_current_status FROM employees WHERE id = p_employee_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee with id % does not exist', p_employee_id;
    END IF;

    IF v_current_status = 'terminated' THEN
        RAISE EXCEPTION 'Employee is already terminated';
    END IF;

    -- Close all active warehouse assignments (end_date IS NULL)
    UPDATE employee_warehouse_assignments
    SET end_date = p_terminated_at::DATE
    WHERE employee_id = p_employee_id
      AND end_date IS NULL;

    -- Update employee status
    UPDATE employees
    SET employment_status = 'terminated',
        terminated_at     = p_terminated_at,
        updated_at        = CURRENT_TIMESTAMP
    WHERE id = p_employee_id;
END;
$$ LANGUAGE plpgsql;

-- Assign employee to a warehouse with overlap checks
CREATE OR REPLACE FUNCTION assign_employee_to_warehouse(
    p_employee_id BIGINT,
    p_warehouse_id BIGINT,
    p_start_date DATE,
    p_end_date DATE DEFAULT NULL,
    p_is_primary BOOLEAN DEFAULT FALSE,
    p_notes TEXT DEFAULT NULL
)
    RETURNS BIGINT AS
$$
DECLARE
    v_assignment_id   BIGINT;
    v_employee_status TEXT;
BEGIN
    -- Employee must be active or on_leave (not terminated)
    SELECT employment_status INTO v_employee_status FROM employees WHERE id = p_employee_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee % does not exist', p_employee_id;
    END IF;
    IF v_employee_status = 'terminated' THEN
        RAISE EXCEPTION 'Cannot assign a terminated employee to a warehouse';
    END IF;

    -- Start date cannot be in the past (allow same day)
    IF p_start_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Start date cannot be in the past (given: %)', p_start_date;
    END IF;

    -- Insert assignment
    INSERT INTO employee_warehouse_assignments (employee_id, warehouse_id, start_date, end_date, is_primary, notes)
    VALUES (p_employee_id, p_warehouse_id, p_start_date, p_end_date, p_is_primary, p_notes)
    RETURNING id INTO v_assignment_id;

    RETURN v_assignment_id;
END;
$$ LANGUAGE plpgsql;

-- End an assignment (with validation)
CREATE OR REPLACE FUNCTION end_warehouse_assignment(
    p_assignment_id BIGINT,
    p_end_date DATE DEFAULT CURRENT_DATE
)
    RETURNS VOID AS
$$
DECLARE
    v_start_date  DATE;
    v_current_end DATE;
BEGIN
    SELECT start_date, end_date
    INTO v_start_date, v_current_end
    FROM employee_warehouse_assignments
    WHERE id = p_assignment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Assignment with id % does not exist', p_assignment_id;
    END IF;

    IF v_current_end IS NOT NULL THEN
        RAISE EXCEPTION 'Assignment already ended on %', v_current_end;
    END IF;

    UPDATE employee_warehouse_assignments
    SET end_date = p_end_date
    WHERE id = p_assignment_id;
END;
$$ LANGUAGE plpgsql;


---===============================
--- Role & Permission Functions
---===============================
-- Assign a role to an employee
CREATE OR REPLACE FUNCTION assign_role_to_employee(
    p_role_id INT,
    p_employee_id BIGINT
)
    RETURNS VOID AS
$$
BEGIN
    -- Optional: check existence (FK would error anyway, but custom message)
    IF NOT EXISTS (SELECT 1 FROM roles WHERE id = p_role_id) THEN
        RAISE EXCEPTION 'Role with id % does not exist', p_role_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_employee_id) THEN
        RAISE EXCEPTION 'Employee with id % does not exist', p_employee_id;
    END IF;

    INSERT INTO roles_employees (roles_id, employees_id)
    VALUES (p_role_id, p_employee_id)
    ON CONFLICT DO NOTHING; -- Silently ignore duplicate
END;
$$ LANGUAGE plpgsql;

-- Remove a role from an employee
CREATE OR REPLACE FUNCTION remove_role_from_employee(
    p_role_id INT,
    p_employee_id BIGINT
)
    RETURNS VOID AS
$$
BEGIN
    DELETE
    FROM roles_employees
    WHERE roles_id = p_role_id
      AND employees_id = p_employee_id;
    IF NOT FOUND THEN
        RAISE NOTICE 'Role % was not assigned to employee %', p_role_id, p_employee_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Assign a permission to a role
CREATE OR REPLACE FUNCTION assign_permission_to_role(
    p_permission_id INT,
    p_role_id INT
)
    RETURNS VOID AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM permissions WHERE id = p_permission_id) THEN
        RAISE EXCEPTION 'Permission with id % does not exist', p_permission_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM roles WHERE id = p_role_id) THEN
        RAISE EXCEPTION 'Role with id % does not exist', p_role_id;
    END IF;

    INSERT INTO permissions_roles (permissions_id, roles_id)
    VALUES (p_permission_id, p_role_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Remove a permission from a role
CREATE OR REPLACE FUNCTION remove_permission_from_role(
    p_permission_id INT,
    p_role_id INT
)
RETURNS VOID AS $$
BEGIN
    DELETE FROM permissions_roles
    WHERE permissions_id = p_permission_id AND roles_id = p_role_id;
    IF NOT FOUND THEN
        RAISE NOTICE 'Permission % was not assigned to role %', p_permission_id, p_role_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Warehouse Functions
-- =============================================================================

-- Warehouses
CREATE
    OR REPLACE FUNCTION create_warehouse(
    p_name TEXT,
    p_address TEXT DEFAULT NULL,
    p_city TEXT DEFAULT 'C',
    p_country TEXT DEFAULT 'C'
)
    RETURNS BIGINT AS
$$
INSERT INTO WAREHOUSES (name, address, city, country)
VALUES (p_name, p_address, p_city, p_country)
RETURNING id;
$$
    LANGUAGE sql;

CREATE
    OR REPLACE FUNCTION update_warehouse(
    p_id BIGINT,
    p_name TEXT,
    p_address TEXT DEFAULT NULL,
    p_city TEXT DEFAULT 'C',
    p_country TEXT DEFAULT 'C'
)
    RETURNS VOID AS
$$
UPDATE WAREHOUSES
SET name    = p_name,
    address = p_address,
    city    = p_city,
    country = p_country
WHERE id = p_id;
$$
    LANGUAGE sql;

-- Sections
CREATE
    OR REPLACE FUNCTION create_section(
    p_warehouse_id BIGINT,
    p_name TEXT,
    p_description TEXT DEFAULT NULL
)
    RETURNS BIGINT AS
$$
INSERT INTO SECTIONS (warehouse_id, name, description)
VALUES (p_warehouse_id, p_name, p_description)
RETURNING id;
$$
    LANGUAGE sql;

CREATE
    OR REPLACE FUNCTION update_section(
    p_id BIGINT,
    p_name TEXT,
    p_description TEXT DEFAULT NULL
)
    RETURNS VOID AS
$$
UPDATE SECTIONS
SET name        = p_name,
    description = p_description
WHERE id = p_id;
$$
    LANGUAGE sql;

-- Locations
CREATE
    OR REPLACE FUNCTION create_location(
    p_section_id BIGINT,
    p_row_number INT,
    p_column_number INT,
    p_level_number INT,
    p_location_code TEXT
)
    RETURNS BIGINT AS
$$
INSERT INTO LOCATIONS (section_id, row_number, column_number, level_number, location_code)
VALUES (p_section_id, p_row_number, p_column_number, p_level_number, p_location_code)
RETURNING id;
$$
    LANGUAGE sql;

CREATE
    OR REPLACE FUNCTION update_location(
    p_id BIGINT,
    p_row_number INT,
    p_column_number INT,
    p_level_number INT,
    p_location_code TEXT
)
    RETURNS VOID AS
$$
UPDATE LOCATIONS
SET row_number    = p_row_number,
    column_number = p_column_number,
    level_number  = p_level_number,
    location_code = p_location_code
WHERE id = p_id;
$$
    LANGUAGE sql;

-- Bins
CREATE
    OR REPLACE FUNCTION create_bin(
    p_location_id BIGINT,
    p_bin_code TEXT,
    p_capacity INT
)
    RETURNS BIGINT AS
$$
INSERT INTO BINS (location_id, bin_code, capacity)
VALUES (p_location_id, p_bin_code, p_capacity)
RETURNING id;
$$
    LANGUAGE sql;

CREATE
    OR REPLACE FUNCTION update_bin(
    p_id BIGINT,
    p_bin_code TEXT,
    p_capacity INT
)
    RETURNS VOID AS
$$
UPDATE BINS
SET bin_code = p_bin_code,
    capacity = p_capacity
WHERE id = p_id;
$$
    LANGUAGE sql;
