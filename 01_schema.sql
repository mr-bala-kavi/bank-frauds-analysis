-- ═══════════════════════════════════════════════════════════════════════
-- BANK FRAUD ANALYST TRAINING DATABASE — SCHEMA
-- Engine  : MySQL 8.0+
-- Charset : utf8mb4 (full Unicode support)
-- Run     : First file — creates database and all 15 tables
-- ═══════════════════════════════════════════════════════════════════════

DROP DATABASE IF EXISTS bank_fraud_db;
CREATE DATABASE bank_fraud_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────
-- 1. CUSTOMERS
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE customers (
    customer_id           CHAR(36)        NOT NULL,
    full_name             VARCHAR(160)    NOT NULL,
    first_name            VARCHAR(80)     NOT NULL,
    last_name             VARCHAR(80)     NOT NULL,
    salutation            ENUM('Mr','Mrs','Ms','Dr','Prof') DEFAULT NULL,
    date_of_birth         DATE            NOT NULL,
    gender                ENUM('M','F','O') NOT NULL,
    nationality           VARCHAR(50)     NOT NULL,
    country_of_residence  VARCHAR(50)     NOT NULL,
    occupation            VARCHAR(100)    DEFAULT NULL,
    annual_income         DECIMAL(15,2)   DEFAULT NULL,
    kyc_status            ENUM('verified','pending','rejected','expired')
                              NOT NULL DEFAULT 'pending',
    kyc_verified_date     DATE            DEFAULT NULL,
    pep_flag              BOOLEAN         NOT NULL DEFAULT FALSE,
    risk_category         ENUM('low','medium','high','very_high')
                              NOT NULL DEFAULT 'low',
    customer_since        DATE            NOT NULL,
    is_active             BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 2. CUSTOMER IDENTITY DOCUMENTS
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE customer_identity_documents (
    document_id       INT             AUTO_INCREMENT,
    customer_id       CHAR(36)        NOT NULL,
    document_type     ENUM('aadhaar','pan','passport','driving_license',
                           'ssn','nic','emirates_id') NOT NULL,
    document_number   VARCHAR(30)     NOT NULL,
    issued_country    VARCHAR(50)     NOT NULL,
    issued_date       DATE            DEFAULT NULL,
    expiry_date       DATE            DEFAULT NULL,
    is_primary        BOOLEAN         NOT NULL DEFAULT FALSE,
    PRIMARY KEY (document_id),
    CONSTRAINT fk_doc_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 3. CUSTOMER CONTACT
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE customer_contact (
    contact_id              INT             AUTO_INCREMENT,
    customer_id             CHAR(36)        NOT NULL,
    phone_primary           VARCHAR(20)     DEFAULT NULL,
    phone_secondary         VARCHAR(20)     DEFAULT NULL,
    email_primary           VARCHAR(120)    DEFAULT NULL,
    email_secondary         VARCHAR(120)    DEFAULT NULL,
    preferred_contact_method ENUM('phone','email','sms') DEFAULT 'phone',
    do_not_call             BOOLEAN         NOT NULL DEFAULT FALSE,
    last_contact_date       DATE            DEFAULT NULL,
    PRIMARY KEY (contact_id),
    CONSTRAINT fk_contact_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 4. CUSTOMER ADDRESS
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE customer_address (
    address_id    INT             AUTO_INCREMENT,
    customer_id   CHAR(36)        NOT NULL,
    address_type  ENUM('residential','permanent','office','mailing')
                      NOT NULL DEFAULT 'residential',
    address_line1 VARCHAR(200)    NOT NULL,
    address_line2 VARCHAR(200)    DEFAULT NULL,
    city          VARCHAR(80)     NOT NULL,
    state         VARCHAR(80)     DEFAULT NULL,
    postal_code   VARCHAR(15)     DEFAULT NULL,
    country       VARCHAR(50)     NOT NULL,
    is_current    BOOLEAN         NOT NULL DEFAULT TRUE,
    from_date     DATE            DEFAULT NULL,
    to_date       DATE            DEFAULT NULL,
    PRIMARY KEY (address_id),
    CONSTRAINT fk_addr_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 5. ACCOUNTS
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE accounts (
    account_id              CHAR(36)        NOT NULL,
    customer_id             CHAR(36)        NOT NULL,
    account_number          VARCHAR(22)     NOT NULL,
    account_type            ENUM('savings','current','salary','nri',
                                 'fixed_deposit','recurring_deposit','joint')
                                NOT NULL DEFAULT 'savings',
    branch_code             VARCHAR(10)     DEFAULT NULL,
    ifsc_code               VARCHAR(11)     DEFAULT NULL,
    currency                VARCHAR(3)      NOT NULL DEFAULT 'INR',
    current_balance         DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    available_balance       DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    minimum_balance         DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    account_status          ENUM('active','dormant','frozen','closed',
                                 'under_investigation')
                                NOT NULL DEFAULT 'active',
    opened_date             DATE            NOT NULL,
    closed_date             DATE            DEFAULT NULL,
    last_transaction_date   DATE            DEFAULT NULL,
    overdraft_limit         DECIMAL(18,2)   DEFAULT 0.00,
    interest_rate           DECIMAL(5,2)    DEFAULT NULL,
    joint_holder_customer_id CHAR(36)       DEFAULT NULL,
    PRIMARY KEY (account_id),
    UNIQUE KEY uk_account_number (account_number),
    CONSTRAINT fk_acct_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_acct_joint_holder
        FOREIGN KEY (joint_holder_customer_id) REFERENCES customers(customer_id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 6. TRANSACTIONS
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE transactions (
    transaction_id           CHAR(36)        NOT NULL,
    account_id               CHAR(36)        NOT NULL,
    transaction_date         DATE            NOT NULL,
    transaction_time         TIME            NOT NULL,
    value_date               DATE            NOT NULL,
    transaction_type         ENUM('credit','debit') NOT NULL,
    transaction_mode         ENUM('NEFT','RTGS','IMPS','UPI','ATM_CASH',
                                  'BRANCH_CASH','CHEQUE','ONLINE_TRANSFER',
                                  'CARD_PURCHASE','EMI','INTEREST','CHARGES',
                                  'SALARY_CREDIT','REFUND') NOT NULL,
    amount                   DECIMAL(18,2)   NOT NULL,
    currency                 VARCHAR(3)      NOT NULL DEFAULT 'INR',
    balance_after_transaction DECIMAL(18,2)  NOT NULL,
    description              VARCHAR(255)    DEFAULT NULL,
    narration                VARCHAR(255)    DEFAULT NULL,
    reference_number         VARCHAR(30)     DEFAULT NULL,
    beneficiary_account_id   CHAR(36)        DEFAULT NULL,
    beneficiary_name         VARCHAR(160)    DEFAULT NULL,
    beneficiary_bank         VARCHAR(100)    DEFAULT NULL,
    beneficiary_ifsc         VARCHAR(11)     DEFAULT NULL,
    channel                  ENUM('mobile_app','internet_banking','atm',
                                  'branch','api','pos') DEFAULT NULL,
    merchant_name            VARCHAR(120)    DEFAULT NULL,
    merchant_category_code   VARCHAR(6)      DEFAULT NULL,
    location_city            VARCHAR(80)     DEFAULT NULL,
    location_country         VARCHAR(50)     DEFAULT NULL,
    ip_address               VARCHAR(45)     DEFAULT NULL,
    device_id                VARCHAR(64)     DEFAULT NULL,
    is_suspicious            BOOLEAN         NOT NULL DEFAULT FALSE,
    fraud_flag               BOOLEAN         NOT NULL DEFAULT FALSE,
    fraud_type               VARCHAR(60)     DEFAULT NULL,
    created_at               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_id),
    CONSTRAINT fk_txn_account
        FOREIGN KEY (account_id) REFERENCES accounts(account_id)
        ON DELETE CASCADE
    -- Note: beneficiary_account_id FK omitted to allow external beneficiaries
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 7. CARDS
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE cards (
    card_id                         CHAR(36)        NOT NULL,
    account_id                      CHAR(36)        NOT NULL,
    customer_id                     CHAR(36)        NOT NULL,
    card_number_masked              VARCHAR(19)     NOT NULL,
    card_type                       ENUM('debit','credit','prepaid','forex')
                                        NOT NULL,
    card_network                    ENUM('Visa','Mastercard','Rupay','Amex')
                                        NOT NULL,
    card_status                     ENUM('active','blocked','expired',
                                         'hotlisted','pending_activation')
                                        NOT NULL DEFAULT 'active',
    issue_date                      DATE            NOT NULL,
    expiry_date                     DATE            NOT NULL,
    credit_limit                    DECIMAL(18,2)   DEFAULT NULL,
    outstanding_amount              DECIMAL(18,2)   DEFAULT NULL,
    daily_atm_limit                 DECIMAL(12,2)   DEFAULT 25000.00,
    daily_pos_limit                 DECIMAL(12,2)   DEFAULT 100000.00,
    daily_online_limit              DECIMAL(12,2)   DEFAULT 100000.00,
    international_transactions_enabled BOOLEAN      NOT NULL DEFAULT FALSE,
    contactless_enabled             BOOLEAN         NOT NULL DEFAULT TRUE,
    last_used_date                  DATE            DEFAULT NULL,
    last_used_location              VARCHAR(100)    DEFAULT NULL,
    PRIMARY KEY (card_id),
    CONSTRAINT fk_card_account
        FOREIGN KEY (account_id) REFERENCES accounts(account_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_card_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 8. LOANS
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE loans (
    loan_id                  CHAR(36)        NOT NULL,
    customer_id              CHAR(36)        NOT NULL,
    account_id               CHAR(36)        NOT NULL,
    loan_type                ENUM('home_loan','personal_loan','auto_loan',
                                  'education_loan','gold_loan','business_loan',
                                  'credit_card_loan') NOT NULL,
    principal_amount         DECIMAL(18,2)   NOT NULL,
    sanctioned_amount        DECIMAL(18,2)   NOT NULL,
    disbursed_amount         DECIMAL(18,2)   NOT NULL,
    outstanding_amount       DECIMAL(18,2)   NOT NULL,
    interest_rate            DECIMAL(5,2)    NOT NULL,
    interest_type            ENUM('fixed','floating') NOT NULL DEFAULT 'floating',
    tenure_months            INT             NOT NULL,
    remaining_months         INT             NOT NULL,
    emi_amount               DECIMAL(14,2)   NOT NULL,
    emi_due_date             TINYINT         NOT NULL DEFAULT 5,
    loan_status              ENUM('active','closed','npa','written_off',
                                  'under_collection') NOT NULL DEFAULT 'active',
    loan_start_date          DATE            NOT NULL,
    loan_end_date            DATE            DEFAULT NULL,
    collateral_type          VARCHAR(60)     DEFAULT NULL,
    collateral_value         DECIMAL(18,2)   DEFAULT NULL,
    purpose_of_loan          VARCHAR(200)    DEFAULT NULL,
    cibil_score_at_approval  INT             DEFAULT NULL,
    co_applicant_customer_id CHAR(36)        DEFAULT NULL,
    PRIMARY KEY (loan_id),
    CONSTRAINT fk_loan_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_loan_account
        FOREIGN KEY (account_id) REFERENCES accounts(account_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_loan_coapplicant
        FOREIGN KEY (co_applicant_customer_id) REFERENCES customers(customer_id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 9. LOAN REPAYMENTS
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE loan_repayments (
    repayment_id             INT             AUTO_INCREMENT,
    loan_id                  CHAR(36)        NOT NULL,
    due_date                 DATE            NOT NULL,
    paid_date                DATE            DEFAULT NULL,
    emi_amount               DECIMAL(14,2)   NOT NULL,
    amount_paid              DECIMAL(14,2)   DEFAULT 0.00,
    principal_component      DECIMAL(14,2)   DEFAULT 0.00,
    interest_component       DECIMAL(14,2)   DEFAULT 0.00,
    penalty_charges          DECIMAL(14,2)   DEFAULT 0.00,
    outstanding_after_payment DECIMAL(18,2)  DEFAULT NULL,
    payment_status           ENUM('paid','partial','missed','bounced')
                                 NOT NULL DEFAULT 'paid',
    bounce_reason            VARCHAR(200)    DEFAULT NULL,
    days_past_due            INT             DEFAULT 0,
    PRIMARY KEY (repayment_id),
    CONSTRAINT fk_repay_loan
        FOREIGN KEY (loan_id) REFERENCES loans(loan_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 10. BENEFICIARIES
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE beneficiaries (
    beneficiary_id             INT             AUTO_INCREMENT,
    customer_id                CHAR(36)        NOT NULL,
    beneficiary_name           VARCHAR(160)    NOT NULL,
    beneficiary_account_number VARCHAR(22)     NOT NULL,
    beneficiary_ifsc           VARCHAR(11)     DEFAULT NULL,
    beneficiary_bank_name      VARCHAR(100)    DEFAULT NULL,
    beneficiary_type           ENUM('own_account','registered','unregistered')
                                   NOT NULL DEFAULT 'registered',
    added_date                 DATE            NOT NULL,
    is_active                  BOOLEAN         NOT NULL DEFAULT TRUE,
    max_transfer_limit_per_day DECIMAL(18,2)   DEFAULT 500000.00,
    total_transferred_lifetime DECIMAL(18,2)   DEFAULT 0.00,
    PRIMARY KEY (beneficiary_id),
    CONSTRAINT fk_benef_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 11. ALERTS
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE alerts (
    alert_id          INT             AUTO_INCREMENT,
    customer_id       CHAR(36)        NOT NULL,
    account_id        CHAR(36)        NOT NULL,
    transaction_id    CHAR(36)        DEFAULT NULL,
    alert_type        ENUM('large_transaction','unusual_pattern',
                           'foreign_transaction','multiple_failed_attempts',
                           'dormant_account_activity','velocity_breach',
                           'structuring_suspicion','card_cloning_suspicion',
                           'new_beneficiary_large_transfer','round_amount_pattern',
                           'geo_anomaly','after_hours_transaction') NOT NULL,
    alert_severity    ENUM('low','medium','high','critical') NOT NULL,
    alert_message     VARCHAR(500)    NOT NULL,
    alert_date        DATE            NOT NULL,
    alert_time        TIME            NOT NULL,
    status            ENUM('open','under_review','resolved',
                           'false_positive','escalated')
                          NOT NULL DEFAULT 'open',
    assigned_to_analyst VARCHAR(80)   DEFAULT NULL,
    resolution_notes   TEXT           DEFAULT NULL,
    resolved_date      DATE           DEFAULT NULL,
    PRIMARY KEY (alert_id),
    CONSTRAINT fk_alert_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_alert_account
        FOREIGN KEY (account_id) REFERENCES accounts(account_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 12. FRAUD CASES
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE fraud_cases (
    case_id             INT             AUTO_INCREMENT,
    customer_id         CHAR(36)        NOT NULL,
    account_id          CHAR(36)        NOT NULL,
    case_type           ENUM('account_takeover','identity_theft','card_fraud',
                             'loan_fraud','money_laundering','phishing',
                             'upi_fraud','cheque_fraud','internal_fraud',
                             'cyber_fraud') NOT NULL,
    case_status         ENUM('reported','investigating','confirmed',
                             'closed_no_fraud','reported_to_rbi','filed_fir')
                            NOT NULL DEFAULT 'reported',
    fraud_amount        DECIMAL(18,2)   NOT NULL DEFAULT 0.00,
    reported_date       DATE            NOT NULL,
    confirmed_date      DATE            DEFAULT NULL,
    closed_date         DATE            DEFAULT NULL,
    reported_by         ENUM('customer','system','analyst','branch','regulator')
                            NOT NULL DEFAULT 'system',
    investigation_notes TEXT            DEFAULT NULL,
    recovery_amount     DECIMAL(18,2)   DEFAULT 0.00,
    fir_number          VARCHAR(30)     DEFAULT NULL,
    PRIMARY KEY (case_id),
    CONSTRAINT fk_fraud_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_fraud_account
        FOREIGN KEY (account_id) REFERENCES accounts(account_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 13. KYC AUDIT LOG
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE kyc_audit_log (
    log_id          INT             AUTO_INCREMENT,
    customer_id     CHAR(36)        NOT NULL,
    action          ENUM('created','updated','verified','rejected',
                         're_kyc_triggered','document_added') NOT NULL,
    changed_fields  JSON            DEFAULT NULL,
    changed_by      VARCHAR(80)     NOT NULL DEFAULT 'system',
    change_date     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remarks         VARCHAR(500)    DEFAULT NULL,
    PRIMARY KEY (log_id),
    CONSTRAINT fk_kyc_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 14. LOGIN AUDIT
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE login_audit (
    login_id                INT             AUTO_INCREMENT,
    customer_id             CHAR(36)        NOT NULL,
    login_datetime          DATETIME        NOT NULL,
    login_channel           ENUM('mobile_app','internet_banking','api')
                                NOT NULL,
    ip_address              VARCHAR(45)     NOT NULL,
    device_id               VARCHAR(64)     DEFAULT NULL,
    device_type             VARCHAR(30)     DEFAULT NULL,
    os                      VARCHAR(30)     DEFAULT NULL,
    browser                 VARCHAR(40)     DEFAULT NULL,
    location_city           VARCHAR(80)     DEFAULT NULL,
    location_country        VARCHAR(50)     DEFAULT NULL,
    login_status            ENUM('success','failed','blocked','suspicious')
                                NOT NULL DEFAULT 'success',
    failure_reason          VARCHAR(200)    DEFAULT NULL,
    session_duration_minutes INT            DEFAULT NULL,
    PRIMARY KEY (login_id),
    CONSTRAINT fk_login_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────────
-- 15. AML SCREENING
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE aml_screening (
    screening_id     INT             AUTO_INCREMENT,
    customer_id      CHAR(36)        NOT NULL,
    screening_date   DATETIME        NOT NULL,
    screening_type   ENUM('onboarding','periodic','transaction_triggered',
                          'manual') NOT NULL,
    watchlist_matched BOOLEAN        NOT NULL DEFAULT FALSE,
    match_details    JSON            DEFAULT NULL,
    risk_score       INT             NOT NULL DEFAULT 0,
    action_taken     ENUM('cleared','escalated','blocked','reported_fiu')
                         NOT NULL DEFAULT 'cleared',
    analyst_notes    TEXT            DEFAULT NULL,
    PRIMARY KEY (screening_id),
    CONSTRAINT fk_aml_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE,
    CONSTRAINT chk_risk_score CHECK (risk_score BETWEEN 0 AND 100)
) ENGINE=InnoDB;

-- ═══════════════════════════════════════════════════════════════════════
-- SCHEMA CREATION COMPLETE
-- Next step: Run 05_generate_data.py to populate data
-- Then run:  02_indexes.sql → 03_views.sql → 04_functions.sql
-- ═══════════════════════════════════════════════════════════════════════
