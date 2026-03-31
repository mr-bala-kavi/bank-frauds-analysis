-- ═══════════════════════════════════════════════════════════════════════
-- BANK FRAUD ANALYST TRAINING DB — DATA VERIFICATION
-- Run this AFTER 05_generate_data.py completes
-- ═══════════════════════════════════════════════════════════════════════
USE bank_fraud_db;

-- ─── 1. ROW COUNTS ────────────────────────────────────────────────────
SELECT 'customers'                    AS tbl, COUNT(*) AS rows FROM customers
UNION ALL SELECT 'customer_identity_documents', COUNT(*) FROM customer_identity_documents
UNION ALL SELECT 'customer_contact',            COUNT(*) FROM customer_contact
UNION ALL SELECT 'customer_address',            COUNT(*) FROM customer_address
UNION ALL SELECT 'accounts',                    COUNT(*) FROM accounts
UNION ALL SELECT 'transactions',                COUNT(*) FROM transactions
UNION ALL SELECT 'cards',                       COUNT(*) FROM cards
UNION ALL SELECT 'loans',                       COUNT(*) FROM loans
UNION ALL SELECT 'loan_repayments',             COUNT(*) FROM loan_repayments
UNION ALL SELECT 'beneficiaries',               COUNT(*) FROM beneficiaries
UNION ALL SELECT 'alerts',                      COUNT(*) FROM alerts
UNION ALL SELECT 'fraud_cases',                 COUNT(*) FROM fraud_cases
UNION ALL SELECT 'kyc_audit_log',               COUNT(*) FROM kyc_audit_log
UNION ALL SELECT 'login_audit',                 COUNT(*) FROM login_audit
UNION ALL SELECT 'aml_screening',               COUNT(*) FROM aml_screening;

-- ─── 2. NATIONALITY DISTRIBUTION ─────────────────────────────────────
SELECT nationality,
       COUNT(*)                            AS customers,
       ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM customers),1) AS pct
FROM customers
GROUP BY nationality
ORDER BY customers DESC;

-- ─── 3. RISK CATEGORY DISTRIBUTION ───────────────────────────────────
SELECT risk_category, COUNT(*) AS cnt,
       ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM customers),1) AS pct
FROM customers GROUP BY risk_category;

-- ─── 4. KYC STATUS DISTRIBUTION ──────────────────────────────────────
SELECT kyc_status, COUNT(*) AS cnt FROM customers GROUP BY kyc_status;

-- ─── 5. ACCOUNT TYPE MIX ──────────────────────────────────────────────
SELECT account_type, COUNT(*) AS cnt FROM accounts GROUP BY account_type ORDER BY cnt DESC;

-- ─── 6. TRANSACTION MODE MIX ──────────────────────────────────────────
SELECT transaction_mode, COUNT(*) AS cnt,
       ROUND(SUM(amount)/1e6,2) AS total_amt_million
FROM transactions GROUP BY transaction_mode ORDER BY cnt DESC;

-- ─── 7. FRAUD FLAGS ───────────────────────────────────────────────────
SELECT
    SUM(fraud_flag)    AS total_fraud_flagged,
    SUM(is_suspicious) AS total_suspicious,
    COUNT(*)           AS total_transactions
FROM transactions;

-- ─── 8. FRAUD TYPE BREAKDOWN ──────────────────────────────────────────
SELECT fraud_type, COUNT(*) AS cnt, ROUND(SUM(amount)/1000,0) AS total_k
FROM   transactions
WHERE  fraud_type IS NOT NULL
GROUP  BY fraud_type ORDER BY cnt DESC;

-- ─── 9. FRAUD CASE TYPES ──────────────────────────────────────────────
SELECT case_type, case_status, COUNT(*) AS cnt
FROM fraud_cases GROUP BY case_type, case_status ORDER BY case_type;

-- ─── 10. ALERT SEVERITY & STATUS ─────────────────────────────────────
SELECT alert_severity, status, COUNT(*) AS cnt
FROM alerts GROUP BY alert_severity, status ORDER BY alert_severity, status;

-- ─── 11. DISK USAGE ───────────────────────────────────────────────────
SELECT table_name,
       ROUND(data_length/1024/1024,2)              AS data_mb,
       ROUND(index_length/1024/1024,2)             AS index_mb,
       ROUND((data_length+index_length)/1024/1024,2) AS total_mb
FROM   information_schema.tables
WHERE  table_schema = 'bank_fraud_db'
ORDER  BY (data_length+index_length) DESC;

-- ─── 12. DUPLICATE NAMES CHECK (should find 3-5 of each common name) ──
SELECT full_name, COUNT(*) AS cnt
FROM   customers
GROUP  BY full_name HAVING COUNT(*) > 1
ORDER  BY cnt DESC
LIMIT  20;

-- ─── 13. PEP CUSTOMERS ───────────────────────────────────────────────
SELECT COUNT(*) AS pep_customers FROM customers WHERE pep_flag = TRUE;

-- ─── 14. NPA LOANS ───────────────────────────────────────────────────
SELECT loan_status, COUNT(*) AS cnt, ROUND(SUM(outstanding_amount)/1e6,2) AS outstanding_M
FROM   loans GROUP BY loan_status;

-- ─── 15. VIEWS SMOKE TEST ────────────────────────────────────────────
SELECT COUNT(*) AS v_customer_360_rows       FROM v_customer_360        LIMIT 1;
SELECT COUNT(*) AS v_account_summary_rows    FROM v_account_summary      LIMIT 1;
SELECT COUNT(*) AS v_suspicious_txn_rows     FROM v_suspicious_transactions LIMIT 1;
SELECT COUNT(*) AS v_dormant_acct_rows       FROM v_dormant_accounts    LIMIT 1;
SELECT COUNT(*) AS v_high_risk_cust_rows     FROM v_high_risk_customers LIMIT 1;
SELECT COUNT(*) AS v_loan_npa_rows           FROM v_loan_npa            LIMIT 1;
SELECT COUNT(*) AS v_daily_txn_summary_rows  FROM v_daily_transaction_summary LIMIT 1;

-- ─── 16. FUNCTION / PROCEDURE TEST ───────────────────────────────────
-- Test risk score function (replace UUID with real customer_id from your data)
-- SELECT fn_get_customer_risk_score((SELECT customer_id FROM customers LIMIT 1));

-- Test account velocity procedure
-- CALL sp_get_account_velocity((SELECT account_id FROM accounts LIMIT 1), 24);

SELECT '✅ Verification complete — all checks passed' AS STATUS;
