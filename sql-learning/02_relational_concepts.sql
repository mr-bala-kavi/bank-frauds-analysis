-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 02: RELATIONAL DATABASE CONCEPTS
-- Learn: Tables, rows, columns, keys, relationships
-- Using: bank_fraud_db schema relationships
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 2.1 WHAT ARE TABLES, ROWS AND COLUMNS?
-- ─────────────────────────────────────────────────────────────────────────
-- TABLES  → like Excel sheets (customers, accounts, transactions)
-- ROWS    → each individual record (one customer, one account)
-- COLUMNS → fields/attributes (full_name, dob, account_number)

-- See a table's rows and columns:
SELECT * FROM customers LIMIT 5;
SELECT * FROM accounts  LIMIT 5;
SELECT * FROM transactions LIMIT 5;

-- ─────────────────────────────────────────────────────────────────────────
-- 2.2 PRIMARY KEY — Uniquely identifies each row
-- ─────────────────────────────────────────────────────────────────────────
-- customers.customer_id  → PRIMARY KEY (no two customers share it)
-- accounts.account_id    → PRIMARY KEY
-- transactions.transaction_id → PRIMARY KEY

-- Find the primary key columns of every table:
SELECT
    table_name,
    column_name       AS primary_key_column
FROM information_schema.columns
WHERE table_schema  = 'bank_fraud_db'
  AND column_key    = 'PRI'
ORDER BY table_name;

-- ─────────────────────────────────────────────────────────────────────────
-- 2.3 FOREIGN KEY — Links one table to another
-- ─────────────────────────────────────────────────────────────────────────
-- accounts.customer_id → references customers.customer_id
-- This is the RELATIONSHIP between the two tables.
-- accounts CANNOT have a customer_id that doesn't exist in customers.

-- See all foreign key relationships in the database:
SELECT
    kcu.table_name       AS child_table,
    kcu.column_name      AS foreign_key_column,
    kcu.referenced_table_name  AS parent_table,
    kcu.referenced_column_name AS parent_column
FROM information_schema.key_column_usage kcu
WHERE kcu.table_schema = 'bank_fraud_db'
  AND kcu.referenced_table_name IS NOT NULL
ORDER BY kcu.table_name;

-- ─────────────────────────────────────────────────────────────────────────
-- 2.4 ONE-TO-ONE RELATIONSHIP
-- ─────────────────────────────────────────────────────────────────────────
-- One customer → One contact record (customer_contact)
-- Each customer has exactly one row in customer_contact

SELECT
    c.customer_id,
    c.full_name,
    cc.email_primary,
    cc.phone_primary
FROM customers c
JOIN customer_contact cc ON c.customer_id = cc.customer_id
LIMIT 5;

-- ─────────────────────────────────────────────────────────────────────────
-- 2.5 ONE-TO-MANY RELATIONSHIP
-- ─────────────────────────────────────────────────────────────────────────
-- One customer → Many accounts (one person can have multiple accounts)
-- One account  → Many transactions

-- How many accounts does each customer have?
SELECT
    c.full_name,
    COUNT(a.account_id) AS total_accounts
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.full_name
ORDER BY total_accounts DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 2.6 MANY-TO-MANY RELATIONSHIP
-- ─────────────────────────────────────────────────────────────────────────
-- One customer can have many AML checks
-- One analyst can handle many fraud cases
-- Resolved using a bridging/junction table

-- Customers with multiple fraud case types (many cases linked to one customer):
SELECT
    c.full_name,
    GROUP_CONCAT(DISTINCT fc.case_type ORDER BY fc.case_type) AS fraud_types,
    COUNT(fc.case_id) AS case_count
FROM customers c
JOIN fraud_cases fc ON c.customer_id = fc.customer_id
GROUP BY c.customer_id, c.full_name
HAVING COUNT(fc.case_id) > 1
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 2.7 REFERENTIAL INTEGRITY
-- ─────────────────────────────────────────────────────────────────────────
-- Every account must belong to a real customer (FK constraint ensures this)
-- Orphan records = accounts with no matching customer (should be 0)

SELECT COUNT(*) AS orphan_accounts
FROM accounts a
LEFT JOIN customers c ON a.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Same for transactions → accounts:
SELECT COUNT(*) AS orphan_transactions
FROM transactions t
LEFT JOIN accounts a ON t.account_id = a.account_id
WHERE a.account_id IS NULL;

-- ─────────────────────────────────────────────────────────────────────────
-- 2.8 ENTITY RELATIONSHIP OVERVIEW (conceptual)
-- ─────────────────────────────────────────────────────────────────────────
-- customers (1) ──── (M) accounts (1) ──── (M) transactions
-- customers (1) ──── (M) loans
-- customers (1) ──── (1) customer_contact
-- customers (1) ──── (1) customer_address
-- customers (1) ──── (M) fraud_cases
-- customers (1) ──── (M) alerts
-- customers (1) ──── (M) login_audit
-- accounts  (1) ──── (M) cards
-- accounts  (1) ──── (M) alerts
-- accounts  (1) ──── (M) fraud_cases
