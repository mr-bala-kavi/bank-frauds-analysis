-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 07: SORTING & GROUPING
-- Commands: ORDER BY, GROUP BY, HAVING
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 7.1 ORDER BY — Sort result rows
-- ─────────────────────────────────────────────────────────────────────────

-- ASC (ascending) = smallest to largest, A to Z, oldest to newest (DEFAULT)
-- DESC (descending) = largest to smallest, Z to A, newest to oldest

-- Sort customers by name alphabetically:
SELECT full_name, nationality, annual_income
FROM customers
ORDER BY full_name ASC
LIMIT 10;

-- Sort by income — richest first:
SELECT full_name, annual_income
FROM customers
ORDER BY annual_income DESC
LIMIT 10;

-- Sort transactions by amount — largest first:
SELECT transaction_id, amount, transaction_date
FROM transactions
ORDER BY amount DESC
LIMIT 10;

-- Sort by date — most recent first:
SELECT transaction_id, transaction_date, amount
FROM transactions
ORDER BY transaction_date DESC
LIMIT 10;

-- MULTI-COLUMN sort (primary: severity, secondary: date):
SELECT alert_id, alert_severity, alert_date, alert_type
FROM alerts
ORDER BY
    FIELD(alert_severity, 'critical','high','medium','low'),  -- custom severity order
    alert_date DESC
LIMIT 15;

-- Sort loans by interest rate descending, then principal ascending:
SELECT loan_id, loan_type, interest_rate, principal_amount
FROM loans
ORDER BY interest_rate DESC, principal_amount ASC
LIMIT 10;

-- Sort by a calculated column alias:
SELECT
    full_name,
    annual_income,
    annual_income / 12 AS monthly_income
FROM customers
ORDER BY monthly_income DESC
LIMIT 10;

-- ORDER BY column position (position 2 = second column in SELECT):
SELECT full_name, annual_income, risk_category
FROM customers
ORDER BY 2 DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 7.2 GROUP BY — Collapse rows into groups and calculate aggregates
-- ─────────────────────────────────────────────────────────────────────────
-- GROUP BY answers: "How many / how much per [group]?"

-- How many customers per nationality?
SELECT
    nationality,
    COUNT(*) AS customer_count
FROM customers
GROUP BY nationality
ORDER BY customer_count DESC;

-- Total transactions by type (credit vs debit):
SELECT
    transaction_type,
    COUNT(*)        AS txn_count,
    SUM(amount)     AS total_amount
FROM transactions
GROUP BY transaction_type;

-- Average balance by account type:
SELECT
    account_type,
    COUNT(*)                AS accounts,
    ROUND(AVG(current_balance), 2) AS avg_balance,
    SUM(current_balance)    AS total_balance
FROM accounts
GROUP BY account_type
ORDER BY avg_balance DESC;

-- Transaction count per day (daily volume):
SELECT
    transaction_date,
    COUNT(*)    AS txns_today,
    SUM(amount) AS daily_volume
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date DESC
LIMIT 30;

-- Fraud cases grouped by type:
SELECT
    case_type,
    case_status,
    COUNT(*)             AS case_count,
    SUM(fraud_amount)    AS total_fraud_amount
FROM fraud_cases
GROUP BY case_type, case_status
ORDER BY total_fraud_amount DESC;

-- Logins grouped by status:
SELECT
    login_status,
    COUNT(*) AS login_count
FROM login_audit
GROUP BY login_status;

-- Cards grouped by issuer network:
SELECT
    issuer_network,
    card_type,
    COUNT(*) AS card_count
FROM cards
GROUP BY issuer_network, card_type
ORDER BY card_count DESC;

-- Monthly transaction summary (real analyst dashboard):
SELECT
    DATE_FORMAT(transaction_date, '%Y-%m') AS year_month,
    COUNT(*)                               AS txn_count,
    SUM(amount)                            AS total_volume,
    AVG(amount)                            AS avg_amount,
    MAX(amount)                            AS largest_txn
FROM transactions
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY year_month DESC
LIMIT 12;

-- ─────────────────────────────────────────────────────────────────────────
-- 7.3 HAVING — Filter AFTER grouping (WHERE filters before grouping)
-- ─────────────────────────────────────────────────────────────────────────
-- Rule: Use WHERE for row-level filters, HAVING for aggregate filters.

-- Nationalities with more than 5,000 customers:
SELECT
    nationality,
    COUNT(*) AS cnt
FROM customers
GROUP BY nationality
HAVING COUNT(*) > 5000
ORDER BY cnt DESC;

-- Account types holding more than ₹100 million total:
SELECT
    account_type,
    SUM(current_balance) AS total_balance
FROM accounts
GROUP BY account_type
HAVING SUM(current_balance) > 100000000
ORDER BY total_balance DESC;

-- Transaction modes used more than 10,000 times:
SELECT
    transaction_mode,
    COUNT(*) AS usage_count
FROM transactions
GROUP BY transaction_mode
HAVING COUNT(*) > 10000
ORDER BY usage_count DESC;

-- Accounts with more than 5 transactions in our dataset:
SELECT
    account_id,
    COUNT(*) AS txn_count,
    SUM(amount) AS total
FROM transactions
GROUP BY account_id
HAVING COUNT(*) > 5
ORDER BY txn_count DESC
LIMIT 10;

-- Branches holding more than ₹200 million:
SELECT
    branch_code,
    COUNT(*)                 AS accounts,
    SUM(current_balance)     AS branch_wealth
FROM accounts
GROUP BY branch_code
HAVING SUM(current_balance) > 200000000
ORDER BY branch_wealth DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- 7.4 WHERE vs HAVING — side by side comparison
-- ─────────────────────────────────────────────────────────────────────────

-- WHERE filters ROWS before grouping:
SELECT nationality, COUNT(*) AS cnt
FROM customers
WHERE annual_income > 500000            -- first filter rows
GROUP BY nationality;

-- HAVING filters GROUPS after grouping:
SELECT nationality, COUNT(*) AS cnt
FROM customers
GROUP BY nationality
HAVING COUNT(*) > 1000;                 -- then filter groups

-- BOTH together (common real-world pattern):
SELECT
    nationality,
    COUNT(*) AS high_income_customers
FROM customers
WHERE annual_income > 500000            -- only high-income rows go into groups
GROUP BY nationality
HAVING COUNT(*) > 500                   -- only nationalities with 500+ such customers
ORDER BY high_income_customers DESC;
