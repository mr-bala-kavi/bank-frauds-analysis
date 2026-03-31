-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 06: FILTERING DATA
-- Commands: WHERE, AND/OR/NOT, IN, BETWEEN, LIKE, LIMIT
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 6.1 WHERE — Basic row filtering
-- ─────────────────────────────────────────────────────────────────────────

-- Equality filter:
SELECT full_name, nationality, risk_category
FROM customers
WHERE nationality = 'India';

-- Not equal to:
SELECT account_number, account_type, account_status
FROM accounts
WHERE account_status != 'active';          -- also: account_status <> 'active'

-- Numeric comparisons:
SELECT transaction_id, amount, transaction_type
FROM transactions
WHERE amount > 500000;                      -- more than 5 lakhs

SELECT loan_id, principal_amount, interest_rate
FROM loans
WHERE interest_rate < 9.0;                 -- cheap loans

SELECT account_number, current_balance
FROM accounts
WHERE current_balance >= 1000000;          -- millionaires!

-- NULL checks:
SELECT customer_id, merchant_name
FROM transactions
WHERE merchant_name IS NULL;               -- peer-to-peer transfers (no merchant)

SELECT customer_id, email_primary
FROM customer_contact
WHERE email_primary IS NOT NULL;           -- customers with email on file

-- ─────────────────────────────────────────────────────────────────────────
-- 6.2 AND — All conditions must be true
-- ─────────────────────────────────────────────────────────────────────────
SELECT full_name, nationality, risk_category, annual_income
FROM customers
WHERE nationality = 'India'
  AND risk_category = 'high'
  AND annual_income > 500000;

-- Find frozen accounts belonging to high-risk customers:
SELECT a.account_number, a.account_type, a.account_status
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id
WHERE a.account_status = 'frozen'
  AND c.risk_category IN ('high','very_high');

-- ─────────────────────────────────────────────────────────────────────────
-- 6.3 OR — At least one condition must be true
-- ─────────────────────────────────────────────────────────────────────────
SELECT full_name, nationality
FROM customers
WHERE nationality = 'USA'
   OR nationality = 'UK'
   OR nationality = 'UAE';

-- Large or suspicious transactions:
SELECT transaction_id, amount, transaction_type, fraud_flag
FROM transactions
WHERE amount > 1000000
   OR fraud_flag = 1
   OR is_suspicious = 1;

-- ─────────────────────────────────────────────────────────────────────────
-- 6.4 NOT — Negate a condition
-- ─────────────────────────────────────────────────────────────────────────
SELECT full_name, nationality
FROM customers
WHERE NOT nationality = 'India';           -- non-Indian customers

SELECT account_number, account_status
FROM accounts
WHERE NOT account_status = 'active';       -- anything but active

-- NOT with IS NULL:
SELECT transaction_id, fraud_type
FROM transactions
WHERE fraud_type IS NOT NULL;              -- transactions with fraud labels

-- ─────────────────────────────────────────────────────────────────────────
-- 6.5 IN — Match against a list of values (replaces multiple ORs)
-- ─────────────────────────────────────────────────────────────────────────
SELECT full_name, nationality, risk_category
FROM customers
WHERE nationality IN ('USA', 'UK', 'UAE', 'Singapore');

-- High-priority alerts:
SELECT alert_id, alert_type, alert_severity
FROM alerts
WHERE alert_severity IN ('critical', 'high');

-- Fraud cases in active investigation:
SELECT case_id, case_type, case_status, fraud_amount
FROM fraud_cases
WHERE case_status IN ('reported', 'investigating', 'confirmed');

-- NOT IN — exclude a list:
SELECT full_name, nationality
FROM customers
WHERE nationality NOT IN ('India', 'USA', 'UK');

SELECT account_number, account_type
FROM accounts
WHERE account_type NOT IN ('savings', 'current');

-- ─────────────────────────────────────────────────────────────────────────
-- 6.6 BETWEEN — Range check (inclusive on both ends)
-- ─────────────────────────────────────────────────────────────────────────
-- Number range:
SELECT transaction_id, amount
FROM transactions
WHERE amount BETWEEN 100000 AND 200000;    -- ₹1L to ₹2L

-- Near the ₹2L reporting threshold (structuring pattern):
SELECT account_id, amount, transaction_date
FROM transactions
WHERE amount BETWEEN 180000 AND 199999;

-- CIBIL score range (credit quality):
SELECT loan_id, cibil_score_at_approval, principal_amount
FROM loans
WHERE cibil_score_at_approval BETWEEN 650 AND 750;

-- Date range:
SELECT transaction_id, transaction_date, amount
FROM transactions
WHERE transaction_date BETWEEN '2023-01-01' AND '2023-12-31';

-- NOT BETWEEN — outside the range:
SELECT transaction_id, amount
FROM transactions
WHERE amount NOT BETWEEN 1000 AND 100000;  -- micro or very large transactions

-- ─────────────────────────────────────────────────────────────────────────
-- 6.7 LIKE — Pattern matching with wildcards
-- % = any number of characters (including zero)
-- _ = exactly one character
-- ─────────────────────────────────────────────────────────────────────────

-- Names starting with 'A':
SELECT full_name FROM customers WHERE full_name LIKE 'A%';

-- Names ending with 'Singh':
SELECT full_name FROM customers WHERE full_name LIKE '%Singh';

-- Names containing 'Kumar' anywhere:
SELECT full_name FROM customers WHERE full_name LIKE '%Kumar%';

-- Gmail users:
SELECT email_primary FROM customer_contact WHERE email_primary LIKE '%@gmail.com';

-- Phone numbers starting with +91 (Indian):
SELECT phone_primary FROM customer_contact WHERE phone_primary LIKE '+91%';

-- IP addresses in 192.168.x.x range:
SELECT ip_address, login_status FROM login_audit WHERE ip_address LIKE '192.168.%';

-- Exactly 5-character beneficiary name (using _ wildcard):
SELECT beneficiary_name FROM transactions WHERE beneficiary_name LIKE '_____';

-- Account numbers starting with 'ACC':
SELECT account_number FROM accounts WHERE account_number LIKE 'ACC%';

-- NOT LIKE — exclude the pattern:
SELECT email_primary FROM customer_contact WHERE email_primary NOT LIKE '%gmail%';

-- Case-insensitive LIKE (MySQL default is case-insensitive for LIKE):
SELECT full_name FROM customers WHERE full_name LIKE 'kumar%';   -- finds 'Kumar', 'kumar'

-- ─────────────────────────────────────────────────────────────────────────
-- 6.8 LIMIT — Control how many rows are returned
-- ─────────────────────────────────────────────────────────────────────────

-- Get first 10 rows:
SELECT * FROM customers LIMIT 10;

-- Get rows 11–20 (LIMIT offset, count):
SELECT * FROM customers LIMIT 10, 10;      -- skip first 10, take next 10

-- Pagination pattern (page 3, 20 rows per page):
SELECT * FROM transactions LIMIT 40, 20;   -- skip 40, take 20

-- Top 5 largest transactions:
SELECT transaction_id, amount
FROM transactions
ORDER BY amount DESC
LIMIT 5;

-- Top 10 highest balance accounts:
SELECT account_number, current_balance
FROM accounts
ORDER BY current_balance DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 6.9 COMBINING ALL FILTERS — Real fraud detection example
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    c.full_name,
    c.nationality,
    c.risk_category,
    a.account_number,
    t.amount,
    t.transaction_date,
    t.transaction_mode
FROM customers c
JOIN accounts a     ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id  = a.account_id
WHERE t.amount BETWEEN 180000 AND 199999          -- structuring range
  AND t.transaction_type = 'debit'
  AND c.risk_category IN ('high', 'very_high')
  AND t.transaction_date BETWEEN '2023-01-01' AND '2023-12-31'
  AND c.nationality LIKE '%India%'
ORDER BY t.amount DESC
LIMIT 20;
