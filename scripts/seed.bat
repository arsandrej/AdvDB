@echo off
FOR /F "tokens=*" %%i in ('type .env ^| findstr "POSTGRES_USER="') do set %%i
FOR /F "tokens=*" %%i in ('type .env ^| findstr "POSTGRES_DB="') do set %%i
docker exec -i my-postgres psql -U %POSTGRES_USER% -d %POSTGRES_DB% -f /scripts/master_seed.sql

:: to execute -> .\scripts\seed.bat