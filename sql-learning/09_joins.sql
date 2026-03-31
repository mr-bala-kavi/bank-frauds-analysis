-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 09: JOINS
-- Types: INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL JOIN, SELF JOIN
-- Joins combine data from multiple tables using a shared column.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 9.1 INNER JOIN — Only returns rows that match in BOTH tables
-- ─────────────────────────────────────────────────────────────────────────
-- Customers who HAVE accounts (excludes customers with no account):
SELECT
    c.customer_id,
    c.full_name,
    c.nationality,
    a.account_number,
    a.account_type,
    a.current_balance
FROM customers c
INNER JOIN accounts a ON c.customer_id = a.customer_id
LIMIT 10;

-- 2-table join: Accounts → Customer names:
SELECT
    a.account_number,
    a.account_type,
    a.current_balance,
    c.full_name,
    c.risk_category
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id     -- JOIN = INNER JOIN
WHERE a.current_balance > 500000
ORDER BY a.current_balance DESC
LIMIT 10;

-- 3-table join: Transactions → Accounts → Customers:
SELECT
    t.transaction_id,
    t.amount,
    t.transaction_type,
    t.transaction_date,
    a.account_number,
    c.full_name,
    c.risk_category
FROM transactions t
JOIN accounts  a ON t.account_id  = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.amount > 100000
ORDER BY t.amount DESC
LIMIT 10;

-- 4-table join: Fraud Cases → Customers → Accounts → Alerts:
SELECT
    fc.case_id,
    fc.case_type,
    fc.fraud_amount,
    c.full_name,
    a.account_number,
    al.alert_severity
FROM fraud_cases fc
JOIN customers c ON fc.customer_id = c.customer_id
JOIN accounts  a ON fc.account_id  = a.account_id
JOIN alerts   al ON al.account_id  = a.account_id
WHERE fc.case_status = 'confirmed'
LIMIT 10;

-- Loans with customer info:
SELECT
    l.loan_id,
    l.loan_type,
    l.principal_amount,
    l.interest_rate,
    l.loan_status,
    c.full_name,
    c.annual_income
FROM loans l
JOIN customers c ON l.customer_id = c.customer_id
ORDER BY l.principal_amount DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 9.2 LEFT JOIN — All rows from LEFT table + matching rows from RIGHT
--              → NULLs appear for unmatched right table columns
-- ─────────────────────────────────────────────────────────────────────────

-- All customers, even those without loans (NULL = no loan):
SELECT
    c.full_name,
    c.nationality,
    l.loan_id,
    l.loan_type,
    l.principal_amount
FROM customers c
LEFT JOIN loans l ON l.customer_id = c.customer_id
LIMIT 20;

-- Find customers who have NO loans (anti-join pattern):
SELECT
    c.full_name,
    c.nationality,
    c.risk_category
FROM customers c
LEFT JOIN loans l ON l.customer_id = c.customer_id
WHERE l.loan_id IS NULL           -- NULL means no matching loan
LIMIT 10;

-- All accounts, even those with NO transactions:
SELECT
    a.account_number,
    a.account_type,
    t.transaction_id,
    t.amount
FROM accounts a
LEFT JOIN transactions t ON t.account_id = a.account_id
WHERE t.transaction_id IS NULL   -- dormant accounts
LIMIT 10;

-- All customers + their fraud cases (NULL = innocent):
SELECT
    c.full_name,
    c.risk_category,
    fc.case_id,
    fc.case_type,
    fc.fraud_amount
FROM customers c
LEFT JOIN fraud_cases fc ON fc.customer_id = c.customer_id
ORDER BY fc.fraud_amount DESC
LIMIT 20;

-- ─────────────────────────────────────────────────────────────────────────
-- 9.3 RIGHT JOIN — All rows from RIGHT table + matching rows from LEFT
--               → NULLs appear for unmatched left table columns
-- ─────────────────────────────────────────────────────────────────────────
-- Less commonly used (can rewrite as LEFT JOIN by swapping table order)

-- All fraud cases, even if the customer record is missing:
SELECT
    c.full_name,
    fc.case_id,
    fc.case_type,
    fc.fraud_amount
FROM customers c
RIGHT JOIN fraud_cases fc ON c.customer_id = fc.customer_id
LIMIT 10;

-- Accounts that have alerts (right = all alerts):
SELECT
    a.account_number,
    al.alert_id,
    al.alert_severity,
    al.alert_type
FROM accounts a
RIGHT JOIN alerts al ON a.account_id = al.account_id
WHERE al.alert_severity = 'critical'
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 9.4 FULL OUTER JOIN (MySQL doesn't support this natively)
-- Simulate with LEFT JOIN UNION RIGHT JOIN
-- Returns ALL rows from both tables, NULLs on non-matching side
-- ─────────────────────────────────────────────────────────────────────────

-- All customers + all fraud cases (even unmatched on both sides):
SELECT
    c.full_name,
    fc.case_id,
    fc.case_type,
    fc.fraud_amount
FROM customers c
LEFT JOIN fraud_cases fc ON c.customer_id = fc.customer_id

UNION

SELECT
    c.full_name,
    fc.case_id,
    fc.case_type,
    fc.fraud_amount
FROM customers c
RIGHT JOIN fraud_cases fc ON c.customer_id = fc.customer_id
LIMIT 30;

-- ─────────────────────────────────────────────────────────────────────────
-- 9.5 SELF JOIN — A table joined to ITSELF
-- Used to compare rows within the same table
-- ─────────────────────────────────────────────────────────────────────────

-- Find customers from the same city (customer_address self-join):
SELECT
    a1.customer_id AS cust1,
    a2.customer_id AS cust2,
    a1.city
FROM customer_address a1
JOIN customer_address a2
    ON  a1.city = a2.city
    AND a1.customer_id < a2.customer_id    -- prevent duplicate pairs / self-match
LIMIT 15;

-- Find transactions where money returned to same account (round trip):
SELECT
    t1.transaction_id           AS outgoing_txn,
    t2.transaction_id           AS incoming_txn,
    t1.account_id,
    t1.amount                   AS sent,
    t2.amount                   AS received,
    t1.transaction_date         AS sent_date,
    t2.transaction_date         AS received_date
FROM transactions t1
JOIN transactions t2
    ON  t2.account_id       = t1.account_id
    AND t2.transaction_type = 'credit'
    AND t1.transaction_type = 'debit'
    AND t2.transaction_id  != t1.transaction_id
    AND ABS(t2.amount - t1.amount) / t1.amount < 0.05   -- within 5% of original
WHERE t1.amount > 50000
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 9.6 JOIN with aggregate functions (JOIN + GROUP BY together)
-- ─────────────────────────────────────────────────────────────────────────

-- Total transaction volume per customer:
SELECT
    c.full_name,
    c.nationality,
    COUNT(t.transaction_id)          AS total_txns,
    ROUND(SUM(t.amount), 2)          AS total_volume,
    ROUND(AVG(t.amount), 2)          AS avg_txn_amount
FROM customers c
JOIN accounts  a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id = a.account_id
GROUP BY c.customer_id, c.full_name, c.nationality
ORDER BY total_volume DESC
LIMIT 10;

-- Branch-wise wealth:
SELECT
    a.branch_code,
    COUNT(a.account_id)              AS account_count,
    SUM(a.current_balance)           AS branch_total_balance
FROM accounts a
GROUP BY a.branch_code
ORDER BY branch_total_balance DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 9.7 CROSS JOIN — Every row from table A × every row from table B
-- (Rarely used in practice — creates Cartesian Product)
-- ─────────────────────────────────────────────────────────────────────────
-- Example: Pair every loan type with every account type (for a report template)
SELECT DISTINCT a.account_type, l.loan_type
FROM accounts a
CROSS JOIN loans l
ORDER BY a.account_type, l.loan_type;
