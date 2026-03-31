-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 11: INDEXES
-- Indexes speed up SELECT queries by avoiding full table scans.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 11.1 WHY INDEXES? — Without an index, MySQL reads EVERY row (full scan)
--                     With an index, MySQL jumps directly to matching rows
-- ─────────────────────────────────────────────────────────────────────────

-- This query on transactions WITHOUT an index = scans 100,000+ rows:
SELECT * FROM transactions WHERE account_id = 'some-uuid';

-- With an index on account_id → MySQL finds it instantly.

-- ─────────────────────────────────────────────────────────────────────────
-- 11.2 SHOW existing indexes on tables
-- ─────────────────────────────────────────────────────────────────────────
SHOW INDEX FROM customers;
SHOW INDEX FROM accounts;
SHOW INDEX FROM transactions;
SHOW INDEX FROM loans;
SHOW INDEX FROM alerts;

-- See all indexes in the database:
SELECT
    table_name,
    index_name,
    column_name,
    non_unique,
    seq_in_index
FROM information_schema.statistics
WHERE table_schema = 'bank_fraud_db'
ORDER BY table_name, index_name, seq_in_index;

-- ─────────────────────────────────────────────────────────────────────────
-- 11.3 CREATE INDEX — Add an index on a column
-- ─────────────────────────────────────────────────────────────────────────

-- Simple single-column index (for WHERE filtering):
CREATE INDEX idx_txn_amount
    ON transactions(amount);

-- Index on date (for date range queries):
CREATE INDEX idx_txn_date
    ON transactions(transaction_date);

-- Index on text column:
CREATE INDEX idx_customer_nationality
    ON customers(nationality);

-- Index on account status (for status filtering):
CREATE INDEX idx_acc_status
    ON accounts(account_status);

-- ─────────────────────────────────────────────────────────────────────────
-- 11.4 COMPOSITE INDEX — Index on multiple columns (order matters!)
-- ─────────────────────────────────────────────────────────────────────────
-- Use when you filter by multiple columns together frequently

CREATE INDEX idx_txn_type_date
    ON transactions(transaction_type, transaction_date);
-- This helps: WHERE transaction_type = 'debit' AND transaction_date = '2023-01-01'
-- Tip: Put the most selective column first

CREATE INDEX idx_loans_status_type
    ON loans(loan_status, loan_type);

-- ─────────────────────────────────────────────────────────────────────────
-- 11.5 UNIQUE INDEX — No duplicate values allowed in the indexed column
-- ─────────────────────────────────────────────────────────────────────────
-- (PRIMARY KEY creates one automatically)

CREATE UNIQUE INDEX idx_unique_account_number
    ON accounts(account_number);         -- each account number must be unique

-- ─────────────────────────────────────────────────────────────────────────
-- 11.6 FULLTEXT INDEX — For text searching (LIKE %word% is slow)
-- ─────────────────────────────────────────────────────────────────────────
CREATE FULLTEXT INDEX idx_ft_alert_message
    ON alerts(alert_message);

-- Now you can search using MATCH...AGAINST (much faster than LIKE):
SELECT alert_id, alert_message
FROM alerts
WHERE MATCH(alert_message) AGAINST('fraud suspicious' IN NATURAL LANGUAGE MODE)
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 11.7 EXPLAIN — See if your query is USING the index or doing a full scan
-- ─────────────────────────────────────────────────────────────────────────

-- Check query execution plan (does it use an index?):
EXPLAIN SELECT * FROM transactions WHERE amount > 500000;
-- Look at 'key' column: if it shows an index name, it's using the index
-- If 'type' = 'ALL' → full table scan (bad for large tables)
-- If 'type' = 'range' or 'ref' → index is being used (good!)

EXPLAIN SELECT * FROM accounts WHERE account_status = 'frozen';

EXPLAIN SELECT * FROM customers WHERE nationality = 'India';

-- EXPLAIN ANALYZE (MySQL 8.0+ — shows actual execution stats):
EXPLAIN ANALYZE
SELECT * FROM transactions
WHERE transaction_type = 'debit' AND amount BETWEEN 100000 AND 200000;

-- ─────────────────────────────────────────────────────────────────────────
-- 11.8 DROP INDEX — Remove an index
-- ─────────────────────────────────────────────────────────────────────────
DROP INDEX idx_txn_amount           ON transactions;
DROP INDEX idx_txn_date             ON transactions;
DROP INDEX idx_customer_nationality ON customers;
DROP INDEX idx_acc_status           ON accounts;
DROP INDEX idx_txn_type_date        ON transactions;
DROP INDEX idx_loans_status_type    ON loans;
DROP INDEX idx_unique_account_number ON accounts;
DROP INDEX idx_ft_alert_message     ON alerts;

-- ─────────────────────────────────────────────────────────────────────────
-- 11.9 INDEX BEST PRACTICES
-- ─────────────────────────────────────────────────────────────────────────
-- ✅ Index columns used in WHERE, JOIN ON, ORDER BY, GROUP BY
-- ✅ Index FOREIGN KEY columns (almost always should be indexed)
-- ✅ Use composite indexes for multi-column WHERE clauses
-- ❌ Don't index every column — indexes slow down INSERT/UPDATE/DELETE
-- ❌ Don't index low-cardinality columns (e.g., gender, boolean)
-- ❌ Avoid indexes on rarely-queried columns

-- Check table size vs index size:
SELECT
    table_name,
    ROUND(data_length  / 1024 / 1024, 2) AS data_mb,
    ROUND(index_length / 1024 / 1024, 2) AS index_mb
FROM information_schema.tables
WHERE table_schema = 'bank_fraud_db'
ORDER BY data_mb DESC;
