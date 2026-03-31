-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 18: DATABASE DESIGN
-- Learn: ER diagrams, table relationships, naming conventions, best practices
-- Using: bank_fraud_db as a reference design
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 18.1 THE 15-TABLE SCHEMA OF bank_fraud_db — understand the design
-- ─────────────────────────────────────────────────────────────────────────
-- Core entities:
-- customers              → Who the bank serves
-- customer_contact       → emails, phones (1:1 with customers)
-- customer_address       → city, state, country (1:1)
-- customer_identity_docs → PAN, Aadhaar, Passport (1:1)

-- Account entities:
-- accounts               → Bank accounts (M:1 with customers)
-- cards                  → Debit/Credit cards (M:1 with accounts)

-- Transaction entities:
-- transactions           → All money movements (M:1 with accounts)
-- beneficiaries          → Saved beneficiaries (M:1 with customers)

-- Loan entity:
-- loans                  → Loans issued (M:1 customers + M:1 accounts)

-- Infrastructure:
-- branches               → Physical branch offices

-- Compliance & Fraud:
-- fraud_cases            → Fraud case management
-- alerts                 → Auto-triggered fraud alerts
-- aml_screening          → Anti-money laundering checks
-- login_audit            → All login events

-- ─────────────────────────────────────────────────────────────────────────
-- 18.2 NAMING CONVENTIONS used in bank_fraud_db
-- ─────────────────────────────────────────────────────────────────────────
-- Tables      : lowercase_snake_case (e.g., fraud_cases, login_audit)
-- Columns     : lowercase_snake_case (e.g., full_name, current_balance)
-- Primary Keys: singular_table + _id  (customer_id, account_id)
-- Foreign Keys: same name as referenced PK (customer_id in accounts)
-- Views       : v_ prefix (v_customer_360, v_suspicious_transactions)
-- Procedures  : sp_ prefix (sp_freeze_account, sp_close_fraud_case)
-- Triggers    : trg_ prefix
-- Indexes     : idx_ prefix (idx_customer_id, idx_txn_date)

-- ─────────────────────────────────────────────────────────────────────────
-- 18.3 CHOOSING THE RIGHT DATA TYPES
-- ─────────────────────────────────────────────────────────────────────────

-- Review data types used in the real schema:
SELECT
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale
FROM information_schema.columns
WHERE table_schema = 'bank_fraud_db'
  AND table_name IN ('customers', 'accounts', 'transactions')
ORDER BY table_name, ordinal_position;

-- Common data type choices:
-- TINYINT(1)     → Boolean flags (0/1): fraud_flag, is_suspicious, pep_flag
-- INT            → IDs and counts (no decimals needed)
-- BIGINT         → Very large integers
-- DECIMAL(15,2)  → Money values (exact precision, avoids floating point errors)
-- FLOAT/DOUBLE   → Scientific calculations (not for money!)
-- VARCHAR(N)     → Variable-length text (store what you need, up to N)
-- CHAR(N)        → Fixed-length text (SWIFT codes, country codes)
-- TEXT           → Long free-form text (notes, descriptions)
-- DATE           → Date only (2023-01-15)
-- TIME           → Time only (14:30:00)
-- DATETIME       → Date + time without timezone
-- TIMESTAMP      → Date + time, auto-updates, timezone-aware
-- UUID / CHAR(36)→ Globally unique IDs (used for customer_id, account_id)
-- JSON           → Flexible structured data (match_details in aml_screening)
-- ENUM           → Fixed list of options (account_type, account_status)

-- ─────────────────────────────────────────────────────────────────────────
-- 18.4 DESIGNING A NEW TABLE — step-by-step
-- ─────────────────────────────────────────────────────────────────────────
-- Requirement: Track customer feedback/complaints

CREATE TABLE IF NOT EXISTS customer_complaints (
    -- Identity
    complaint_id     INT           AUTO_INCREMENT PRIMARY KEY,

    -- Foreign Keys (links to parent tables)
    customer_id      VARCHAR(100)  NOT NULL,
    account_id       VARCHAR(100),  -- nullable (complaint might not relate to an account)

    -- Core data
    complaint_type   ENUM('transaction','service','fraud','loan','other') NOT NULL,
    severity         ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
    subject          VARCHAR(500)  NOT NULL,
    description      TEXT,

    -- Status tracking
    status           ENUM('open','in_progress','resolved','closed') NOT NULL DEFAULT 'open',
    assigned_to      VARCHAR(100),
    resolution_notes TEXT,

    -- Timestamps (always include these!)
    created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                   ON UPDATE CURRENT_TIMESTAMP,
    resolved_at      DATETIME,     -- NULL until resolved

    -- Constraints
    CONSTRAINT fk_complaint_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT chk_resolved_date
        CHECK (resolved_at IS NULL OR resolved_at >= created_at)
);

-- Add performance indexes on commonly filtered columns:
CREATE INDEX idx_complaint_customer ON customer_complaints(customer_id);
CREATE INDEX idx_complaint_status   ON customer_complaints(status);
CREATE INDEX idx_complaint_created  ON customer_complaints(created_at);

-- Test the design:
SELECT
    cc.complaint_id,
    c.full_name,
    cc.complaint_type,
    cc.severity,
    cc.status,
    cc.created_at
FROM customer_complaints cc
JOIN customers c ON c.customer_id = cc.customer_id
ORDER BY cc.created_at DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 18.5 DESIGN BEST PRACTICES — Always follow these
-- ─────────────────────────────────────────────────────────────────────────
-- ✅ Every table needs a PRIMARY KEY
-- ✅ Use FOREIGN KEYS to enforce relationships
-- ✅ Always include created_at and updated_at timestamps
-- ✅ Use NOT NULL for required fields
-- ✅ Use ENUM for fixed value sets (don't use open VARCHAR for status)
-- ✅ Use DECIMAL for money, never FLOAT
-- ✅ Index all FOREIGN KEY columns
-- ✅ Index columns you frequently filter (WHERE) or sort (ORDER BY)
-- ✅ Normalize to at least 3NF
-- ✅ Use meaningful column names (not col1, val2, etc.)
-- ❌ Don't use SELECT * in production code
-- ❌ Don't store calculated values that can be derived (e.g., total = qty * price)
-- ❌ Don't use reserved words as column names (date, name, value, key)

-- ─────────────────────────────────────────────────────────────────────────
-- 18.6 Entity Relationship Summary of bank_fraud_db
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns c
     WHERE c.table_schema = t.table_schema AND c.table_name = t.table_name) AS column_count
FROM information_schema.tables t
WHERE table_schema = 'bank_fraud_db'
  AND table_type   = 'BASE TABLE'
ORDER BY table_name;

-- ─────────────────────────────────────────────────────────────────────────
-- 18.7 CLEANUP
-- ─────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS customer_complaints;
