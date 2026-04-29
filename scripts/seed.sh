#!/bin/bash

# Get the directory where this script resides
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Move up to the project root (where .env is located)
cd "$SCRIPT_DIR/.." || { echo "ERROR: Could not navigate to project root"; exit 1; }

# Load POSTGRES_USER and POSTGRES_DB from .env
POSTGRES_USER=$(grep '^POSTGRES_USER=' .env | cut -d '=' -f2-)
POSTGRES_DB=$(grep '^POSTGRES_DB=' .env | cut -d '=' -f2-)

# Check that both variables were found
if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_DB" ]; then
    echo "ERROR: POSTGRES_USER or POSTGRES_DB not found in .env file"
    exit 1
fi

# Execute the SQL script inside the running PostgreSQL container
docker exec -i my-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /scripts/master_seed.sql

# If successful, print a confirmation
if [ $? -eq 0 ]; then
    echo "master_seed.sql executed successfully"
else
    echo "ERROR: Failed to execute master_seed.sql"
    exit 1
fi
