-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 17: NORMALIZATION
-- Organizing tables to reduce redundancy and improve data integrity.
-- Normal Forms: 1NF → 2NF → 3NF (most databases target 3NF)
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 17.1 UNNORMALIZED (UNF) — Single messy flat table (what NOT to do)
-- ─────────────────────────────────────────────────────────────────────────
-- Imagine storing everything in ONE table:
--
-- customer_name | phone1        | phone2        | account1  | balance1 | account2  | balance2
-- Karthik Kumar | +91-9876...   | +91-7654...   | ACC-001   | 50000    | ACC-002   | 20000
-- Priya Sharma  | +91-8765...   | NULL          | ACC-003   | 75000    | NULL      | NULL
--
-- Problems:
-- ❌ Multiple phone columns (phone1, phone2, phone3...) — hard to extend
-- ❌ Multiple account columns — wasted space when only one account
-- ❌ Updating Karthik's phone is done in one place but others might exist

-- ─────────────────────────────────────────────────────────────────────────
-- 17.2 FIRST NORMAL FORM (1NF)
-- ─────────────────────────────────────────────────────────────────────────
-- Rules:
-- ✅ Each column holds ONE value (atomic values)
-- ✅ Each row is unique (has a primary key)
-- ✅ No repeating column groups (no phone1, phone2...)

-- BEFORE 1NF (violation — multiple values in one cell):
CREATE TABLE IF NOT EXISTS norm_bad_contact (
    customer_id  INT PRIMARY KEY,
    full_name    VARCHAR(150),
    phones       VARCHAR(500)    -- "9876543210, 8765432109" — NOT atomic!
);

-- AFTER 1NF (separate row per phone):
CREATE TABLE IF NOT EXISTS norm_1nf_customer (
    customer_id  INT,
    full_name    VARCHAR(150),
    phone        VARCHAR(30),
    PRIMARY KEY (customer_id, phone)   -- composite PK makes each row unique
);

INSERT INTO norm_1nf_customer VALUES
    (1, 'Karthik Kumar', '+91-98765-43210'),
    (1, 'Karthik Kumar', '+91-76543-21098'),  -- second phone = new row
    (2, 'Priya Sharma',  '+91-87654-32109');

SELECT * FROM norm_1nf_customer;

-- BUT notice: 'Karthik Kumar' repeats → leads to 2NF...

-- ─────────────────────────────────────────────────────────────────────────
-- 17.3 SECOND NORMAL FORM (2NF)
-- ─────────────────────────────────────────────────────────────────────────
-- Rules:
-- ✅ Must be in 1NF
-- ✅ Every non-key column must depend on the WHOLE primary key (no partial dependency)

-- Problem in 1NF table above:
-- PK = (customer_id, phone)
-- full_name depends only on customer_id — NOT on both customer_id AND phone
-- This is a PARTIAL DEPENDENCY → violates 2NF

-- FIX 2NF: Split into two tables:
CREATE TABLE IF NOT EXISTS norm_2nf_customers (
    customer_id  INT PRIMARY KEY,
    full_name    VARCHAR(150)
);

CREATE TABLE IF NOT EXISTS norm_2nf_phones (
    customer_id  INT,
    phone        VARCHAR(30),
    phone_type   VARCHAR(20) DEFAULT 'primary',
    PRIMARY KEY (customer_id, phone),
    FOREIGN KEY (customer_id) REFERENCES norm_2nf_customers(customer_id)
);

INSERT INTO norm_2nf_customers VALUES (1, 'Karthik Kumar'), (2, 'Priya Sharma');
INSERT INTO norm_2nf_phones VALUES
    (1, '+91-98765-43210', 'primary'),
    (1, '+91-76543-21098', 'secondary'),
    (2, '+91-87654-32109', 'primary');

-- Now full_name is stored ONCE per customer (not duplicated):
SELECT c.full_name, p.phone, p.phone_type
FROM norm_2nf_customers c
JOIN norm_2nf_phones p ON c.customer_id = p.customer_id;

-- ─────────────────────────────────────────────────────────────────────────
-- 17.4 THIRD NORMAL FORM (3NF)
-- ─────────────────────────────────────────────────────────────────────────
-- Rules:
-- ✅ Must be in 2NF
-- ✅ No TRANSITIVE DEPENDENCIES (non-key column depending on another non-key column)

-- Example of 3NF violation:
CREATE TABLE IF NOT EXISTS norm_bad_loan (
    loan_id          INT PRIMARY KEY,
    customer_id      INT,
    branch_code      VARCHAR(20),
    branch_city      VARCHAR(100),   -- depends on branch_code, NOT on loan_id!
    loan_amount      DECIMAL(15,2)
);

-- branch_city depends on branch_code (transitive dependency) → violates 3NF
-- If branch moves city, you'd update hundreds of loan rows!

-- FIX 3NF: Split out the transitive dependency:
CREATE TABLE IF NOT EXISTS norm_3nf_branches (
    branch_code  VARCHAR(20) PRIMARY KEY,
    branch_city  VARCHAR(100),
    branch_name  VARCHAR(150)
);

CREATE TABLE IF NOT EXISTS norm_3nf_loans (
    loan_id      INT PRIMARY KEY,
    customer_id  INT,
    branch_code  VARCHAR(20),
    loan_amount  DECIMAL(15,2),
    FOREIGN KEY (branch_code) REFERENCES norm_3nf_branches(branch_code)
);

-- Now branch_city is stored ONCE in norm_3nf_branches.
-- Changing a branch's city = one update in one table.

-- ─────────────────────────────────────────────────────────────────────────
-- 17.5 How bank_fraud_db is already normalized — verify it
-- ─────────────────────────────────────────────────────────────────────────

-- customers table: one row per customer (1NF ✅, 2NF ✅, 3NF ✅)
DESCRIBE customers;

-- customer_contact is split from customers (separate table = less redundancy):
DESCRIBE customer_contact;

-- customer_address is split from customers:
DESCRIBE customer_address;

-- accounts is separate from customers:
DESCRIBE accounts;

-- transactions is separate from accounts:
DESCRIBE transactions;

-- ─────────────────────────────────────────────────────────────────────────
-- 17.6 DENORMALIZATION — When breaking the rules is okay (performance)
-- ─────────────────────────────────────────────────────────────────────────
-- Sometimes we intentionally store redundant data for query speed:

-- Example: transactions.location_country is duplicated info
-- (you could JOIN to login_audit to get country) but storing it directly
-- makes fraud detection queries MUCH faster.

-- Check this pattern in our DB — the fraud detection query would be slow
-- without denormalized location_country in transactions:
SELECT
    t.transaction_id,
    t.amount,
    t.location_country           -- stored directly (denormalized)
FROM transactions t
WHERE t.location_country != 'India'
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 17.7 CLEANUP
-- ─────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS norm_2nf_phones;
DROP TABLE IF EXISTS norm_2nf_customers;
DROP TABLE IF EXISTS norm_1nf_customer;
DROP TABLE IF EXISTS norm_bad_contact;
DROP TABLE IF EXISTS norm_3nf_loans;
DROP TABLE IF EXISTS norm_3nf_branches;
DROP TABLE IF EXISTS norm_bad_loan;
