-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 12: CONSTRAINTS
-- Types: PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL, CHECK, DEFAULT
-- Constraints enforce rules at the database level — data can never violate them.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 12.1 PRIMARY KEY — Uniquely identifies each row, cannot be NULL
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS demo_primary_key (
    customer_id  INT          AUTO_INCREMENT,
    full_name    VARCHAR(150) NOT NULL,
    -- Inline PK declaration:
    PRIMARY KEY (customer_id)
);

-- Each table should have exactly ONE Primary Key
-- The PK can span multiple columns (composite PK):
CREATE TABLE IF NOT EXISTS demo_composite_pk (
    account_id      INT,
    transaction_seq INT,
    amount          DECIMAL(15,2),
    PRIMARY KEY (account_id, transaction_seq)  -- combination is unique
);

-- View primary key of a table:
SELECT column_name AS primary_key
FROM information_schema.columns
WHERE table_schema = 'bank_fraud_db'
  AND table_name   = 'customers'
  AND column_key   = 'PRI';

-- ─────────────────────────────────────────────────────────────────────────
-- 12.2 FOREIGN KEY — Enforces referential integrity between tables
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS demo_parent (
    id    INT AUTO_INCREMENT PRIMARY KEY,
    name  VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS demo_child (
    child_id     INT AUTO_INCREMENT PRIMARY KEY,
    parent_id    INT NOT NULL,
    description  VARCHAR(200),
    -- FK constraint definition:
    CONSTRAINT fk_demo_parent
        FOREIGN KEY (parent_id)
        REFERENCES demo_parent(id)
        ON DELETE CASCADE    -- if parent deleted, delete children too
        ON UPDATE CASCADE    -- if parent PK changes, update FK here
);

-- ON DELETE options:
-- CASCADE     → delete child rows when parent is deleted
-- SET NULL    → set FK to NULL when parent is deleted
-- RESTRICT    → block parent deletion if children exist (default)
-- NO ACTION   → same as RESTRICT

-- View all foreign keys in the database:
SELECT
    kcu.table_name        AS child_table,
    kcu.column_name       AS fk_column,
    kcu.referenced_table_name  AS parent_table,
    kcu.referenced_column_name AS pk_column,
    rc.delete_rule,
    rc.update_rule
FROM information_schema.key_column_usage kcu
JOIN information_schema.referential_constraints rc
    ON rc.constraint_name = kcu.constraint_name
WHERE kcu.table_schema = 'bank_fraud_db'
ORDER BY kcu.table_name;

-- ─────────────────────────────────────────────────────────────────────────
-- 12.3 UNIQUE — No duplicate values in the column (NULLs are allowed)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS demo_unique (
    id             INT           AUTO_INCREMENT PRIMARY KEY,
    email          VARCHAR(255)  UNIQUE,          -- inline syntax
    account_number VARCHAR(20),
    pan_number     VARCHAR(10),
    UNIQUE KEY uq_account  (account_number),       -- named unique constraint
    UNIQUE KEY uq_pan      (pan_number)
);

-- Composite UNIQUE (combination of both columns must be unique):
CREATE TABLE IF NOT EXISTS demo_composite_unique (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    user_id   INT,
    role_name VARCHAR(50),
    UNIQUE KEY uq_user_role (user_id, role_name)   -- same user can't have same role twice
);

-- See unique keys on customers:
SHOW INDEX FROM customers WHERE Non_unique = 0;

-- ─────────────────────────────────────────────────────────────────────────
-- 12.4 NOT NULL — Column must always have a value
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS demo_not_null (
    id          INT          AUTO_INCREMENT PRIMARY KEY,
    full_name   VARCHAR(150) NOT NULL,          -- required
    email       VARCHAR(255) NOT NULL,          -- required
    phone       VARCHAR(20),                    -- optional (can be NULL)
    kyc_status  VARCHAR(20)  NOT NULL DEFAULT 'pending'  -- required, default provided
);

-- Trying to insert without NOT NULL column will fail:
-- INSERT INTO demo_not_null (email) VALUES ('test@gmail.com');
-- ERROR: Field 'full_name' doesn't have a default value

-- ─────────────────────────────────────────────────────────────────────────
-- 12.5 CHECK — Validates data before inserting/updating (MySQL 8.0+)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS demo_check (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    full_name      VARCHAR(150)  NOT NULL,
    annual_income  DECIMAL(15,2) NOT NULL,
    age            INT,
    risk_score     INT,
    account_type   VARCHAR(20),

    -- CHECK constraints:
    CONSTRAINT chk_income_positive  CHECK (annual_income >= 0),
    CONSTRAINT chk_age_adult        CHECK (age >= 18 AND age <= 120),
    CONSTRAINT chk_risk_range       CHECK (risk_score BETWEEN 0 AND 100),
    CONSTRAINT chk_account_type     CHECK (account_type IN ('savings','current','salary','nri'))
);

-- Trying to insert invalid data FAILS with error:
-- INSERT INTO demo_check (full_name, annual_income, age)
-- VALUES ('Test', -5000, 15);
-- ERROR: Check constraint 'chk_income_positive' is violated

-- Real example: See CHECK constraints in the database:
SELECT
    table_name,
    constraint_name,
    check_clause
FROM information_schema.check_constraints
WHERE constraint_schema = 'bank_fraud_db';

-- ─────────────────────────────────────────────────────────────────────────
-- 12.6 DEFAULT — Value used when no value is provided during INSERT
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS demo_default (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(150)  NOT NULL,
    account_type  VARCHAR(20)   DEFAULT 'savings',       -- text default
    balance       DECIMAL(15,2) DEFAULT 0.00,            -- numeric default
    is_active     TINYINT(1)    DEFAULT 1,               -- boolean-like default
    risk_level    VARCHAR(20)   DEFAULT 'low',
    created_at    DATETIME      DEFAULT CURRENT_TIMESTAMP,   -- auto timestamp
    updated_at    DATETIME      DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP  -- auto-updates on change
);

-- Insert without specifying defaulted columns:
INSERT INTO demo_default (full_name) VALUES ('Test Customer');
-- balance = 0.00, account_type = 'savings', created_at = now() → all auto-filled

SELECT * FROM demo_default;

-- ─────────────────────────────────────────────────────────────────────────
-- 12.7 Viewing all constraints on a table
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'bank_fraud_db'
  AND table_name   = 'accounts';

-- ─────────────────────────────────────────────────────────────────────────
-- 12.8 CLEANUP
-- ─────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS demo_child;
DROP TABLE IF EXISTS demo_parent;
DROP TABLE IF EXISTS demo_primary_key;
DROP TABLE IF EXISTS demo_composite_pk;
DROP TABLE IF EXISTS demo_unique;
DROP TABLE IF EXISTS demo_composite_unique;
DROP TABLE IF EXISTS demo_not_null;
DROP TABLE IF EXISTS demo_check;
DROP TABLE IF EXISTS demo_default;
