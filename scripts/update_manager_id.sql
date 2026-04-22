-- =============================================================================
-- UPDATE manager_id BASED ON ROLE HIERARCHY
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Tag every employee with their primary role and hierarchy level.
--    "Primary role" = the most operational one they hold
--    (highest hierarchy_level number wins).
-- ---------------------------------------------------------------------------

WITH role_levels (role_name, hierarchy_level) AS (
    VALUES
        ('Admin',                1),
        ('Warehouse Manager',    1),
        ('Operations Supervisor',2),
        ('Inventory Analyst',    3),
        ('HR Coordinator',       3),
        ('Procurement Officer',  3),
        ('IT Support',           3),
        ('Auditor',              3),
        ('Quality Inspector',    3),
        ('Receiving Clerk',      4),
        ('Shipping Coordinator', 4),
        ('Forklift Operator',    4)
),

-- Each employee keeps only their most operational role
employee_primary_role AS (
    SELECT DISTINCT ON (e.id)
        e.id  AS employee_id,
        rl.role_name,
        rl.hierarchy_level
    FROM       EMPLOYEES        e
    JOIN       ROLES_EMPLOYEES  re ON re.employees_id = e.id
    JOIN       ROLES             r ON  r.id = re.roles_id
    JOIN       role_levels      rl ON rl.role_name = r.name
    ORDER BY   e.id,
               rl.hierarchy_level DESC  -- highest level = most operational role
),

-- ---------------------------------------------------------------------------
-- 2. Build numbered manager pools (one row-number per pool).
--    Every subordinate group picks its manager by:
--        manager_rn = (subordinate_rn % pool_size) + 1
-- ---------------------------------------------------------------------------

-- Pool A: Warehouse Managers (for level-2 subordinates)
pool_warehouse_mgr AS (
    SELECT
        employee_id,
        ROW_NUMBER() OVER (ORDER BY employee_id) AS pool_rn
    FROM employee_primary_role
    WHERE role_name IN ('Admin', 'Warehouse Manager')
),

-- Pool B: Operations Supervisors (for level-3 subordinates + Forklift Operators)
pool_ops_supervisor AS (
    SELECT
        employee_id,
        ROW_NUMBER() OVER (ORDER BY employee_id) AS pool_rn
    FROM employee_primary_role
    WHERE role_name = 'Operations Supervisor'
),

-- Pool C: Inventory Analysts (for Receiving Clerks)
pool_inventory_analyst AS (
    SELECT
        employee_id,
        ROW_NUMBER() OVER (ORDER BY employee_id) AS pool_rn
    FROM employee_primary_role
    WHERE role_name = 'Inventory Analyst'
),

-- Pool D: Procurement Officers (for Shipping Coordinators)
pool_procurement_officer AS (
    SELECT
        employee_id,
        ROW_NUMBER() OVER (ORDER BY employee_id) AS pool_rn
    FROM employee_primary_role
    WHERE role_name = 'Procurement Officer'
),

-- ---------------------------------------------------------------------------
-- 3. Number each subordinate within their group so we can MOD into the pool.
-- ---------------------------------------------------------------------------

subordinate_ranked AS (
    SELECT
        employee_id,
        role_name,
        hierarchy_level,
        ROW_NUMBER() OVER (
            PARTITION BY role_name          -- separate sequence per role
            ORDER BY employee_id
        ) AS sub_rn
    FROM employee_primary_role
),

-- ---------------------------------------------------------------------------
-- 4. Join each subordinate to the right manager pool.
-- ---------------------------------------------------------------------------

new_managers AS (

    -- Level 1: no manager
    SELECT sr.employee_id, NULL::BIGINT AS new_manager_id
    FROM   subordinate_ranked sr
    WHERE  sr.hierarchy_level = 1

    UNION ALL

    -- Level 2 (Operations Supervisor) → Warehouse Manager pool
    SELECT sr.employee_id,
           pm.employee_id AS new_manager_id
    FROM   subordinate_ranked  sr
    JOIN   pool_warehouse_mgr  pm
        ON pm.pool_rn = (sr.sub_rn - 1) % (SELECT COUNT(*) FROM pool_warehouse_mgr) + 1
    WHERE  sr.hierarchy_level = 2

    UNION ALL

    -- Level 3 (all mid roles) → Operations Supervisor pool
    SELECT sr.employee_id,
           pm.employee_id AS new_manager_id
    FROM   subordinate_ranked   sr
    JOIN   pool_ops_supervisor  pm
        ON pm.pool_rn = (sr.sub_rn - 1) % (SELECT COUNT(*) FROM pool_ops_supervisor) + 1
    WHERE  sr.hierarchy_level = 3

    UNION ALL

    -- Receiving Clerk (level 4) → Inventory Analyst pool
    SELECT sr.employee_id,
           pm.employee_id AS new_manager_id
    FROM   subordinate_ranked      sr
    JOIN   pool_inventory_analyst  pm
        ON pm.pool_rn = (sr.sub_rn - 1) % (SELECT COUNT(*) FROM pool_inventory_analyst) + 1
    WHERE  sr.role_name = 'Receiving Clerk'

    UNION ALL

    -- Shipping Coordinator (level 4) → Procurement Officer pool
    SELECT sr.employee_id,
           pm.employee_id AS new_manager_id
    FROM   subordinate_ranked       sr
    JOIN   pool_procurement_officer pm
        ON pm.pool_rn = (sr.sub_rn - 1) % (SELECT COUNT(*) FROM pool_procurement_officer) + 1
    WHERE  sr.role_name = 'Shipping Coordinator'

    UNION ALL

    -- Forklift Operator (level 4) → Operations Supervisor pool
    SELECT sr.employee_id,
           pm.employee_id AS new_manager_id
    FROM   subordinate_ranked   sr
    JOIN   pool_ops_supervisor  pm
        ON pm.pool_rn = (sr.sub_rn - 1) % (SELECT COUNT(*) FROM pool_ops_supervisor) + 1
    WHERE  sr.role_name = 'Forklift Operator'
)

-- ---------------------------------------------------------------------------
-- 5. Apply the update
-- ---------------------------------------------------------------------------

UPDATE EMPLOYEES e
SET    manager_id = nm.new_manager_id
FROM   new_managers nm
WHERE  e.id        = nm.employee_id
  AND  (nm.new_manager_id IS NULL OR nm.new_manager_id <> e.id);  -- safety: never self-manage

COMMIT;

-- ---------------------------------------------------------------------------
-- VERIFICATION
-- Shows how many subordinates each role reports to, and to which manager role.
-- Every level-1 employee should show NULL for manager_role.
-- ---------------------------------------------------------------------------

WITH primary_roles AS (
    SELECT DISTINCT ON (re.employees_id)
        re.employees_id AS employee_id,
        r.name          AS role_name
    FROM  ROLES_EMPLOYEES re
    JOIN  ROLES r ON r.id = re.roles_id
    JOIN (
        VALUES
            ('Admin',1),('Warehouse Manager',1),('Operations Supervisor',2),
            ('Inventory Analyst',3),('HR Coordinator',3),('Procurement Officer',3),
            ('IT Support',3),('Auditor',3),('Quality Inspector',3),
            ('Receiving Clerk',4),('Shipping Coordinator',4),('Forklift Operator',4)
    ) AS rl(role_name, lvl) ON rl.role_name = r.name
    ORDER BY re.employees_id, rl.lvl DESC
)

SELECT
    pr_sub.role_name                AS subordinate_role,
    COALESCE(pr_mgr.role_name,
             '— no manager (root)') AS manager_role,
    COUNT(*)                        AS employee_count
FROM       EMPLOYEES     e
JOIN       primary_roles pr_sub ON pr_sub.employee_id = e.id
LEFT JOIN  EMPLOYEES     mgr    ON mgr.id = e.manager_id
LEFT JOIN  primary_roles pr_mgr ON pr_mgr.employee_id = mgr.id
GROUP BY   pr_sub.role_name, pr_mgr.role_name
ORDER BY   pr_sub.role_name, manager_role;
