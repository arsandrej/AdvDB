-- =============================================================================
-- SEED SCRIPT: employees, roles, permissions, permissions_roles, roles_employees
-- =============================================================================
-- Prerequisites — place these CSV files in the same directory:
--   first_names.csv  |  last_names.csv  |  job_titles.csv
--   roles.csv        |  permissions.csv
--
-- Run with:
--   psql -U <user> -d <database> -f seed_employees_roles.sql
--
-- All logic is set-based — no row-by-row loops.
-- Tweak the LIMIT in section 6 to control exact employee count (min 2000).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. STAGING TABLES
-- ---------------------------------------------------------------------------

CREATE TEMP TABLE stg_first_names (
    first_name VARCHAR(63)
);

CREATE TEMP TABLE stg_last_names (
    last_name VARCHAR(63)
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

COPY stg_first_names  FROM '/csv/first_names.csv'  CSV HEADER;
COPY stg_last_names   FROM '/csv/last_names.csv'   CSV HEADER;
COPY stg_job_titles   FROM '/csv/job_titles.csv'   CSV HEADER;
COPY stg_roles        FROM '/csv/roles.csv'        CSV HEADER;
COPY stg_permissions  FROM '/csv/permissions.csv'  CSV HEADER;

-- Deduplicate names that may appear more than once in the CSVs
DELETE FROM stg_first_names
WHERE ctid NOT IN (
    SELECT MIN(ctid) FROM stg_first_names GROUP BY first_name
);

DELETE FROM stg_last_names
WHERE ctid NOT IN (
    SELECT MIN(ctid) FROM stg_last_names GROUP BY last_name
);

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
--    Curated access matrix: each role receives a specific set of permissions.
-- ---------------------------------------------------------------------------

INSERT INTO PERMISSIONS_ROLES (permissions_id, roles_id)
SELECT p.id, r.id
FROM   ROLES r
JOIN   PERMISSIONS p ON TRUE
WHERE (
    -- Admin: everything
    (r.name = 'Admin')

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

    OR (r.name = 'Inventory Analyst' AND p.name IN (
        'inventory.view','inventory.edit','inventory.reserve',
        'products.view','products.edit',
        'warehouses.view',
        'transactions.view','transactions.create',
        'reports.view','reports.export','audit.view'
    ))

    OR (r.name = 'Receiving Clerk' AND p.name IN (
        'inventory.view','inventory.edit',
        'products.view',
        'warehouses.view',
        'transactions.view','transactions.create',
        'deliveries.view','deliveries.create','deliveries.edit',
        'reports.view'
    ))

    OR (r.name = 'Shipping Coordinator' AND p.name IN (
        'inventory.view','inventory.reserve',
        'products.view',
        'warehouses.view',
        'transactions.view','transactions.create',
        'shipments.view','shipments.create','shipments.edit',
        'reports.view'
    ))

    OR (r.name = 'Forklift Operator' AND p.name IN (
        'inventory.view',
        'products.view',
        'warehouses.view',
        'transactions.view','transactions.create'
    ))

    OR (r.name = 'Quality Inspector' AND p.name IN (
        'inventory.view','inventory.edit',
        'products.view',
        'warehouses.view',
        'transactions.view',
        'reports.view'
    ))

    OR (r.name = 'Procurement Officer' AND p.name IN (
        'inventory.view',
        'products.view','products.edit',
        'warehouses.view',
        'transactions.view','transactions.create',
        'deliveries.view','deliveries.create','deliveries.edit',
        'reports.view','reports.export'
    ))

    OR (r.name = 'HR Coordinator' AND p.name IN (
        'employees.view','employees.edit','employees.delete',
        'roles.view','roles.assign',
        'warehouses.view',
        'reports.view'
    ))

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
--    Cross join first × last names → assign a unique row number, then cycle
--    through job titles and derive all other columns from that number.
--    The LIMIT controls the exact employee count — raise it freely, the
--    cross join supports up to ~15 000 unique name combinations.
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

-- ① Cross join produces all unique first × last combinations
all_combinations AS (
    SELECT
        f.first_name,
        l.last_name,
        ROW_NUMBER() OVER (ORDER BY l.last_name, f.first_name) AS rn
    FROM stg_first_names f
    CROSS JOIN stg_last_names l
),

-- ② Keep only as many rows as we want employees
limited AS (
    SELECT * FROM all_combinations
    ORDER BY rn
    LIMIT 2000            -- ← change this number to produce more employees
),

-- ③ Number every job row so we can cycle through them
numbered_jobs AS (
    SELECT
        job_title,
        employment_status,
        ROW_NUMBER() OVER (ORDER BY employment_status DESC, job_title) AS jrn
    FROM stg_job_titles
),

job_count AS (SELECT COUNT(*) AS cnt FROM stg_job_titles),

-- ④ Pair each employee with a job via modular arithmetic
with_jobs AS (
    SELECT
        e.first_name,
        e.last_name,
        e.rn,
        j.job_title,
        j.employment_status
    FROM  limited e
    JOIN  numbered_jobs j
       ON j.jrn = ((e.rn - 1) % (SELECT cnt FROM job_count)) + 1
),

-- ⑤ Derive timestamps: hire dates spread evenly across last 10 years
with_dates AS (
    SELECT
        *,
        CURRENT_TIMESTAMP
            - ( ((rn::numeric / 2000) * 365 * 10) || ' days' )::INTERVAL
            AS hired_at,
        CASE
            WHEN employment_status = 'terminated'
            THEN CURRENT_TIMESTAMP
                 - ( ((rn::numeric / 2000) * 365 * 2) || ' days' )::INTERVAL
            ELSE NULL
        END AS terminated_at
    FROM with_jobs
)

-- ⑥ Final SELECT — manager_id resolved by employee_number of senior staff
SELECT
    'EMP-' || LPAD(rn::text, 7, '0')                                  AS employee_number,
    first_name,
    last_name,
    LOWER(first_name) || '.' || LOWER(last_name)
        || rn::text || '@warehouseco.com'                              AS email,
    '+1-555-' || LPAD(((100000 + rn * 97) % 900000 + 100000)::text, 6, '0')
                                                                       AS phone,
    job_title,
    employment_status,
    hired_at,
    terminated_at,
    -- First 20 employees are top-level managers (no manager_id).
    -- Everyone else cycles through those 20 as their manager.
    CASE
        WHEN rn <= 20 THEN NULL
        ELSE (
            SELECT id FROM EMPLOYEES
            WHERE  employee_number = 'EMP-' || LPAD(((rn % 20) + 1)::text, 7, '0')
        )
    END                                                                AS manager_id
FROM with_dates
ORDER BY rn;

-- ---------------------------------------------------------------------------
-- 7. ROLES_EMPLOYEES
--    Assign roles based on job title (primary role) + two bonus rules:
--      • Every 7th employee also gets Auditor (cross-functional read access)
--      • The first 20 employees (senior staff) also get Warehouse Manager
-- ---------------------------------------------------------------------------

INSERT INTO ROLES_EMPLOYEES (roles_id, employees_id)

WITH

emp_numbered AS (
    SELECT
        id,
        job_title,
        ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM EMPLOYEES
),

-- Primary role derived from job title
primary_role AS (
    SELECT
        e.id   AS employee_id,
        r.id   AS role_id,
        r.name AS role_name
    FROM emp_numbered e
    JOIN ROLES r ON r.name = CASE e.job_title
        WHEN 'Warehouse Manager'           THEN 'Warehouse Manager'
        WHEN 'Assistant Warehouse Manager' THEN 'Warehouse Manager'
        WHEN 'Operations Supervisor'       THEN 'Operations Supervisor'
        WHEN 'Warehouse Supervisor'        THEN 'Operations Supervisor'
        WHEN 'Inventory Specialist'        THEN 'Inventory Analyst'
        WHEN 'Inventory Control Manager'   THEN 'Inventory Analyst'
        WHEN 'Senior Inventory Analyst'    THEN 'Inventory Analyst'
        WHEN 'Data Entry Clerk'            THEN 'Inventory Analyst'
        WHEN 'Receiving Clerk'             THEN 'Receiving Clerk'
        WHEN 'Returns Processor'           THEN 'Receiving Clerk'
        WHEN 'Shipping Coordinator'        THEN 'Shipping Coordinator'
        WHEN 'Dispatch Coordinator'        THEN 'Shipping Coordinator'
        WHEN 'Packing Specialist'          THEN 'Shipping Coordinator'
        WHEN 'Fleet Coordinator'           THEN 'Shipping Coordinator'
        WHEN 'Forklift Operator'           THEN 'Forklift Operator'
        WHEN 'Loading Dock Supervisor'     THEN 'Forklift Operator'
        WHEN 'Stock Associate'             THEN 'Forklift Operator'
        WHEN 'Warehouse Associate'         THEN 'Forklift Operator'
        WHEN 'Quality Control Inspector'   THEN 'Quality Inspector'
        WHEN 'Logistics Coordinator'       THEN 'Operations Supervisor'
        WHEN 'Procurement Officer'         THEN 'Procurement Officer'
        WHEN 'Supply Chain Analyst'        THEN 'Procurement Officer'
        WHEN 'HR Coordinator'              THEN 'HR Coordinator'
        WHEN 'IT Support Technician'       THEN 'IT Support'
        WHEN 'Safety Officer'              THEN 'Auditor'
        ELSE 'Inventory Analyst'
    END
),

-- Every 7th employee also gets Auditor
auditor_extra AS (
    SELECT
        e.id   AS employee_id,
        r.id   AS role_id,
        r.name AS role_name
    FROM  emp_numbered e
    JOIN  ROLES r ON r.name = 'Auditor'
    JOIN  primary_role pr ON pr.employee_id = e.id AND pr.role_name <> 'Auditor'
    WHERE e.rn % 7 = 0
),

-- First 20 employees (senior staff) also carry Warehouse Manager
senior_extra AS (
    SELECT
        e.id   AS employee_id,
        r.id   AS role_id,
        r.name AS role_name
    FROM  emp_numbered e
    JOIN  ROLES r ON r.name = 'Warehouse Manager'
    JOIN  primary_role pr ON pr.employee_id = e.id AND pr.role_name <> 'Warehouse Manager'
    WHERE e.rn <= 20
),

all_assignments AS (
    SELECT employee_id, role_id FROM primary_role
    UNION
    SELECT employee_id, role_id FROM auditor_extra
    UNION
    SELECT employee_id, role_id FROM senior_extra
)

SELECT role_id, employee_id
FROM   all_assignments
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 8. CLEANUP
-- ---------------------------------------------------------------------------

DROP TABLE stg_first_names;
DROP TABLE stg_last_names;
DROP TABLE stg_job_titles;
DROP TABLE stg_roles;
DROP TABLE stg_permissions;

COMMIT;

-- ---------------------------------------------------------------------------
-- SANITY CHECK
-- ---------------------------------------------------------------------------
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
