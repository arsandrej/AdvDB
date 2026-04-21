-- =============================================================================
-- SEED SCRIPT: employees, roles, permissions, permissions_roles, roles_employees
-- =============================================================================
-- Prerequisites:
--   Place the four csv files next to this script (or adjust paths below):
--     employees_raw.csv  |  job_titles.csv  |  roles.csv  |  permissions.csv
--
-- Run with:
--   psql -U <user> -d <database> -f seed_employees_roles.sql
--
-- All logic is set-based — no row-by-row loops.
-- Adjust the path prefix in the COPY commands if your files live elsewhere.
-- =============================================================================

\set csv_dir '../csv'

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. STAGING TABLES
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE stg_names (
    first_name VARCHAR(63),
    last_name  VARCHAR(63)
);

CREATE TEMP TABLE stg_job_titles (
    job_title         VARCHAR(63),
    employment_status VARCHAR(63)
);

CREATE TEMP TABLE stg_roles (
    name        TEXT,
    description TEXT
);

CREATE TEMP TABLE stg_permissions (
    name        TEXT,
    description TEXT
);

-- ---------------------------------------------------------------------------
-- 2. LOAD CSVs INTO STAGING TABLES
-- ---------------------------------------------------------------------------
\copy stg_names        FROM :'csv_dir'/employees_raw.csv CSV HEADER
\copy stg_job_titles   FROM :'csv_dir'/job_titles.csv    CSV HEADER
\copy stg_roles        FROM :'csv_dir'/roles.csv         CSV HEADER
\copy stg_permissions  FROM :'csv_dir'/permissions.csv   CSV HEADER


-- ---------------------------------------------------------------------------
-- 3. ROLES
-- ---------------------------------------------------------------------------

INSERT INTO ROLES (name, description)
SELECT name, description
FROM   stg_roles
ON CONFLICT (name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. PERMISSIONS
-- ---------------------------------------------------------------------------

INSERT INTO PERMISSIONS (name, description)
SELECT name, description
FROM   stg_permissions
ON CONFLICT (name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. PERMISSIONS_ROLES
--    Assign permissions to roles based on a logical access matrix.
--    Each role gets a specific, curated set of permissions.
-- ---------------------------------------------------------------------------

INSERT INTO PERMISSIONS_ROLES (permissions_id, roles_id)
SELECT p.id, r.id
FROM   ROLES r
JOIN   PERMISSIONS p ON TRUE  -- explicit matrix below
WHERE (
    -- Admin: everything
    (r.name = 'Admin')

    -- Warehouse Manager: all ops except system config and permission editing
    OR (r.name = 'Warehouse Manager' AND p.name IN (
        'inventory.view','inventory.edit','inventory.reserve',
        'products.view','products.edit',
        'warehouses.view','warehouses.edit',
        'employees.view','employees.edit',
        'transactions.view','transactions.create','transactions.approve',
        'shipments.view','shipments.create','shipments.edit',
        'deliveries.view','deliveries.create','deliveries.edit',
        'roles.view','reports.view','reports.export','audit.view'
    ))

    -- Operations Supervisor: daily ops, approvals, no destructive actions
    OR (r.name = 'Operations Supervisor' AND p.name IN (
        'inventory.view','inventory.edit','inventory.reserve',
        'products.view',
        'warehouses.view',
        'employees.view',
        'transactions.view','transactions.create','transactions.approve',
        'shipments.view','shipments.create','shipments.edit',
        'deliveries.view','deliveries.create','deliveries.edit',
        'reports.view','reports.export'
    ))

    -- Inventory Analyst: inventory + products read/write, reporting
    OR (r.name = 'Inventory Analyst' AND p.name IN (
        'inventory.view','inventory.edit','inventory.reserve',
        'products.view','products.edit',
        'warehouses.view',
        'transactions.view','transactions.create',
        'reports.view','reports.export','audit.view'
    ))

    -- Receiving Clerk: deliveries and incoming inventory
    OR (r.name = 'Receiving Clerk' AND p.name IN (
        'inventory.view','inventory.edit',
        'products.view',
        'warehouses.view',
        'transactions.view','transactions.create',
        'deliveries.view','deliveries.create','deliveries.edit',
        'reports.view'
    ))

    -- Shipping Coordinator: outbound shipments and reservations
    OR (r.name = 'Shipping Coordinator' AND p.name IN (
        'inventory.view','inventory.reserve',
        'products.view',
        'warehouses.view',
        'transactions.view','transactions.create',
        'shipments.view','shipments.create','shipments.edit',
        'reports.view'
    ))

    -- Forklift Operator: location/bin visibility + movement recording
    OR (r.name = 'Forklift Operator' AND p.name IN (
        'inventory.view',
        'products.view',
        'warehouses.view',
        'transactions.view','transactions.create'
    ))

    -- Quality Inspector: view + quarantine (edit status) + flag issues
    OR (r.name = 'Quality Inspector' AND p.name IN (
        'inventory.view','inventory.edit',
        'products.view',
        'warehouses.view',
        'transactions.view',
        'reports.view'
    ))

    -- Procurement Officer: suppliers, deliveries, products
    OR (r.name = 'Procurement Officer' AND p.name IN (
        'inventory.view',
        'products.view','products.edit',
        'warehouses.view',
        'transactions.view','transactions.create',
        'deliveries.view','deliveries.create','deliveries.edit',
        'reports.view','reports.export'
    ))

    -- HR Coordinator: employee and assignment management
    OR (r.name = 'HR Coordinator' AND p.name IN (
        'employees.view','employees.edit','employees.delete',
        'roles.view','roles.assign',
        'warehouses.view',
        'reports.view'
    ))

    -- Auditor: read-only everywhere, export, audit logs
    OR (r.name = 'Auditor' AND p.name IN (
        'inventory.view',
        'products.view',
        'warehouses.view',
        'employees.view',
        'transactions.view',
        'shipments.view',
        'deliveries.view',
        'roles.view',
        'permissions.view',
        'reports.view','reports.export','audit.view'
    ))

    -- IT Support: system config, user/role management, no business data writes
    OR (r.name = 'IT Support' AND p.name IN (
        'employees.view','employees.edit',
        'roles.view','roles.edit','roles.assign',
        'permissions.view','permissions.edit',
        'system.configure',
        'reports.view','audit.view'
    ))
)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. EMPLOYEES
--    Combine names × job_titles with deterministic but varied assignment.
--    Produces ~100 employees (one per name row).
--    Managers are assigned from the first 12 employees (senior staff).
-- ---------------------------------------------------------------------------

INSERT INTO EMPLOYEES (
    employee_number,
    first_name,
    last_name,
    email,
    phone,
    job_title,
    employment_status,
    hired_at,
    terminated_at,
    manager_id
)
WITH

-- Number every name row 1..N
numbered_names AS (
    SELECT
        first_name,
        last_name,
        ROW_NUMBER() OVER (ORDER BY last_name, first_name) AS rn
    FROM stg_names
),

-- Number every job row 1..M
numbered_jobs AS (
    SELECT
        job_title,
        employment_status,
        ROW_NUMBER() OVER (ORDER BY employment_status DESC, job_title) AS rn
    FROM stg_job_titles
),

-- Total job rows so we can wrap-around
job_count AS (
    SELECT COUNT(*) AS cnt FROM stg_job_titles
),

-- Pair each name with a job (cycling through jobs if there are more names)
combined AS (
    SELECT
        n.first_name,
        n.last_name,
        n.rn,
        j.job_title,
        j.employment_status
    FROM   numbered_names   n
    JOIN   numbered_jobs    j ON j.rn = ((n.rn - 1) % (SELECT cnt FROM job_count)) + 1
),

-- Build hire dates spread over the last 8 years
with_dates AS (
    SELECT
        *,
        -- Spread hire dates: oldest employees hired ~8 years ago, newest ~1 month ago
        CURRENT_TIMESTAMP
            - (( (rn::numeric / (SELECT COUNT(*) FROM stg_names)) * 365 * 8 )
               || ' days')::INTERVAL  AS hired_at,
        CASE
            WHEN employment_status = 'terminated'
            THEN CURRENT_TIMESTAMP
                 - (( (rn::numeric / (SELECT COUNT(*) FROM stg_names)) * 365 * 2 )
                    || ' days')::INTERVAL
            ELSE NULL
        END AS terminated_at
    FROM combined
)

SELECT
    -- employee_number: EMP-000001 … EMP-000NNN
    'EMP-' || LPAD(rn::text, 6, '0')                        AS employee_number,
    first_name,
    last_name,
    -- email: firstname.lastname+rn@company.com (rn ensures uniqueness)
    LOWER(first_name) || '.' || LOWER(last_name)
        || rn::text || '@warehouseco.com'                    AS email,
    -- phone: simple pattern +1-555-XXXXXX
    '+1-555-' || LPAD((100000 + rn * 97 % 900000)::text, 6, '0') AS phone,
    job_title,
    employment_status,
    hired_at,
    terminated_at,
    -- Assign manager: employees 1-12 are top-level (no manager).
    -- Everyone else gets a manager from the first 12.
    CASE
        WHEN rn <= 12 THEN NULL
        ELSE (
            SELECT id FROM EMPLOYEES
            WHERE employee_number = 'EMP-' || LPAD(((rn % 12) + 1)::text, 6, '0')
        )
    END                                                      AS manager_id
FROM with_dates
ORDER BY rn;

-- ---------------------------------------------------------------------------
-- 7. ROLES_EMPLOYEES
--    Assign 1-3 roles per employee.
--    Role assignment mirrors job title — uses modular arithmetic so the
--    distribution is deterministic and realistic without any loops.
-- ---------------------------------------------------------------------------

INSERT INTO ROLES_EMPLOYEES (roles_id, employees_id)

WITH

-- Tag each employee with a numeric position for modular arithmetic
emp_numbered AS (
    SELECT
        id,
        job_title,
        ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM EMPLOYEES
),

-- Map job titles to a primary role name
primary_role AS (
    SELECT
        e.id          AS employee_id,
        e.rn,
        e.job_title,
        r.id          AS role_id,
        r.name        AS role_name,
        1             AS slot
    FROM emp_numbered e
    JOIN ROLES r ON r.name = CASE e.job_title
        WHEN 'Warehouse Manager'          THEN 'Warehouse Manager'
        WHEN 'Assistant Warehouse Manager' THEN 'Warehouse Manager'
        WHEN 'Operations Supervisor'      THEN 'Operations Supervisor'
        WHEN 'Inventory Specialist'       THEN 'Inventory Analyst'
        WHEN 'Inventory Control Manager'  THEN 'Inventory Analyst'
        WHEN 'Senior Inventory Analyst'   THEN 'Inventory Analyst'
        WHEN 'Receiving Clerk'            THEN 'Receiving Clerk'
        WHEN 'Shipping Coordinator'       THEN 'Shipping Coordinator'
        WHEN 'Dispatch Coordinator'       THEN 'Shipping Coordinator'
        WHEN 'Forklift Operator'          THEN 'Forklift Operator'
        WHEN 'Loading Dock Supervisor'    THEN 'Forklift Operator'
        WHEN 'Quality Control Inspector'  THEN 'Quality Inspector'
        WHEN 'Logistics Coordinator'      THEN 'Operations Supervisor'
        WHEN 'Procurement Officer'        THEN 'Procurement Officer'
        WHEN 'Supply Chain Analyst'       THEN 'Procurement Officer'
        WHEN 'HR Coordinator'             THEN 'HR Coordinator'
        WHEN 'IT Support Technician'      THEN 'IT Support'
        WHEN 'Data Entry Clerk'           THEN 'Inventory Analyst'
        WHEN 'Packing Specialist'         THEN 'Shipping Coordinator'
        WHEN 'Returns Processor'          THEN 'Receiving Clerk'
        WHEN 'Stock Associate'            THEN 'Forklift Operator'
        WHEN 'Warehouse Associate'        THEN 'Forklift Operator'
        WHEN 'Warehouse Supervisor'       THEN 'Operations Supervisor'
        WHEN 'Fleet Coordinator'          THEN 'Shipping Coordinator'
        WHEN 'Safety Officer'             THEN 'Auditor'
        ELSE 'Inventory Analyst'  -- fallback
    END
),

-- Every 5th employee also gets the Auditor role (cross-functional read access)
auditor_extra AS (
    SELECT
        e.id   AS employee_id,
        e.rn,
        e.job_title,
        r.id   AS role_id,
        r.name AS role_name,
        2      AS slot
    FROM   emp_numbered e
    JOIN   ROLES r ON r.name = 'Auditor'
    JOIN   primary_role pr ON pr.employee_id = e.id AND pr.role_name <> 'Auditor'
    WHERE  e.rn % 5 = 0
),

-- Senior staff (rn <= 12, i.e. managers / supervisors) also get Warehouse Manager
senior_manager_extra AS (
    SELECT
        e.id   AS employee_id,
        e.rn,
        e.job_title,
        r.id   AS role_id,
        r.name AS role_name,
        3      AS slot
    FROM   emp_numbered e
    JOIN   ROLES r ON r.name = 'Warehouse Manager'
    JOIN   primary_role pr ON pr.employee_id = e.id AND pr.role_name <> 'Warehouse Manager'
    WHERE  e.rn <= 12
),

all_assignments AS (
    SELECT employee_id, role_id FROM primary_role
    UNION
    SELECT employee_id, role_id FROM auditor_extra
    UNION
    SELECT employee_id, role_id FROM senior_manager_extra
)

SELECT role_id, employee_id
FROM   all_assignments
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 8. CLEANUP
-- ---------------------------------------------------------------------------

DROP TABLE stg_names;
DROP TABLE stg_job_titles;
DROP TABLE stg_roles;
DROP TABLE stg_permissions;

COMMIT;

-- Quick sanity check counts
SELECT 'EMPLOYEES'        AS tbl, COUNT(*) AS rows FROM EMPLOYEES
UNION ALL
SELECT 'ROLES',                   COUNT(*)          FROM ROLES
UNION ALL
SELECT 'PERMISSIONS',             COUNT(*)          FROM PERMISSIONS
UNION ALL
SELECT 'PERMISSIONS_ROLES',       COUNT(*)          FROM PERMISSIONS_ROLES
UNION ALL
SELECT 'ROLES_EMPLOYEES',         COUNT(*)          FROM ROLES_EMPLOYEES
ORDER BY tbl;
