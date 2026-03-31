-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 05: DQL — DATA QUERY LANGUAGE (SELECT)
-- The SELECT statement — THE most important SQL command
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 5.1 SELECT * — Get ALL columns from a table
-- ─────────────────────────────────────────────────────────────────────────
SELECT * FROM customers LIMIT 10;
-- * means "every column" — use only when exploring data

SELECT * FROM accounts      LIMIT 5;
SELECT * FROM transactions  LIMIT 5;
SELECT * FROM fraud_cases   LIMIT 5;

-- ─────────────────────────────────────────────────────────────────────────
-- 5.2 SELECT specific columns (always prefer this over *)
-- ─────────────────────────────────────────────────────────────────────────
SELECT full_name, dob, nationality
FROM customers
LIMIT 10;

SELECT account_number, account_type, current_balance
FROM accounts
LIMIT 10;

SELECT transaction_id, amount, transaction_date, transaction_type
FROM transactions
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 5.3 Column ALIASES — Rename columns in output
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    full_name       AS customer_name,
    annual_income   AS yearly_income,
    risk_category   AS risk_level
FROM customers
LIMIT 10;

-- Aliases with spaces need backticks or quotes:
SELECT
    full_name           AS `Customer Full Name`,
    annual_income       AS 'Annual Income (INR)'
FROM customers
LIMIT 5;

-- ─────────────────────────────────────────────────────────────────────────
-- 5.4 SELECT with CALCULATIONS (derived columns)
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    full_name,
    annual_income,
    annual_income / 12              AS monthly_income,
    annual_income * 0.30            AS tax_estimate,
    annual_income - (annual_income * 0.30) AS net_income
FROM customers
LIMIT 10;

-- Balance with 5% interest calculation:
SELECT
    account_number,
    current_balance,
    ROUND(current_balance * 0.05, 2)             AS interest_earned,
    ROUND(current_balance + current_balance * 0.05, 2) AS projected_balance
FROM accounts
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 5.5 SELECT with STRING FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    full_name,
    UPPER(full_name)                AS name_upper,
    LOWER(full_name)                AS name_lower,
    LENGTH(full_name)               AS name_length,
    SUBSTRING(full_name, 1, 5)      AS first_5_chars,
    CONCAT(full_name, ' — ', nationality) AS combined
FROM customers
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 5.6 SELECT with DATE FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    full_name,
    dob                                               AS date_of_birth,
    YEAR(dob)                                         AS birth_year,
    TIMESTAMPDIFF(YEAR, dob, CURDATE())               AS age_years,
    YEAR(customer_since)                              AS joined_year,
    DATEDIFF(CURDATE(), customer_since)               AS days_as_customer
FROM customers
LIMIT 10;

-- Transaction date breakdown:
SELECT
    transaction_id,
    transaction_date,
    YEAR(transaction_date)                            AS yr,
    MONTH(transaction_date)                           AS mo,
    DAY(transaction_date)                             AS dy,
    DAYNAME(transaction_date)                         AS day_name,
    MONTHNAME(transaction_date)                       AS month_name
FROM transactions
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 5.7 SELECT DISTINCT — Remove duplicate values
-- ─────────────────────────────────────────────────────────────────────────
SELECT DISTINCT nationality         FROM customers;
SELECT DISTINCT account_type        FROM accounts;
SELECT DISTINCT transaction_mode    FROM transactions;
SELECT DISTINCT risk_category       FROM customers;
SELECT DISTINCT alert_severity      FROM alerts;
SELECT DISTINCT card_type           FROM cards;

-- DISTINCT on multiple columns (combination must be unique):
SELECT DISTINCT account_type, account_status FROM accounts;

-- ─────────────────────────────────────────────────────────────────────────
-- 5.8 SELECT with NULL handling
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    transaction_id,
    merchant_name,
    IFNULL(merchant_name, 'No Merchant')  AS merchant_display,
    COALESCE(beneficiary_name, merchant_name, 'Unknown')  AS payee
FROM transactions
LIMIT 10;

-- IFNULL(x, y)     → if x is NULL return y
-- COALESCE(a,b,c)  → returns first non-NULL value from left

-- ─────────────────────────────────────────────────────────────────────────
-- 5.9 SELECT with CONCAT
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    CONCAT(full_name, ' (', nationality, ')') AS customer_label,
    CONCAT('₹', FORMAT(annual_income, 0))     AS formatted_income
FROM customers
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 5.10 SELECT syntax structure (anatomy)
-- ─────────────────────────────────────────────────────────────────────────
-- Full SELECT clause order (must follow this sequence):
--
-- SELECT   [columns or expressions]
-- FROM     [table]
-- JOIN     [other table ON condition]
-- WHERE    [row filter condition]
-- GROUP BY [column to group]
-- HAVING   [filter on grouped results]
-- ORDER BY [column to sort]
-- LIMIT    [max rows to return]

-- Example using all clauses:
SELECT
    c.nationality,
    COUNT(*)             AS customer_count,
    AVG(c.annual_income) AS avg_income
FROM customers c
WHERE c.annual_income > 100000
GROUP BY c.nationality
HAVING COUNT(*) > 100
ORDER BY avg_income DESC
LIMIT 10;
