\echo '========================================='
\echo 'Starting master seed process...'
\echo '========================================='

\echo 'Warehouses structure'
\ir warehouses/seed_warehouse_structure.sql

\echo 'Employees'
\ir employees/employees_seed.sql

\echo 'Update manager IDs (self-reference)'
\ir employees/update_manager_id.sql

\echo 'Employee warehouse assignments'
\ir employees/employee_warehouse_assignments_seed.sql

\echo 'Large products'
\ir products/large_products.sql

\echo 'Transaction types'
\ir inventory/transaction_type_seed.sql

\echo '========================================='
\echo '✅ Master seed completed successfully!'
\echo '========================================='