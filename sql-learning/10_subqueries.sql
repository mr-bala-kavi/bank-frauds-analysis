-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 10: SUBQUERIES
-- A query nested inside another query
-- Types: Scalar, Row, Column (IN), Correlated, EXISTS
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 10.1 SCALAR SUBQUERY — returns a SINGLE VALUE used in comparison
-- ─────────────────────────────────────────────────────────────────────────

-- Transactions above the overall average transaction amount:
SELECT transaction_id, amount
FROM transactions
WHERE amount > (SELECT AVG(amount) FROM transactions)
ORDER BY amount DESC
LIMIT 10;

-- Loans above average principal:
SELECT loan_id, loan_type, principal_amount
FROM loans
WHERE principal_amount > (SELECT AVG(principal_amount) FROM loans)
ORDER BY principal_amount DESC
LIMIT 10;

-- Accounts with balance above bank-wide average:
SELECT account_number, account_type, current_balance
FROM accounts
WHERE current_balance > (SELECT AVG(current_balance) FROM accounts)
ORDER BY current_balance DESC
LIMIT 10;

-- Income of a specific customer (embeds a lookup):
SELECT full_name, annual_income
FROM customers
WHERE annual_income = (SELECT MAX(annual_income) FROM customers);  -- richest customer

-- ─────────────────────────────────────────────────────────────────────────
-- 10.2 COLUMN SUBQUERY — returns a LIST of values (used with IN)
-- ─────────────────────────────────────────────────────────────────────────

-- Find customers who have had at least one fraud case:
SELECT full_name, nationality, risk_category
FROM customers
WHERE customer_id IN (
    SELECT DISTINCT customer_id FROM fraud_cases
)
LIMIT 10;

-- Find all accounts that have triggered a critical alert:
SELECT account_number, account_type, account_status
FROM accounts
WHERE account_id IN (
    SELECT DISTINCT account_id FROM alerts
    WHERE alert_severity = 'critical'
)
LIMIT 10;

-- Customers who NEVER had a fraud case (NOT IN pattern):
SELECT full_name, nationality
FROM customers
WHERE customer_id NOT IN (
    SELECT DISTINCT customer_id FROM fraud_cases
    WHERE customer_id IS NOT NULL
)
LIMIT 10;

-- Accounts with no transactions at all (dormant):
SELECT account_number, account_type, opened_date
FROM accounts
WHERE account_id NOT IN (
    SELECT DISTINCT account_id FROM transactions
)
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 10.3 ROW SUBQUERY — returns a SINGLE ROW (multiple columns)
-- ─────────────────────────────────────────────────────────────────────────

-- Find the customer with the exact max annual income:
SELECT full_name, annual_income, nationality
FROM customers
WHERE (annual_income, nationality) = (
    SELECT MAX(annual_income), nationality
    FROM customers
    WHERE nationality = 'India'
    LIMIT 1
);

-- ─────────────────────────────────────────────────────────────────────────
-- 10.4 CORRELATED SUBQUERY — Inner query references the outer query's row
-- Runs ONCE per row of the outer query (can be slow on large tables)
-- ─────────────────────────────────────────────────────────────────────────

-- Find customers whose balance is above average for their nationality:
SELECT
    c.full_name,
    c.nationality,
    a.current_balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
WHERE a.current_balance > (
    SELECT AVG(a2.current_balance)
    FROM accounts a2
    JOIN customers c2 ON c2.customer_id = a2.customer_id
    WHERE c2.nationality = c.nationality    -- correlates to outer query
)
LIMIT 10;

-- Transactions that are the largest for that specific account:
SELECT t.account_id, t.transaction_id, t.amount
FROM transactions t
WHERE t.amount = (
    SELECT MAX(t2.amount)
    FROM transactions t2
    WHERE t2.account_id = t.account_id    -- correlates to outer row
)
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 10.5 EXISTS / NOT EXISTS — Check if a subquery returns any rows
-- Faster than IN on large datasets when checking existence only
-- ─────────────────────────────────────────────────────────────────────────

-- Customers who have at least one fraud case (EXISTS):
SELECT c.full_name, c.risk_category
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM fraud_cases fc
    WHERE fc.customer_id = c.customer_id
)
LIMIT 10;

-- Accounts that HAVE at least one pending alert (EXISTS):
SELECT a.account_number, a.account_status
FROM accounts a
WHERE EXISTS (
    SELECT 1 FROM alerts al
    WHERE al.account_id = a.account_id
      AND al.status = 'open'
)
LIMIT 10;

-- Customers with NO alerts at all (NOT EXISTS):
SELECT c.full_name, c.nationality
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM alerts al
    JOIN accounts a ON al.account_id = a.account_id
    WHERE a.customer_id = c.customer_id
)
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 10.6 SUBQUERY IN SELECT clause (derived column)
-- ─────────────────────────────────────────────────────────────────────────

-- Show each customer with their total number of accounts:
SELECT
    c.full_name,
    c.nationality,
    (SELECT COUNT(*) FROM accounts a WHERE a.customer_id = c.customer_id) AS account_count,
    (SELECT SUM(current_balance) FROM accounts a WHERE a.customer_id = c.customer_id) AS total_balance
FROM customers c
LIMIT 10;

-- Each fraud case alongside the bank's average fraud amount:
SELECT
    fc.case_id,
    fc.case_type,
    fc.fraud_amount,
    (SELECT ROUND(AVG(fraud_amount),2) FROM fraud_cases) AS bank_avg_fraud,
    ROUND(fc.fraud_amount - (SELECT AVG(fraud_amount) FROM fraud_cases), 2) AS vs_average
FROM fraud_cases fc
ORDER BY fc.fraud_amount DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 10.7 SUBQUERY IN FROM clause (derived table / inline view)
-- ─────────────────────────────────────────────────────────────────────────

-- Treat a summarized query as a mini table:
SELECT
    nationality,
    customer_count,
    avg_income,
    CASE WHEN avg_income > 500000 THEN 'Affluent' ELSE 'Regular' END AS segment
FROM (
    SELECT
        nationality,
        COUNT(*)             AS customer_count,
        AVG(annual_income)   AS avg_income
    FROM customers
    GROUP BY nationality
) AS nationality_summary
ORDER BY avg_income DESC;

-- Second highest transaction amount (classic interview question):
SELECT MAX(amount) AS second_highest
FROM transactions
WHERE amount < (SELECT MAX(amount) FROM transactions);

-- Top 3 accounts per account type using subquery + LIMIT workaround:
SELECT *
FROM (
    SELECT
        account_number,
        account_type,
        current_balance,
        RANK() OVER (PARTITION BY account_type ORDER BY current_balance DESC) AS rnk
    FROM accounts
) AS ranked_accounts
WHERE rnk <= 3;
