-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 20: CTE — COMMON TABLE EXPRESSIONS
-- WITH keyword — creates a named temporary result set
-- Makes complex queries readable and reusable within a single query.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 20.1 BASIC CTE — Simple named query block
-- ─────────────────────────────────────────────────────────────────────────

-- Without CTE (ugly nested subquery):
SELECT nationality, customer_count
FROM (
    SELECT nationality, COUNT(*) AS customer_count
    FROM customers
    GROUP BY nationality
) AS counts
WHERE customer_count > 1000;

-- WITH CTE (clean and readable):
WITH nationality_counts AS (
    SELECT nationality, COUNT(*) AS customer_count
    FROM customers
    GROUP BY nationality
)
SELECT nationality, customer_count
FROM nationality_counts
WHERE customer_count > 1000
ORDER BY customer_count DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- 20.2 CTE for FRAUD ANALYSIS — Structuring detection
-- ─────────────────────────────────────────────────────────────────────────

WITH structured_transactions AS (
    SELECT
        account_id,
        transaction_date,
        COUNT(*)        AS txn_count,
        SUM(amount)     AS total
    FROM transactions
    WHERE amount BETWEEN 180000 AND 199999
      AND transaction_type = 'debit'
    GROUP BY account_id, transaction_date
    HAVING COUNT(*) >= 3
)
SELECT
    s.account_id,
    a.account_number,
    c.full_name,
    c.risk_category,
    s.transaction_date,
    s.txn_count,
    s.total
FROM structured_transactions s
JOIN accounts  a ON a.account_id  = s.account_id
JOIN customers c ON c.customer_id = a.customer_id
ORDER BY s.txn_count DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 20.3 MULTIPLE CTEs — Chain several named blocks
-- ─────────────────────────────────────────────────────────────────────────

WITH
-- CTE 1: High-risk customers
high_risk_customers AS (
    SELECT customer_id, full_name, annual_income, risk_category
    FROM customers
    WHERE risk_category IN ('high', 'very_high')
),

-- CTE 2: Their frozen accounts
frozen_accounts AS (
    SELECT a.account_id, a.account_number, a.current_balance, a.customer_id
    FROM accounts a
    WHERE a.account_status = 'frozen'
),

-- CTE 3: Unresolved fraud cases
open_fraud AS (
    SELECT fc.customer_id, COUNT(*) AS open_cases, SUM(fc.fraud_amount) AS total_fraud
    FROM fraud_cases fc
    WHERE fc.case_status IN ('reported', 'investigating')
    GROUP BY fc.customer_id
)

-- Final query joins all 3 CTEs:
SELECT
    h.full_name,
    h.risk_category,
    h.annual_income,
    f.account_number,
    f.current_balance,
    o.open_cases,
    o.total_fraud
FROM high_risk_customers h
JOIN frozen_accounts f ON f.customer_id = h.customer_id
JOIN open_fraud      o ON o.customer_id = h.customer_id
ORDER BY o.total_fraud DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 20.4 CTE WITH WINDOW FUNCTIONS (very powerful combination)
-- ─────────────────────────────────────────────────────────────────────────

-- Find the top transaction for each customer (using window function inside CTE):
WITH ranked_transactions AS (
    SELECT
        t.transaction_id,
        t.account_id,
        t.amount,
        t.transaction_date,
        a.customer_id,
        ROW_NUMBER() OVER (
            PARTITION BY a.customer_id
            ORDER BY t.amount DESC
        ) AS rank_by_amount
    FROM transactions t
    JOIN accounts a ON a.account_id = t.account_id
)
SELECT
    rt.customer_id,
    c.full_name,
    rt.transaction_id,
    rt.amount        AS highest_txn,
    rt.transaction_date
FROM ranked_transactions rt
JOIN customers c ON c.customer_id = rt.customer_id
WHERE rt.rank_by_amount = 1    -- only the top transaction per customer
ORDER BY rt.amount DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 20.5 RECURSIVE CTE — Query hierarchical or graph data
-- ─────────────────────────────────────────────────────────────────────────
-- Syntax: first part is the anchor (starting rows)
--         second part (after UNION ALL) references the CTE itself

-- Generate a number sequence from 1 to 10:
WITH RECURSIVE number_series AS (
    SELECT 1 AS n               -- anchor: start at 1
    UNION ALL
    SELECT n + 1                -- recursive: add 1 each time
    FROM number_series
    WHERE n < 10                -- stop condition
)
SELECT n FROM number_series;

-- Generate months in a year:
WITH RECURSIVE months AS (
    SELECT 1 AS month_num, 'January' AS month_name
    UNION ALL
    SELECT
        month_num + 1,
        MONTHNAME(DATE_ADD('2023-01-01', INTERVAL month_num MONTH))
    FROM months
    WHERE month_num < 12
)
SELECT * FROM months;

-- REAL FRAUD USE CASE: Trace money trail (A → B → C → D):
WITH RECURSIVE money_trail AS (
    -- Anchor: start from mule account debit transactions
    SELECT
        transaction_id,
        account_id          AS from_account,
        beneficiary_account_id AS to_account,
        amount,
        transaction_date,
        1                   AS hop,
        CAST(transaction_id AS CHAR(500)) AS path
    FROM transactions
    WHERE fraud_type = 'mule_account'
      AND transaction_type = 'debit'
    LIMIT 5

    UNION ALL

    -- Recursive: follow the money to the next hop
    SELECT
        t.transaction_id,
        t.account_id,
        t.beneficiary_account_id,
        t.amount,
        t.transaction_date,
        mt.hop + 1,
        CONCAT(mt.path, ' → ', t.transaction_id)
    FROM transactions t
    JOIN money_trail mt
        ON  t.account_id = mt.to_account
        AND t.transaction_date >= mt.transaction_date
    WHERE mt.hop < 4    -- stop at 4 hops
)
SELECT
    hop,
    from_account,
    to_account,
    ROUND(amount, 2) AS amount,
    transaction_date,
    path
FROM money_trail
ORDER BY path, hop;

-- ─────────────────────────────────────────────────────────────────────────
-- 20.6 CTE in UPDATE (MySQL 8.0+)
-- ─────────────────────────────────────────────────────────────────────────
-- Find and update all accounts belonging to very-high-risk customers:
-- (Use with caution — this modifies real data)

-- Dry run: just SELECT what would be updated:
WITH very_high_risk_accounts AS (
    SELECT a.account_id
    FROM accounts a
    JOIN customers c ON c.customer_id = a.customer_id
    WHERE c.risk_category = 'very_high'
      AND a.account_status = 'active'
)
SELECT account_id FROM very_high_risk_accounts LIMIT 5;

-- ─────────────────────────────────────────────────────────────────────────
-- 20.7 CTE vs Subquery vs View — When to use each
-- ─────────────────────────────────────────────────────────────────────────
-- CTE     → Complex single-query logic, readable, reused within ONE query
-- Subquery → Simple one-off inline, or correlated row-by-row logic
-- VIEW    → Logic reused across MULTIPLE queries, long-term, stored in DB

-- Summary example comparing all three approaches:

-- SUBQUERY approach:
SELECT full_name FROM customers
WHERE customer_id IN (SELECT DISTINCT customer_id FROM fraud_cases);

-- CTE approach:
WITH fraud_customers AS (SELECT DISTINCT customer_id FROM fraud_cases)
SELECT c.full_name FROM customers c
JOIN fraud_customers fc ON c.customer_id = fc.customer_id;

-- VIEW approach (create once, query forever):
-- CREATE VIEW vw_fraud_customers AS SELECT DISTINCT customer_id FROM fraud_cases;
-- SELECT c.full_name FROM customers c JOIN vw_fraud_customers fc ON c.customer_id = fc.customer_id;
