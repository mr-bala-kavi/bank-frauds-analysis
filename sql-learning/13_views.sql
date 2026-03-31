-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 13: VIEWS
-- A VIEW is a saved SELECT query that acts like a virtual table.
-- Data is NOT stored in the view — it is always live from the real tables.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 13.1 WHY USE VIEWS?
-- ─────────────────────────────────────────────────────────────────────────
-- ✅ Simplify complex queries — write once, reuse many times
-- ✅ Security — hide sensitive columns from specific users
-- ✅ Consistency — always shows up-to-date data from underlying tables
-- ✅ Readability — give meaningful names to complex joins

-- ─────────────────────────────────────────────────────────────────────────
-- 13.2 CREATE VIEW — Basic single-table view
-- ─────────────────────────────────────────────────────────────────────────

-- View: Only non-sensitive customer info:
CREATE OR REPLACE VIEW vw_customer_summary AS
SELECT
    customer_id,
    full_name,
    nationality,
    risk_category,
    annual_income,
    kyc_status,
    customer_since
FROM customers;

-- Use the view exactly like a table:
SELECT * FROM vw_customer_summary LIMIT 10;
SELECT * FROM vw_customer_summary WHERE nationality = 'India' LIMIT 5;
SELECT * FROM vw_customer_summary WHERE risk_category = 'very_high' LIMIT 5;

-- ─────────────────────────────────────────────────────────────────────────
-- 13.3 View with JOINED tables
-- ─────────────────────────────────────────────────────────────────────────

-- View: Complete account + customer info:
CREATE OR REPLACE VIEW vw_account_details AS
SELECT
    a.account_id,
    a.account_number,
    a.account_type,
    a.account_status,
    a.current_balance,
    a.opened_date,
    a.branch_code,
    c.full_name        AS customer_name,
    c.nationality,
    c.risk_category,
    c.annual_income
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id;

SELECT * FROM vw_account_details WHERE account_status = 'frozen' LIMIT 10;
SELECT * FROM vw_account_details WHERE current_balance > 1000000 ORDER BY current_balance DESC LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 13.4 View with AGGREGATION (summary view)
-- ─────────────────────────────────────────────────────────────────────────

-- View: Customer-level balance summary:
CREATE OR REPLACE VIEW vw_customer_wealth AS
SELECT
    c.customer_id,
    c.full_name,
    c.nationality,
    COUNT(a.account_id)        AS total_accounts,
    SUM(a.current_balance)     AS total_balance,
    MAX(a.current_balance)     AS largest_account,
    MIN(a.current_balance)     AS smallest_account
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name, c.nationality;

SELECT * FROM vw_customer_wealth ORDER BY total_balance DESC LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 13.5 View for FRAUD analytics
-- ─────────────────────────────────────────────────────────────────────────

-- View: Active suspicious accounts:
CREATE OR REPLACE VIEW vw_suspicious_accounts AS
SELECT
    a.account_id,
    a.account_number,
    a.account_status,
    c.full_name,
    c.risk_category,
    COUNT(fc.case_id)          AS fraud_case_count,
    SUM(fc.fraud_amount)       AS total_fraud_amount,
    COUNT(al.alert_id)         AS alert_count
FROM accounts a
JOIN customers c   ON c.customer_id = a.customer_id
LEFT JOIN fraud_cases fc ON fc.account_id = a.account_id
LEFT JOIN alerts al      ON al.account_id = a.account_id
WHERE c.risk_category IN ('high', 'very_high')
   OR a.account_status IN ('frozen', 'under_investigation')
GROUP BY a.account_id, a.account_number, a.account_status,
         c.full_name, c.risk_category;

SELECT * FROM vw_suspicious_accounts ORDER BY total_fraud_amount DESC LIMIT 10;

-- View: High-value transactions dashboard:
CREATE OR REPLACE VIEW vw_high_value_transactions AS
SELECT
    t.transaction_id,
    t.transaction_date,
    t.amount,
    t.transaction_type,
    t.transaction_mode,
    t.location_country,
    t.fraud_flag,
    a.account_number,
    c.full_name,
    c.risk_category
FROM transactions t
JOIN accounts  a ON a.account_id  = t.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.amount > 500000;

SELECT * FROM vw_high_value_transactions ORDER BY amount DESC LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 13.6 View for DAILY ANALYST DASHBOARD (morning review)
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW vw_open_critical_alerts AS
SELECT
    al.alert_id,
    al.alert_type,
    al.alert_severity,
    al.alert_date,
    al.alert_message,
    al.assigned_to_analyst,
    c.full_name,
    c.risk_category,
    a.account_number,
    a.account_status,
    DATEDIFF(CURDATE(), al.alert_date) AS days_open
FROM alerts al
JOIN customers c ON c.customer_id = al.customer_id
JOIN accounts  a ON a.account_id  = al.account_id
WHERE al.alert_severity IN ('critical', 'high')
  AND al.status IN ('open', 'under_review');

SELECT * FROM vw_open_critical_alerts ORDER BY days_open DESC LIMIT 20;

-- ─────────────────────────────────────────────────────────────────────────
-- 13.7 SHOW all existing views
-- ─────────────────────────────────────────────────────────────────────────
SHOW FULL TABLES WHERE Table_type = 'VIEW';

-- See view definition:
SHOW CREATE VIEW vw_customer_summary\G

-- ─────────────────────────────────────────────────────────────────────────
-- 13.8 Update data THROUGH a view (simple views only)
-- ─────────────────────────────────────────────────────────────────────────
-- Only works on views without: DISTINCT, GROUP BY, HAVING, UNION, aggregation
-- UPDATE vw_customer_summary SET risk_category = 'high' WHERE customer_id = 1;

-- ─────────────────────────────────────────────────────────────────────────
-- 13.9 DROP VIEW
-- ─────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS vw_customer_summary;
DROP VIEW IF EXISTS vw_account_details;
DROP VIEW IF EXISTS vw_customer_wealth;
DROP VIEW IF EXISTS vw_suspicious_accounts;
DROP VIEW IF EXISTS vw_high_value_transactions;
DROP VIEW IF EXISTS vw_open_critical_alerts;
