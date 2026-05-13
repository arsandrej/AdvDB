-- =============================================================================
-- TEST SCRIPT FOR WAREHOUSE & EMPLOYEE ADMINISTRATION FUNCTIONS
-- =============================================================================

-- 1. Create and update a warehouse
SELECT create_warehouse('warehouse2', '123 Dummy St', 'city2', 'country2') AS wh_id;
SELECT update_warehouse(1, 'warehouse2-updated', '456 New Address', 'city2b', 'country2');

-- 2. Create sections
SELECT create_section(1, 'section2', 'Test section') AS sec_id;
SELECT create_section(1, 'section3') AS sec2_id;

-- 3. Update a section
SELECT update_section(2, 'section2-renamed', 'Updated description');

-- 4. Create locations
SELECT create_location(2, 1, 2, 1, 'LOC-A1B2') AS loc_id;
SELECT create_location(3, 2, 1, 1, 'LOC-C2D1') AS loc2_id;

-- 5. Update a location
SELECT update_location(2, 2, 2, 2, 'LOC-UPDATED');

-- 6. Create bins
SELECT create_bin(2, 'BIN-001', 500) AS bin_id;
SELECT create_bin(2, 'BIN-002', 1000) AS bin2_id;

-- 7. Update a bin
SELECT update_bin(3, 'BIN-001-renamed', 750);

-- 8. Hire an employee
SELECT hire_employee('EMP002', 'Jane', 'Smith', 'jane.smith@example.com',
                     '+123456789', 'Supervisor', 'ACTIVE', '2024-06-01') AS emp_id;

-- 9. Update employee details (change job title, phone)
SELECT update_employee(2, 'Jane', 'Smith-Doe', 'jane.smith@example.com',
                       '+987654321', 'Senior Supervisor', 'ACTIVE', NULL);

-- 10. Terminate the employee (fired/left)
SELECT terminate_employee(2, '2025-01-15');

-- 11. Re-hire? (just change status back; we can use update_employee to set status 'ACTIVE' again if needed)
-- But for completeness, we can directly update.
SELECT update_employee(2, 'Jane', 'Smith-Doe', 'jane.smith@example.com',
                       '+987654321', 'Senior Supervisor', 'ACTIVE', NULL);

-- 12. Assign employee to a warehouse
SELECT assign_employee_to_warehouse(2, 1, CURRENT_DATE, NULL, TRUE, 'Primary assignment') AS assign_id;

-- 13. End that assignment
SELECT end_warehouse_assignment(1, CURRENT_DATE + 30);

-- 14. Role & Permission management
INSERT INTO ROLES (name)
VALUES ('role1')
ON CONFLICT DO NOTHING;
INSERT INTO ROLES (name)
VALUES ('role2')
ON CONFLICT DO NOTHING;
INSERT INTO PERMISSIONS (name)
VALUES ('perm1')
ON CONFLICT DO NOTHING;
INSERT INTO PERMISSIONS (name)
VALUES ('perm2')
ON CONFLICT DO NOTHING;

-- Get IDs (hardcoded for demo; in practice use subqueries)
-- role1 = 1, role2 = 2; perm1 = 1, perm2 = 2 (depending on sequences)
-- Assign role to employee
SELECT assign_role_to_employee(1, 2); -- role1 to emp2
SELECT assign_role_to_employee(2, 2);
-- role2 to emp2

-- Remove role
SELECT remove_role_from_employee(2, 2);
-- remove role2

-- Assign permissions to role
SELECT assign_permission_to_role(1, 1); -- perm1 -> role1
SELECT assign_permission_to_role(2, 1);
-- perm2 -> role1

-- Remove permission from role
SELECT remove_permission_from_role(2, 1);