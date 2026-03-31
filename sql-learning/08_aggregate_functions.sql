-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 08: AGGREGATE FUNCTIONS
-- Functions: COUNT, SUM, AVG, MIN, MAX
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 8.1 COUNT — Count rows or non-NULL values
-- ─────────────────────────────────────────────────────────────────────────

-- Count ALL rows (includes NULLs):
SELECT COUNT(*) AS total_customers    FROM customers;
SELECT COUNT(*) AS total_accounts     FROM accounts;
SELECT COUNT(*) AS total_transactions FROM transactions;
SELECT COUNT(*) AS total_fraud_cases  FROM fraud_cases;
SELECT COUNT(*) AS total_alerts       FROM alerts;

-- Count only non-NULL values in a column:
SELECT COUNT(merchant_name) AS txns_with_merchant  FROM transactions;
-- This gives a lower number than COUNT(*) because some merchant_name = NULL

-- COUNT with WHERE filter:
SELECT COUNT(*) AS indian_customers
FROM customers
WHERE nationality = 'India';

SELECT COUNT(*) AS open_alerts
FROM alerts
WHERE status = 'open';

SELECT COUNT(*) AS frozen_accounts
FROM accounts
WHERE account_status = 'frozen';

-- COUNT with GROUP BY (count per category):
SELECT
    nationality,
    COUNT(*) AS customer_count
FROM customers
GROUP BY nationality
ORDER BY customer_count DESC;

SELECT
    risk_category,
    COUNT(*) AS cnt
FROM customers
GROUP BY risk_category;

SELECT
    alert_severity,
    COUNT(*) AS alert_count
FROM alerts
GROUP BY alert_severity;

-- COUNT DISTINCT (count unique values only):
SELECT COUNT(DISTINCT nationality)     AS unique_nationalities   FROM customers;
SELECT COUNT(DISTINCT transaction_mode) AS unique_modes          FROM transactions;
SELECT COUNT(DISTINCT branch_code)     AS unique_branches        FROM accounts;
SELECT COUNT(DISTINCT beneficiary_name) AS unique_beneficiaries  FROM transactions;

-- ─────────────────────────────────────────────────────────────────────────
-- 8.2 SUM — Total of numeric values
-- ─────────────────────────────────────────────────────────────────────────

-- Total wealth managed by the bank:
SELECT SUM(current_balance) AS total_bank_balance FROM accounts;

-- Total loan outstanding:
SELECT SUM(outstanding_amount) AS total_debt FROM loans;

-- Total fraud amount across all cases:
SELECT SUM(fraud_amount) AS total_fraud_amount FROM fraud_cases;

-- Total money recovered:
SELECT SUM(recovery_amount) AS total_recovered FROM fraud_cases;

-- SUM filtered:
SELECT SUM(amount) AS total_debit_volume
FROM transactions
WHERE transaction_type = 'debit';

SELECT SUM(amount) AS total_credit_volume
FROM transactions
WHERE transaction_type = 'credit';

-- SUM with GROUP BY (total per group):
SELECT
    transaction_type,
    SUM(amount)          AS total_amount,
    COUNT(*)             AS txn_count
FROM transactions
GROUP BY transaction_type;

SELECT
    account_type,
    SUM(current_balance) AS total_balance
FROM accounts
GROUP BY account_type
ORDER BY total_balance DESC;

SELECT
    currency,
    SUM(amount)          AS total_by_currency
FROM transactions
GROUP BY currency
ORDER BY total_by_currency DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- 8.3 AVG — Average (mean) of numeric values
-- ─────────────────────────────────────────────────────────────────────────

-- Average account balance:
SELECT ROUND(AVG(current_balance), 2) AS avg_balance FROM accounts;

-- Average transaction size:
SELECT ROUND(AVG(amount), 2) AS avg_transaction FROM transactions;

-- Average loan interest rate:
SELECT ROUND(AVG(interest_rate), 2) AS avg_interest_rate FROM loans;

-- Average CIBIL score:
SELECT ROUND(AVG(cibil_score_at_approval), 0) AS avg_cibil FROM loans;

-- Average income by nationality:
SELECT
    nationality,
    ROUND(AVG(annual_income), 2) AS avg_annual_income
FROM customers
GROUP BY nationality
ORDER BY avg_annual_income DESC;

-- Average balance by account type:
SELECT
    account_type,
    ROUND(AVG(current_balance), 2) AS avg_balance
FROM accounts
GROUP BY account_type;

-- Average fraud amount by case type:
SELECT
    case_type,
    ROUND(AVG(fraud_amount), 2) AS avg_fraud_amount
FROM fraud_cases
GROUP BY case_type
ORDER BY avg_fraud_amount DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- 8.4 MIN — Smallest value in the column
-- ─────────────────────────────────────────────────────────────────────────

-- Smallest transaction:
SELECT MIN(amount) AS smallest_transaction FROM transactions;

-- Smallest loan:
SELECT MIN(principal_amount) AS smallest_loan FROM loans;

-- Lowest balance account:
SELECT MIN(current_balance) AS lowest_balance FROM accounts;

-- Oldest customer (earliest DOB):
SELECT MIN(dob) AS oldest_customer_dob FROM customers;

-- Earliest transaction on record:
SELECT MIN(transaction_date) AS earliest_transaction FROM transactions;

-- MIN per group (lowest balance per account type):
SELECT
    account_type,
    MIN(current_balance) AS lowest_balance_in_type
FROM accounts
GROUP BY account_type;

-- ─────────────────────────────────────────────────────────────────────────
-- 8.5 MAX — Largest value in the column
-- ─────────────────────────────────────────────────────────────────────────

-- Largest single transaction:
SELECT MAX(amount) AS largest_transaction FROM transactions;

-- Largest loan ever given:
SELECT MAX(principal_amount) AS biggest_loan FROM loans;

-- Highest account balance:
SELECT MAX(current_balance) AS richest_account FROM accounts;

-- Most recent login:
SELECT MAX(login_datetime) AS last_login FROM login_audit;

-- MAX per group (biggest loan per type):
SELECT
    loan_type,
    MAX(principal_amount) AS biggest_loan_of_type
FROM loans
GROUP BY loan_type
ORDER BY biggest_loan_of_type DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- 8.6 Combining all aggregate functions
-- ─────────────────────────────────────────────────────────────────────────

-- Transaction summary by transaction mode:
SELECT
    transaction_mode,
    COUNT(*)                      AS txn_count,
    SUM(amount)                   AS total_amount,
    ROUND(AVG(amount), 2)         AS avg_amount,
    MIN(amount)                   AS min_amount,
    MAX(amount)                   AS max_amount
FROM transactions
GROUP BY transaction_mode
ORDER BY total_amount DESC;

-- Account summary by type:
SELECT
    account_type,
    COUNT(*)                      AS account_count,
    ROUND(SUM(current_balance), 2) AS total_balance,
    ROUND(AVG(current_balance), 2) AS avg_balance,
    MIN(current_balance)           AS min_balance,
    MAX(current_balance)           AS max_balance
FROM accounts
GROUP BY account_type;

-- Fraud dashboard summary:
SELECT
    case_type,
    COUNT(*)                       AS cases,
    SUM(fraud_amount)              AS total_fraud,
    ROUND(AVG(fraud_amount), 2)    AS avg_fraud,
    MAX(fraud_amount)              AS biggest_case,
    SUM(recovery_amount)           AS recovered
FROM fraud_cases
GROUP BY case_type
ORDER BY total_fraud DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- 8.7 Aggregate functions with ROLLUP (subtotals + grand total)
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    IFNULL(account_type, 'ALL TYPES') AS account_type,
    COUNT(*)                          AS account_count,
    SUM(current_balance)              AS total_balance
FROM accounts
GROUP BY account_type WITH ROLLUP;
-- ROLLUP adds a final summary row for the entire column
