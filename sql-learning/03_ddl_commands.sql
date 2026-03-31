-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 03: DDL — DATA DEFINITION LANGUAGE
-- Commands: CREATE, ALTER, DROP, TRUNCATE
-- These commands define and modify the STRUCTURE of tables.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 3.1 CREATE — Build a new table from scratch
-- ─────────────────────────────────────────────────────────────────────────

-- Create a simple practice table (won't affect real data)
CREATE TABLE IF NOT EXISTS practice_customers (
    customer_id     INT           AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(150)  NOT NULL,
    email           VARCHAR(255)  UNIQUE,
    phone           VARCHAR(20),
    annual_income   DECIMAL(15,2) DEFAULT 0.00,
    risk_level      ENUM('low','medium','high') DEFAULT 'low',
    is_active       TINYINT(1)    DEFAULT 1,
    created_at      DATETIME      DEFAULT CURRENT_TIMESTAMP
);

-- ── What each constraint means ──
-- AUTO_INCREMENT → MySQL assigns the next number automatically
-- PRIMARY KEY    → Uniquely identifies each row
-- NOT NULL       → Column cannot be empty
-- UNIQUE         → No duplicates allowed in this column
-- DEFAULT        → Value used if none is provided
-- ENUM           → Only specific values are allowed

-- Create a related table (with a FOREIGN KEY):
CREATE TABLE IF NOT EXISTS practice_accounts (
    account_id      INT            AUTO_INCREMENT PRIMARY KEY,
    customer_id     INT            NOT NULL,
    account_number  VARCHAR(20)    UNIQUE NOT NULL,
    account_type    ENUM('savings','current','salary') DEFAULT 'savings',
    balance         DECIMAL(15,2)  DEFAULT 0.00,
    opened_date     DATE           NOT NULL,
    CONSTRAINT fk_prac_customer
        FOREIGN KEY (customer_id)
        REFERENCES practice_customers(customer_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- ON DELETE CASCADE → If customer is deleted, their accounts auto-delete
-- ON UPDATE CASCADE → If customer_id changes, update here too

-- ─────────────────────────────────────────────────────────────────────────
-- 3.2 ALTER — Modify an existing table
-- ─────────────────────────────────────────────────────────────────────────

-- ADD a new column:
ALTER TABLE practice_customers
    ADD COLUMN occupation VARCHAR(100) AFTER full_name;

-- ADD multiple columns at once:
ALTER TABLE practice_customers
    ADD COLUMN dob         DATE         AFTER occupation,
    ADD COLUMN nationality VARCHAR(50)  DEFAULT 'India' AFTER dob;

-- MODIFY a column (change type or constraint):
ALTER TABLE practice_customers
    MODIFY COLUMN phone VARCHAR(30) NOT NULL;

-- CHANGE a column (rename + retype):
ALTER TABLE practice_customers
    CHANGE COLUMN risk_level risk_category ENUM('low','medium','high','very_high') DEFAULT 'low';

-- DROP a column:
ALTER TABLE practice_customers
    DROP COLUMN is_active;

-- RENAME the table:
ALTER TABLE practice_customers RENAME TO practice_clients;

-- Add an INDEX on a frequently searched column:
ALTER TABLE practice_clients
    ADD INDEX idx_email (email);

-- Add a CHECK constraint (MySQL 8.0+):
ALTER TABLE practice_accounts
    ADD CONSTRAINT chk_balance CHECK (balance >= 0);

-- ─────────────────────────────────────────────────────────────────────────
-- 3.3 DROP — Remove tables or databases permanently
-- ─────────────────────────────────────────────────────────────────────────

-- Drop a table (removes data + structure completely):
DROP TABLE IF EXISTS practice_accounts;   -- drop child first (FK dependency)
DROP TABLE IF EXISTS practice_clients;

-- Drop an index:
-- ALTER TABLE customers DROP INDEX idx_email;

-- Drop a column (same as ALTER above):
-- ALTER TABLE some_table DROP COLUMN some_column;

-- ─────────────────────────────────────────────────────────────────────────
-- 3.4 TRUNCATE — Wipe all rows but KEEP the table structure
-- ─────────────────────────────────────────────────────────────────────────

-- First, let's create + insert some data to demonstrate:
CREATE TABLE IF NOT EXISTS demo_log (
    log_id      INT AUTO_INCREMENT PRIMARY KEY,
    event       VARCHAR(100),
    logged_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO demo_log (event) VALUES ('Login attempt'), ('Failed auth'), ('Fraud alert');

SELECT * FROM demo_log;   -- see 3 rows

TRUNCATE TABLE demo_log;  -- removes ALL rows instantly, resets AUTO_INCREMENT

SELECT * FROM demo_log;   -- now empty, but table still exists

DROP TABLE IF EXISTS demo_log;  -- clean up

-- ─────────────────────────────────────────────────────────────────────────
-- 3.5 TRUNCATE vs DELETE vs DROP comparison
-- ─────────────────────────────────────────────────────────────────────────
-- TRUNCATE → Removes ALL rows. Cannot WHERE filter. Resets AUTO_INCREMENT. Fast.
-- DELETE   → Removes specific or all rows. Can WHERE filter. Slow on big tables.
-- DROP     → Destroys the entire table (structure + data). Cannot recover.

-- REAL WORLD EXAMPLE from our database:
-- DESCRIBE the customers table to see how CREATE defines columns:
DESCRIBE customers;
DESCRIBE accounts;
DESCRIBE transactions;
