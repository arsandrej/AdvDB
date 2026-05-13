-- =============================================================================
-- WAREHOUSE SETUP FUNCTIONS
-- =============================================================================

-- Warehouses
CREATE
    OR REPLACE FUNCTION create_warehouse(
    p_name TEXT,
    p_address TEXT DEFAULT NULL,
    p_city TEXT,
    p_country TEXT
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
    p_city TEXT,
    p_country TEXT
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

-- =============================================================================
-- EMPLOYEE ADMINISTRATION FUNCTIONS
-- =============================================================================

-- Hire employee
CREATE
    OR REPLACE FUNCTION hire_employee(
    p_employee_number TEXT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_email TEXT,
    p_phone TEXT DEFAULT NULL,
    p_job_title TEXT,
    p_employment_status TEXT DEFAULT 'ACTIVE',
    p_hired_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    p_manager_id BIGINT DEFAULT NULL
)
    RETURNS BIGINT AS
$$
INSERT INTO EMPLOYEES (employee_number, first_name, last_name, email, phone,
                       job_title, employment_status, hired_at, manager_id)
VALUES (p_employee_number, p_first_name, p_last_name, p_email, p_phone,
        p_job_title, p_employment_status, p_hired_at, p_manager_id)
RETURNING id;
$$
    LANGUAGE sql;

-- Update basic employee info (excluding termination fields)
CREATE
    OR REPLACE FUNCTION update_employee(
    p_employee_id BIGINT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_email TEXT,
    p_phone TEXT DEFAULT NULL,
    p_job_title TEXT,
    p_employment_status TEXT,
    p_manager_id BIGINT DEFAULT NULL
)
    RETURNS VOID AS
$$
UPDATE EMPLOYEES
SET first_name        = p_first_name,
    last_name         = p_last_name,
    email             = p_email,
    phone             = p_phone,
    job_title         = p_job_title,
    employment_status = p_employment_status,
    manager_id        = p_manager_id
WHERE id = p_employee_id;
$$
    LANGUAGE sql;

-- Terminate an employee (set status and terminated_at)
CREATE
    OR REPLACE FUNCTION terminate_employee(
    p_employee_id BIGINT,
    p_terminated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
    RETURNS VOID AS
$$
UPDATE EMPLOYEES
SET employment_status = 'TERMINATED',
    terminated_at     = p_terminated_at
WHERE id = p_employee_id;
$$
    LANGUAGE sql;

-- Assign employee to a warehouse
CREATE
    OR REPLACE FUNCTION assign_employee_to_warehouse(
    p_employee_id BIGINT,
    p_warehouse_id BIGINT,
    p_start_date DATE,
    p_end_date DATE DEFAULT NULL,
    p_is_primary BOOLEAN DEFAULT FALSE,
    p_notes TEXT DEFAULT NULL
)
    RETURNS BIGINT AS
$$
INSERT INTO EMPLOYEE_WAREHOUSE_ASSIGNMENTS (employee_id, warehouse_id, start_date,
                                            end_date, is_primary, notes)
VALUES (p_employee_id, p_warehouse_id, p_start_date,
        p_end_date, p_is_primary, p_notes)
RETURNING id;
$$
    LANGUAGE sql;

-- End an assignment (set the end date)
CREATE
    OR REPLACE FUNCTION end_warehouse_assignment(
    p_assignment_id BIGINT,
    p_end_date DATE DEFAULT CURRENT_DATE
)
    RETURNS VOID AS
$$
UPDATE EMPLOYEE_WAREHOUSE_ASSIGNMENTS
SET end_date = p_end_date
WHERE id = p_assignment_id;
$$
    LANGUAGE sql;

-- Assign a role to an employee
CREATE
    OR REPLACE FUNCTION assign_role_to_employee(
    p_role_id INT,
    p_employee_id BIGINT
)
    RETURNS VOID AS
$$
INSERT INTO ROLES_EMPLOYEES (roles_id, employees_id)
VALUES (p_role_id, p_employee_id);
$$
    LANGUAGE sql;

-- Remove a role from an employee
CREATE
    OR REPLACE FUNCTION remove_role_from_employee(
    p_role_id INT,
    p_employee_id BIGINT
)
    RETURNS VOID AS
$$
DELETE
FROM ROLES_EMPLOYEES
WHERE roles_id = p_role_id
  AND employees_id = p_employee_id;
$$
    LANGUAGE sql;

-- Assign a permission to a role
CREATE
    OR REPLACE FUNCTION assign_permission_to_role(
    p_permission_id INT,
    p_role_id INT
)
    RETURNS VOID AS
$$
INSERT INTO PERMISSIONS_ROLES (permissions_id, roles_id)
VALUES (p_permission_id, p_role_id);
$$
    LANGUAGE sql;

-- Remove a permission from a role
CREATE
    OR REPLACE FUNCTION remove_permission_from_role(
    p_permission_id INT,
    p_role_id INT
)
    RETURNS VOID AS
$$
DELETE
FROM PERMISSIONS_ROLES
WHERE permissions_id = p_permission_id
  AND roles_id = p_role_id;
$$
    LANGUAGE sql;