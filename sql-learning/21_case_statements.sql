-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 21: CASE STATEMENTS
-- CASE is SQL's IF-THEN-ELSE — creates conditional logic inside a query.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- SYNTAX — Two forms:
--
-- Simple CASE (compare one column):
--   CASE column
--       WHEN value1 THEN result1
--       WHEN value2 THEN result2
--       ELSE default_result
--   END
--
-- Searched CASE (any condition):
--   CASE
--       WHEN condition1 THEN result1
--       WHEN condition2 THEN result2
--       ELSE default_result
--   END
-- ─────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────
-- 21.1 SIMPLE CASE — Map values to labels
-- ─────────────────────────────────────────────────────────────────────────

-- Translate account_type codes to friendly names:
SELECT
    account_number,
    account_type,
    CASE account_type
        WHEN 'savings'  THEN 'Savings Account 💰'
        WHEN 'current'  THEN 'Current / Business Account 🏢'
        WHEN 'salary'   THEN 'Salary Account 📅'
        WHEN 'nri'      THEN 'NRI Account 🌏'
        ELSE            'Other Account'
    END AS account_label
FROM accounts
LIMIT 10;

-- Translate gender code to full word:
SELECT
    full_name,
    gender,
    CASE gender
        WHEN 'M' THEN 'Male'
        WHEN 'F' THEN 'Female'
        WHEN 'O' THEN 'Other'
        ELSE         'Not Specified'
    END AS gender_label
FROM customers
LIMIT 10;

-- Translate alert severity to priority number:
SELECT
    alert_id,
    alert_severity,
    CASE alert_severity
        WHEN 'critical' THEN 1
        WHEN 'high'     THEN 2
        WHEN 'medium'   THEN 3
        WHEN 'low'      THEN 4
        ELSE 99
    END AS priority_order
FROM alerts
ORDER BY priority_order ASC
LIMIT 15;

-- ─────────────────────────────────────────────────────────────────────────
-- 21.2 SEARCHED CASE — Range/condition based labels
-- ─────────────────────────────────────────────────────────────────────────

-- Classify transactions by size:
SELECT
    transaction_id,
    amount,
    CASE
        WHEN amount >= 1000000 THEN '💎 Very Large (> ₹10L)'
        WHEN amount >= 500000  THEN '🔴 Large (₹5L–₹10L)'
        WHEN amount >= 100000  THEN '🟠 Medium (₹1L–₹5L)'
        WHEN amount >= 10000   THEN '🟡 Small (₹10K–₹1L)'
        ELSE                        '🟢 Micro (< ₹10K)'
    END AS transaction_size_label
FROM transactions
LIMIT 15;

-- Classify customers by income bracket:
SELECT
    full_name,
    annual_income,
    CASE
        WHEN annual_income >= 5000000 THEN 'HNI (High Net Worth)'
        WHEN annual_income >= 1000000 THEN 'Affluent'
        WHEN annual_income >= 500000  THEN 'Upper-Middle'
        WHEN annual_income >= 200000  THEN 'Middle Class'
        WHEN annual_income > 0        THEN 'Lower Income'
        ELSE                               'No Income / Student'
    END AS income_segment
FROM customers
ORDER BY annual_income DESC
LIMIT 15;

-- Classify loans by risk (CIBIL score + principal):
SELECT
    loan_id,
    loan_type,
    cibil_score_at_approval,
    principal_amount,
    CASE
        WHEN cibil_score_at_approval >= 750 AND principal_amount < 1000000 THEN 'Low Risk'
        WHEN cibil_score_at_approval >= 650 AND principal_amount < 3000000 THEN 'Medium Risk'
        WHEN cibil_score_at_approval < 650                                  THEN 'High Risk'
        ELSE                                                                     'Under Review'
    END AS loan_risk_rating
FROM loans
LIMIT 15;

-- ─────────────────────────────────────────────────────────────────────────
-- 21.3 CASE in GROUP BY — Count rows per dynamically created category
-- ─────────────────────────────────────────────────────────────────────────

-- Count customers per income segment:
SELECT
    CASE
        WHEN annual_income >= 5000000 THEN 'HNI'
        WHEN annual_income >= 1000000 THEN 'Affluent'
        WHEN annual_income >= 500000  THEN 'Upper-Middle'
        WHEN annual_income >= 200000  THEN 'Middle Class'
        WHEN annual_income > 0        THEN 'Lower Income'
        ELSE                               'No Income'
    END AS segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(annual_income), 2) AS avg_income
FROM customers
GROUP BY segment
ORDER BY avg_income DESC;

-- Count transactions by size bucket:
SELECT
    CASE
        WHEN amount >= 1000000 THEN 'Very Large'
        WHEN amount >= 100000  THEN 'Large'
        WHEN amount >= 10000   THEN 'Medium'
        ELSE                        'Small'
    END AS size_bucket,
    COUNT(*)         AS txn_count,
    SUM(amount)      AS total_amount
FROM transactions
GROUP BY size_bucket
ORDER BY total_amount DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- 21.4 CASE in ORDER BY — Custom sort order
-- ─────────────────────────────────────────────────────────────────────────

-- Sort alerts by a custom severity priority:
SELECT
    alert_id,
    alert_severity,
    alert_type,
    alert_date
FROM alerts
ORDER BY
    CASE alert_severity
        WHEN 'critical' THEN 1
        WHEN 'high'     THEN 2
        WHEN 'medium'   THEN 3
        WHEN 'low'      THEN 4
    END ASC,
    alert_date DESC
LIMIT 15;

-- ─────────────────────────────────────────────────────────────────────────
-- 21.5 CASE in WHERE — Conditional filtering (dynamic filter)
-- ─────────────────────────────────────────────────────────────────────────

-- Example: get 'active' savings accounts OR all frozen accounts:
SELECT account_number, account_type, account_status, current_balance
FROM accounts
WHERE
    CASE
        WHEN account_type = 'savings' THEN account_status = 'active'
        ELSE account_status = 'frozen'
    END
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 21.6 CASE for PIVOT — Turn rows into columns (cross-tab report)
-- ─────────────────────────────────────────────────────────────────────────

-- Count transactions by type per day (pivot: debit vs credit as columns):
SELECT
    transaction_date,
    SUM(CASE WHEN transaction_type = 'debit'  THEN 1 ELSE 0 END) AS debit_count,
    SUM(CASE WHEN transaction_type = 'credit' THEN 1 ELSE 0 END) AS credit_count,
    SUM(CASE WHEN transaction_type = 'debit'  THEN amount ELSE 0 END) AS total_debits,
    SUM(CASE WHEN transaction_type = 'credit' THEN amount ELSE 0 END) AS total_credits
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date DESC
LIMIT 15;

-- Risk category pivot (count per nationality × risk):
SELECT
    nationality,
    SUM(CASE WHEN risk_category = 'low'       THEN 1 ELSE 0 END) AS low_risk,
    SUM(CASE WHEN risk_category = 'medium'    THEN 1 ELSE 0 END) AS medium_risk,
    SUM(CASE WHEN risk_category = 'high'      THEN 1 ELSE 0 END) AS high_risk,
    SUM(CASE WHEN risk_category = 'very_high' THEN 1 ELSE 0 END) AS very_high_risk,
    COUNT(*) AS total_customers
FROM customers
GROUP BY nationality
ORDER BY total_customers DESC
LIMIT 10;

-- Alert count by severity per month (calendar pivot):
SELECT
    DATE_FORMAT(alert_date, '%Y-%m') AS month,
    SUM(CASE WHEN alert_severity = 'critical' THEN 1 ELSE 0 END) AS critical,
    SUM(CASE WHEN alert_severity = 'high'     THEN 1 ELSE 0 END) AS high,
    SUM(CASE WHEN alert_severity = 'medium'   THEN 1 ELSE 0 END) AS medium,
    SUM(CASE WHEN alert_severity = 'low'      THEN 1 ELSE 0 END) AS low_sev,
    COUNT(*) AS total_alerts
FROM alerts
GROUP BY month
ORDER BY month DESC
LIMIT 12;

-- ─────────────────────────────────────────────────────────────────────────
-- 21.7 CASE with NULL handling
-- ─────────────────────────────────────────────────────────────────────────

-- Display "Unknown" for NULL merchant names:
SELECT
    transaction_id,
    amount,
    CASE
        WHEN merchant_name IS NULL THEN '(Peer Transfer)'
        ELSE merchant_name
    END AS merchant_display,
    CASE
        WHEN fraud_flag = 1         THEN '🚨 FLAGGED'
        WHEN is_suspicious = 1      THEN '⚠️ SUSPICIOUS'
        ELSE                             '✅ CLEAN'
    END AS flag_status
FROM transactions
LIMIT 15;

-- ─────────────────────────────────────────────────────────────────────────
-- 21.8 CASE inside aggregate functions (conditional aggregation)
-- ─────────────────────────────────────────────────────────────────────────

-- Total flagged vs clean transaction amounts:
SELECT
    SUM(CASE WHEN fraud_flag = 1 THEN amount ELSE 0 END) AS flagged_total,
    SUM(CASE WHEN fraud_flag = 0 THEN amount ELSE 0 END) AS clean_total,
    COUNT(CASE WHEN fraud_flag = 1 THEN 1 END)           AS flagged_count,
    COUNT(CASE WHEN fraud_flag = 0 THEN 1 END)           AS clean_count
FROM transactions;

-- Account summary with status-based tallies:
SELECT
    account_type,
    COUNT(*) AS total,
    SUM(CASE WHEN account_status = 'active'              THEN 1 ELSE 0 END) AS active,
    SUM(CASE WHEN account_status = 'frozen'              THEN 1 ELSE 0 END) AS frozen,
    SUM(CASE WHEN account_status = 'under_investigation' THEN 1 ELSE 0 END) AS under_investigation
FROM accounts
GROUP BY account_type;
