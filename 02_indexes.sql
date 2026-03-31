-- ═══════════════════════════════════════════════════════════════════════
-- BANK FRAUD ANALYST TRAINING DATABASE — INDEXES
-- Engine  : MySQL 8.0+
-- Run     : AFTER data is loaded (05_generate_data.py)
--           Creating indexes after bulk load is significantly faster.
-- ═══════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────
-- CUSTOMERS
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_cust_full_name       ON customers (full_name);
CREATE INDEX idx_cust_last_name       ON customers (last_name);
CREATE INDEX idx_cust_kyc_status      ON customers (kyc_status);
CREATE INDEX idx_cust_risk_category   ON customers (risk_category);
CREATE INDEX idx_cust_nationality     ON customers (nationality);
CREATE INDEX idx_cust_pep_flag        ON customers (pep_flag);
CREATE INDEX idx_cust_is_active       ON customers (is_active);
CREATE INDEX idx_cust_since           ON customers (customer_since);

-- ─────────────────────────────────────────────────────────────────────
-- CUSTOMER IDENTITY DOCUMENTS
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_doc_customer         ON customer_identity_documents (customer_id);
CREATE INDEX idx_doc_type             ON customer_identity_documents (document_type);
CREATE INDEX idx_doc_number           ON customer_identity_documents (document_number);

-- ─────────────────────────────────────────────────────────────────────
-- CUSTOMER CONTACT
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_contact_customer     ON customer_contact (customer_id);
CREATE INDEX idx_contact_email        ON customer_contact (email_primary);

-- ─────────────────────────────────────────────────────────────────────
-- CUSTOMER ADDRESS
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_addr_customer        ON customer_address (customer_id);
CREATE INDEX idx_addr_city            ON customer_address (city);
CREATE INDEX idx_addr_country         ON customer_address (country);

-- ─────────────────────────────────────────────────────────────────────
-- ACCOUNTS
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_acct_customer        ON accounts (customer_id);
CREATE INDEX idx_acct_status          ON accounts (account_status);
CREATE INDEX idx_acct_type            ON accounts (account_type);
CREATE INDEX idx_acct_opened          ON accounts (opened_date);
CREATE INDEX idx_acct_last_txn        ON accounts (last_transaction_date);
CREATE INDEX idx_acct_branch          ON accounts (branch_code);

-- ─────────────────────────────────────────────────────────────────────
-- TRANSACTIONS  (heaviest table — critical indexes)
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_txn_account          ON transactions (account_id);
CREATE INDEX idx_txn_date             ON transactions (transaction_date);
CREATE INDEX idx_txn_fraud_flag       ON transactions (fraud_flag);
CREATE INDEX idx_txn_suspicious       ON transactions (is_suspicious);
CREATE INDEX idx_txn_mode             ON transactions (transaction_mode);
CREATE INDEX idx_txn_type             ON transactions (transaction_type);
CREATE INDEX idx_txn_amount           ON transactions (amount);
CREATE INDEX idx_txn_channel          ON transactions (channel);
CREATE INDEX idx_txn_acct_date        ON transactions (account_id, transaction_date);
CREATE INDEX idx_txn_acct_fraud       ON transactions (account_id, fraud_flag);
CREATE INDEX idx_txn_date_suspicious  ON transactions (transaction_date, is_suspicious);
CREATE INDEX idx_txn_benef_acct       ON transactions (beneficiary_account_id);
CREATE INDEX idx_txn_location_country ON transactions (location_country);

-- ─────────────────────────────────────────────────────────────────────
-- CARDS
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_card_account         ON cards (account_id);
CREATE INDEX idx_card_customer        ON cards (customer_id);
CREATE INDEX idx_card_status          ON cards (card_status);
CREATE INDEX idx_card_type            ON cards (card_type);

-- ─────────────────────────────────────────────────────────────────────
-- LOANS
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_loan_customer        ON loans (customer_id);
CREATE INDEX idx_loan_status          ON loans (loan_status);
CREATE INDEX idx_loan_type            ON loans (loan_type);
CREATE INDEX idx_loan_account         ON loans (account_id);

-- ─────────────────────────────────────────────────────────────────────
-- LOAN REPAYMENTS
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_repay_loan           ON loan_repayments (loan_id);
CREATE INDEX idx_repay_status         ON loan_repayments (payment_status);
CREATE INDEX idx_repay_due_date       ON loan_repayments (due_date);

-- ─────────────────────────────────────────────────────────────────────
-- BENEFICIARIES
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_benef_customer       ON beneficiaries (customer_id);
CREATE INDEX idx_benef_type           ON beneficiaries (beneficiary_type);

-- ─────────────────────────────────────────────────────────────────────
-- ALERTS  (frequently queried by analysts)
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_alert_customer       ON alerts (customer_id);
CREATE INDEX idx_alert_account        ON alerts (account_id);
CREATE INDEX idx_alert_status         ON alerts (status);
CREATE INDEX idx_alert_severity       ON alerts (alert_severity);
CREATE INDEX idx_alert_date           ON alerts (alert_date);
CREATE INDEX idx_alert_type           ON alerts (alert_type);
CREATE INDEX idx_alert_cust_status    ON alerts (customer_id, status);
CREATE INDEX idx_alert_date_severity  ON alerts (alert_date, alert_severity);
CREATE INDEX idx_alert_transaction    ON alerts (transaction_id);

-- ─────────────────────────────────────────────────────────────────────
-- FRAUD CASES
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_fraud_customer       ON fraud_cases (customer_id);
CREATE INDEX idx_fraud_account        ON fraud_cases (account_id);
CREATE INDEX idx_fraud_status         ON fraud_cases (case_status);
CREATE INDEX idx_fraud_type           ON fraud_cases (case_type);
CREATE INDEX idx_fraud_reported       ON fraud_cases (reported_date);

-- ─────────────────────────────────────────────────────────────────────
-- KYC AUDIT LOG
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_kyc_customer         ON kyc_audit_log (customer_id);
CREATE INDEX idx_kyc_action           ON kyc_audit_log (action);
CREATE INDEX idx_kyc_date             ON kyc_audit_log (change_date);

-- ─────────────────────────────────────────────────────────────────────
-- LOGIN AUDIT  (high-volume — critical indexes)
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_login_customer       ON login_audit (customer_id);
CREATE INDEX idx_login_ip             ON login_audit (ip_address);
CREATE INDEX idx_login_datetime       ON login_audit (login_datetime);
CREATE INDEX idx_login_status         ON login_audit (login_status);
CREATE INDEX idx_login_channel        ON login_audit (login_channel);
CREATE INDEX idx_login_cust_datetime  ON login_audit (customer_id, login_datetime);
CREATE INDEX idx_login_cust_status    ON login_audit (customer_id, login_status);

-- ─────────────────────────────────────────────────────────────────────
-- AML SCREENING
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_aml_customer         ON aml_screening (customer_id);
CREATE INDEX idx_aml_date             ON aml_screening (screening_date);
CREATE INDEX idx_aml_watchlist        ON aml_screening (watchlist_matched);
CREATE INDEX idx_aml_action           ON aml_screening (action_taken);
CREATE INDEX idx_aml_risk_score       ON aml_screening (risk_score);

-- ═══════════════════════════════════════════════════════════════════════
-- INDEX CREATION COMPLETE — 75 indexes total
-- ═══════════════════════════════════════════════════════════════════════
