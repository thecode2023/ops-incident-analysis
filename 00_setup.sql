-- ============================================================
-- DAY 1 SETUP SCRIPT
-- Run this first before incident_kpi_analysis.sql
-- ============================================================
-- Step 1: Create your database
--   In terminal: createdb incident_analysis
--   Then connect: psql -d incident_analysis
--
-- Step 2: Download dataset from Kaggle
--   https://www.kaggle.com/datasets/chicago/chicago-311-service-requests
--   Save the CSV to a known path (e.g. ~/Downloads/311.csv)
--
-- Step 3: Run this file, then incident_kpi_analysis.sql
-- ============================================================

-- Create raw import table
-- (Column names match the Chicago 311 CSV headers)
DROP TABLE IF EXISTS chicago_311_raw;

CREATE TABLE chicago_311_raw (
    service_request_id      TEXT,
    sr_type                 TEXT,
    sr_short_code           TEXT,
    owner_department        TEXT,
    status                  TEXT,
    created_date            TEXT,
    closed_date             TEXT,
    street_address          TEXT,
    city                    TEXT,
    state                   TEXT,
    zip_code                TEXT,
    latitude                TEXT,
    longitude               TEXT,
    location                TEXT
);

-- Import the CSV (update path to match where you saved the file)
-- Run this line in psql after connecting to the database:
--
--   \COPY chicago_311_raw FROM '~/Downloads/311.csv'
--       WITH (FORMAT csv, HEADER true, QUOTE '"');
--
-- If you hit encoding issues, add: ENCODING 'UTF8'

-- Verify import worked
SELECT COUNT(*) AS total_rows FROM chicago_311_raw;
SELECT sr_type, status, created_date FROM chicago_311_raw LIMIT 5;

-- Once confirmed, run: incident_kpi_analysis.sql
-- That file creates the cleaned `incidents` table and all 15 queries.

-- ============================================================
-- QUICK REFERENCE: psql commands you'll use
-- ============================================================
-- Connect to DB:     psql -U postgres -d incident_analysis
-- Run a file:        \i path/to/file.sql
-- List tables:       \dt
-- Describe a table:  \d incidents
-- Quit psql:         \q
-- Export results:    \COPY (SELECT ...) TO 'output.csv' CSV HEADER;
-- ============================================================
