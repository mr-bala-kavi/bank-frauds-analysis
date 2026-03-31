-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 04: DML — DATA MANIPULATION LANGUAGE
-- Commands: INSERT, UPDATE, DELETE
-- These commands change the DATA inside tables (not the structure).
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- SETUP: Create a safe practice table (won't touch real data)
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dml_practice (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    full_name   VARCHAR(150) NOT NULL,
    email       VARCHAR(255) UNIQUE,
    city        VARCHAR(100),
    balance     DECIMAL(15,2) DEFAULT 0.00,
    status      VARCHAR(20) DEFAULT 'active',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────────────────────────────────────────────────────────────────
-- 4.1 INSERT — Add new rows into a table
-- ─────────────────────────────────────────────────────────────────────────

-- Insert ONE row (specify column names — always best practice):
INSERT INTO dml_practice (full_name, email, city, balance)
VALUES ('Karthik Kumar', 'karthik@gmail.com', 'Chennai', 50000.00);

-- Insert ONE row without column names (must match all column order exactly):
INSERT INTO dml_practice
VALUES (NULL, 'Priya Sharma', 'priya@yahoo.com', 'Mumbai', 75000.00, 'active', NOW());

-- Insert MULTIPLE rows in one statement (much faster than separate INSERTs):
INSERT INTO dml_practice (full_name, email, city, balance, status)
VALUES
    ('Amit Patel',     'amit@outlook.com',   'Ahmedabad', 120000.00, 'active'),
    ('Sneha Reddy',    'sneha@gmail.com',     'Hyderabad',  35000.00, 'active'),
    ('Rahul Singh',    'rahul@hotmail.com',   'Delhi',      88000.00, 'inactive'),
    ('Meena Iyer',     'meena@gmail.com',     'Bengaluru', 200000.00, 'active'),
    ('Vijay Nair',     'vijay@yahoo.com',     'Kochi',      15000.00, 'frozen');

-- INSERT with SELECT (copy data from another table):
-- Example: Backup all high-risk customers into a new table
CREATE TABLE IF NOT EXISTS high_risk_backup AS
    SELECT customer_id, full_name, risk_category, annual_income
    FROM customers
    WHERE risk_category IN ('high', 'very_high');

SELECT * FROM high_risk_backup LIMIT 5;

-- INSERT IGNORE — skips duplicate key errors instead of failing:
INSERT IGNORE INTO dml_practice (full_name, email, city, balance)
VALUES ('Karthik Kumar', 'karthik@gmail.com', 'Chennai', 50000.00);  -- duplicate email → ignored

-- INSERT ON DUPLICATE KEY UPDATE — upsert pattern:
INSERT INTO dml_practice (full_name, email, city, balance)
VALUES ('Karthik Kumar', 'karthik@gmail.com', 'Chennai', 60000.00)
ON DUPLICATE KEY UPDATE balance = 60000.00;
-- If email already exists, UPDATE balance instead of inserting

-- ─────────────────────────────────────────────────────────────────────────
-- 4.2 UPDATE — Modify existing rows
-- ─────────────────────────────────────────────────────────────────────────

-- Update ONE column for ONE specific row:
UPDATE dml_practice
SET balance = 55000.00
WHERE id = 1;

-- Update MULTIPLE columns at once:
UPDATE dml_practice
SET city    = 'Coimbatore',
    status  = 'active',
    balance = balance + 5000.00    -- add 5000 to existing balance
WHERE full_name = 'Karthik Kumar';

-- Update ALL rows matching a condition:
UPDATE dml_practice
SET status = 'inactive'
WHERE balance < 20000.00;

-- Update using a calculation:
UPDATE dml_practice
SET balance = balance * 1.05     -- 5% interest to all active accounts
WHERE status = 'active';

-- REAL WORLD: Freeze an account (from our actual data workflow):
-- UPDATE accounts SET account_status = 'frozen'
-- WHERE account_id = 'some-id';

-- ⚠️ SAFE UPDATE MODE:
-- If MySQL complains "UPDATE without WHERE uses safe update mode", add LIMIT:
UPDATE dml_practice
SET status = 'reviewed'
WHERE city = 'Delhi'
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 4.3 DELETE — Remove specific rows from a table
-- ─────────────────────────────────────────────────────────────────────────

-- Delete ONE specific row:
DELETE FROM dml_practice
WHERE email = 'vijay@yahoo.com';

-- Delete rows matching a condition:
DELETE FROM dml_practice
WHERE status = 'inactive';

-- Delete with LIMIT (safe — restrict how many rows get deleted at once):
DELETE FROM dml_practice
WHERE balance < 50000.00
LIMIT 2;

-- Delete ALL rows (like TRUNCATE but slower, keeps AUTO_INCREMENT value):
-- DELETE FROM dml_practice;  -- ⚠️ removes every row

-- REAL WORLD: Remove a test fraud case:
-- DELETE FROM fraud_cases WHERE investigation_notes = 'TEST ENTRY';

-- ─────────────────────────────────────────────────────────────────────────
-- 4.4 DML ON REAL TABLES (read-only lookups to verify understanding)
-- ─────────────────────────────────────────────────────────────────────────

-- See the current state of real customers before any change:
SELECT customer_id, full_name, risk_category
FROM customers
WHERE risk_category = 'very_high'
LIMIT 5;

-- What would UPDATE look like on real data (don't run without WHERE):
-- UPDATE customers
-- SET risk_category = 'high'
-- WHERE risk_category = 'very_high' AND kyc_status = 'verified'
-- LIMIT 10;

-- Check current alerts before deleting any:
SELECT alert_id, alert_type, status
FROM alerts
WHERE status = 'resolved'
LIMIT 5;

-- ─────────────────────────────────────────────────────────────────────────
-- 4.5 CLEANUP
-- ─────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS dml_practice;
DROP TABLE IF EXISTS high_risk_backup;
