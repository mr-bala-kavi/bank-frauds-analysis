-- ═══════════════════════════════════════════════════════════════════════
-- BANK FRAUD ANALYST TRAINING DATABASE — VIEWS
-- Engine  : MySQL 8.0+
-- Run     : After data load and index creation
-- ═══════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────
-- VIEW 1: v_customer_360
-- Full customer profile — joins customers, contact, address, accounts,
-- KYC status into a single analyst-ready view.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_customer_360 AS
SELECT
    c.customer_id,
    c.full_name,
    c.first_name,
    c.last_name,
    c.salutation,
    c.date_of_birth,
    TIMESTAMPDIFF(YEAR, c.date_of_birth, CURDATE())            AS age,
    c.gender,
    c.nationality,
    c.country_of_residence,
    c.occupation,
    c.annual_income,
    c.kyc_status,
    c.kyc_verified_date,
    c.pep_flag,
    c.risk_category,
    c.customer_since,
    c.is_active,
    -- Contact info
    cc.phone_primary,
    cc.phone_secondary,
    cc.email_primary,
    cc.email_secondary,
    cc.preferred_contact_method,
    -- Current address
    ca.address_line1,
    ca.address_line2,
    ca.city,
    ca.state,
    ca.postal_code,
    ca.country                                                  AS address_country,
    -- Account summary
    acct.total_accounts,
    acct.total_balance,
    acct.active_accounts
FROM customers c
LEFT JOIN customer_contact cc
    ON cc.customer_id = c.customer_id
LEFT JOIN (
    SELECT customer_id, address_line1, address_line2, city, state,
           postal_code, country
    FROM customer_address
    WHERE is_current = TRUE
    ORDER BY from_date DESC
    LIMIT 1000000           -- MySQL requires LIMIT in subquery with ORDER BY
) ca ON ca.customer_id = c.customer_id
LEFT JOIN (
    SELECT customer_id,
           COUNT(*)                                              AS total_accounts,
           SUM(current_balance)                                  AS total_balance,
           SUM(CASE WHEN account_status = 'active' THEN 1 ELSE 0 END) AS active_accounts
    FROM accounts
    GROUP BY customer_id
) acct ON acct.customer_id = c.customer_id;


-- ─────────────────────────────────────────────────────────────────────
-- VIEW 2: v_account_summary
-- Account with balance, last transaction details, and alert count.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_account_summary AS
SELECT
    a.account_id,
    a.account_number,
    a.customer_id,
    c.full_name                                                AS customer_name,
    a.account_type,
    a.branch_code,
    a.ifsc_code,
    a.currency,
    a.current_balance,
    a.available_balance,
    a.account_status,
    a.opened_date,
    a.last_transaction_date,
    DATEDIFF(CURDATE(), a.last_transaction_date)               AS days_since_last_txn,
    a.overdraft_limit,
    a.interest_rate,
    COALESCE(al.alert_count, 0)                                AS alert_count,
    COALESCE(al.open_alerts, 0)                                AS open_alerts,
    COALESCE(txn.txn_count, 0)                                 AS total_transactions,
    COALESCE(txn.total_credits, 0)                             AS total_credits,
    COALESCE(txn.total_debits, 0)                              AS total_debits
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
LEFT JOIN (
    SELECT account_id,
           COUNT(*)                                             AS alert_count,
           SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END)    AS open_alerts
    FROM alerts
    GROUP BY account_id
) al ON al.account_id = a.account_id
LEFT JOIN (
    SELECT account_id,
           COUNT(*)                                             AS txn_count,
           SUM(CASE WHEN transaction_type = 'credit' THEN amount ELSE 0 END) AS total_credits,
           SUM(CASE WHEN transaction_type = 'debit'  THEN amount ELSE 0 END) AS total_debits
    FROM transactions
    GROUP BY account_id
) txn ON txn.account_id = a.account_id;


-- ─────────────────────────────────────────────────────────────────────
-- VIEW 3: v_suspicious_transactions
-- All flagged + suspicious transactions with customer details.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_suspicious_transactions AS
SELECT
    t.transaction_id,
    t.account_id,
    a.account_number,
    a.customer_id,
    c.full_name                                                AS customer_name,
    c.risk_category,
    c.pep_flag,
    t.transaction_date,
    t.transaction_time,
    t.transaction_type,
    t.transaction_mode,
    t.amount,
    t.currency,
    t.balance_after_transaction,
    t.description,
    t.narration,
    t.beneficiary_name,
    t.beneficiary_bank,
    t.channel,
    t.merchant_name,
    t.location_city,
    t.location_country,
    t.ip_address,
    t.device_id,
    t.is_suspicious,
    t.fraud_flag,
    t.fraud_type
FROM transactions t
JOIN accounts a  ON a.account_id  = t.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.is_suspicious = TRUE OR t.fraud_flag = TRUE;


-- ─────────────────────────────────────────────────────────────────────
-- VIEW 4: v_dormant_accounts
-- Accounts with no transaction in 365+ days.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_dormant_accounts AS
SELECT
    a.account_id,
    a.account_number,
    a.customer_id,
    c.full_name                                                AS customer_name,
    a.account_type,
    a.branch_code,
    a.current_balance,
    a.account_status,
    a.opened_date,
    a.last_transaction_date,
    DATEDIFF(CURDATE(), a.last_transaction_date)               AS days_dormant
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
WHERE a.account_status != 'closed'
  AND (
      a.last_transaction_date IS NULL
      OR DATEDIFF(CURDATE(), a.last_transaction_date) >= 365
  );


-- ─────────────────────────────────────────────────────────────────────
-- VIEW 5: v_high_risk_customers
-- High / very_high risk customers with fraud case & alert counts.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_high_risk_customers AS
SELECT
    c.customer_id,
    c.full_name,
    c.nationality,
    c.country_of_residence,
    c.occupation,
    c.annual_income,
    c.kyc_status,
    c.pep_flag,
    c.risk_category,
    c.customer_since,
    c.is_active,
    COALESCE(fc.fraud_case_count, 0)                           AS fraud_case_count,
    COALESCE(fc.total_fraud_amount, 0)                         AS total_fraud_amount,
    COALESCE(al.alert_count, 0)                                AS alert_count,
    COALESCE(al.critical_alerts, 0)                            AS critical_alerts
FROM customers c
LEFT JOIN (
    SELECT customer_id,
           COUNT(*)              AS fraud_case_count,
           SUM(fraud_amount)     AS total_fraud_amount
    FROM fraud_cases
    GROUP BY customer_id
) fc ON fc.customer_id = c.customer_id
LEFT JOIN (
    SELECT customer_id,
           COUNT(*)                                              AS alert_count,
           SUM(CASE WHEN alert_severity = 'critical' THEN 1 ELSE 0 END) AS critical_alerts
    FROM alerts
    GROUP BY customer_id
) al ON al.customer_id = c.customer_id
WHERE c.risk_category IN ('high', 'very_high');


-- ─────────────────────────────────────────────────────────────────────
-- VIEW 6: v_loan_npa
-- NPA loans with days-past-due and outstanding amounts.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_loan_npa AS
SELECT
    l.loan_id,
    l.customer_id,
    c.full_name                                                AS customer_name,
    l.loan_type,
    l.principal_amount,
    l.sanctioned_amount,
    l.outstanding_amount,
    l.interest_rate,
    l.interest_type,
    l.tenure_months,
    l.remaining_months,
    l.emi_amount,
    l.loan_status,
    l.loan_start_date,
    l.collateral_type,
    l.collateral_value,
    l.cibil_score_at_approval,
    COALESCE(r.max_dpd, 0)                                     AS max_days_past_due,
    COALESCE(r.missed_payments, 0)                             AS missed_payments,
    COALESCE(r.bounced_payments, 0)                            AS bounced_payments,
    COALESCE(r.total_paid, 0)                                  AS total_amount_paid
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id
LEFT JOIN (
    SELECT loan_id,
           MAX(days_past_due)                                   AS max_dpd,
           SUM(CASE WHEN payment_status = 'missed'  THEN 1 ELSE 0 END) AS missed_payments,
           SUM(CASE WHEN payment_status = 'bounced'  THEN 1 ELSE 0 END) AS bounced_payments,
           SUM(amount_paid)                                     AS total_paid
    FROM loan_repayments
    GROUP BY loan_id
) r ON r.loan_id = l.loan_id
WHERE l.loan_status = 'npa';


-- ─────────────────────────────────────────────────────────────────────
-- VIEW 7: v_daily_transaction_summary
-- Aggregated daily stats per account.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_daily_transaction_summary AS
SELECT
    t.account_id,
    a.account_number,
    t.transaction_date,
    COUNT(*)                                                    AS txn_count,
    SUM(CASE WHEN t.transaction_type = 'credit' THEN t.amount ELSE 0 END)  AS total_credits,
    SUM(CASE WHEN t.transaction_type = 'debit'  THEN t.amount ELSE 0 END)  AS total_debits,
    SUM(CASE WHEN t.transaction_type = 'credit' THEN t.amount ELSE -t.amount END) AS net_flow,
    MAX(t.amount)                                               AS max_amount,
    MIN(t.amount)                                               AS min_amount,
    AVG(t.amount)                                               AS avg_amount,
    SUM(CASE WHEN t.is_suspicious = TRUE THEN 1 ELSE 0 END)    AS suspicious_count,
    SUM(CASE WHEN t.fraud_flag    = TRUE THEN 1 ELSE 0 END)    AS fraud_count,
    GROUP_CONCAT(DISTINCT t.transaction_mode)                   AS modes_used,
    GROUP_CONCAT(DISTINCT t.channel)                            AS channels_used
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
GROUP BY t.account_id, a.account_number, t.transaction_date;


-- ═══════════════════════════════════════════════════════════════════════
-- ALL 7 VIEWS CREATED SUCCESSFULLY
-- ═══════════════════════════════════════════════════════════════════════
