-- ═══════════════════════════════════════════════════════════════════════
-- BANK FRAUD ANALYST TRAINING DATABASE — FUNCTIONS & STORED PROCEDURES
-- Engine  : MySQL 8.0+
-- Run     : After data load and index creation
-- Note    : Must be run in a client that supports DELIMITER
--           (MySQL Workbench, mysql CLI, DBeaver)
-- ═══════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────
-- FUNCTION 1: fn_get_customer_risk_score
-- Returns a 0–100 risk score based on:
--   - Transaction patterns, alerts, fraud cases, KYC status, PEP flag
-- ─────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS fn_get_customer_risk_score;

DELIMITER //
CREATE FUNCTION fn_get_customer_risk_score(p_customer_id CHAR(36))
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_score       INT DEFAULT 0;
    DECLARE v_kyc_status  VARCHAR(20);
    DECLARE v_pep         BOOLEAN;
    DECLARE v_risk_cat    VARCHAR(20);
    DECLARE v_alert_count INT DEFAULT 0;
    DECLARE v_fraud_count INT DEFAULT 0;
    DECLARE v_crit_alerts INT DEFAULT 0;
    DECLARE v_susp_txn    INT DEFAULT 0;
    DECLARE v_high_val_txn INT DEFAULT 0;

    -- Base risk from KYC status
    SELECT kyc_status, pep_flag, risk_category
    INTO   v_kyc_status, v_pep, v_risk_cat
    FROM   customers
    WHERE  customer_id = p_customer_id;

    -- KYC score component (0-15)
    SET v_score = v_score + CASE v_kyc_status
        WHEN 'verified' THEN 0
        WHEN 'pending'  THEN 8
        WHEN 'expired'  THEN 12
        WHEN 'rejected' THEN 15
        ELSE 5
    END;

    -- PEP score component (0-15)
    IF v_pep = TRUE THEN
        SET v_score = v_score + 15;
    END IF;

    -- Existing risk category component (0-15)
    SET v_score = v_score + CASE v_risk_cat
        WHEN 'low'       THEN 0
        WHEN 'medium'    THEN 5
        WHEN 'high'      THEN 10
        WHEN 'very_high' THEN 15
        ELSE 0
    END;

    -- Alert count component (0-20)
    SELECT COUNT(*),
           SUM(CASE WHEN alert_severity = 'critical' THEN 1 ELSE 0 END)
    INTO   v_alert_count, v_crit_alerts
    FROM   alerts
    WHERE  customer_id = p_customer_id;

    SET v_score = v_score + LEAST(v_alert_count, 10) + LEAST(v_crit_alerts * 3, 10);

    -- Fraud case component (0-20)
    SELECT COUNT(*)
    INTO   v_fraud_count
    FROM   fraud_cases
    WHERE  customer_id = p_customer_id
      AND  case_status NOT IN ('closed_no_fraud');

    SET v_score = v_score + LEAST(v_fraud_count * 5, 20);

    -- Suspicious transaction component (0-15)
    SELECT COUNT(*),
           SUM(CASE WHEN amount > 1000000 THEN 1 ELSE 0 END)
    INTO   v_susp_txn, v_high_val_txn
    FROM   transactions t
    JOIN   accounts a ON a.account_id = t.account_id
    WHERE  a.customer_id = p_customer_id
      AND  (t.is_suspicious = TRUE OR t.fraud_flag = TRUE);

    SET v_score = v_score + LEAST(v_susp_txn * 2, 10) + LEAST(v_high_val_txn, 5);

    -- Cap at 100
    RETURN LEAST(v_score, 100);
END //
DELIMITER ;


-- ─────────────────────────────────────────────────────────────────────
-- FUNCTION 2: fn_flag_suspicious_transaction
-- Checks rules and updates is_suspicious flag.
-- Returns TRUE if flagged, FALSE otherwise.
-- Rules checked:
--   1. Amount > ₹10,00,000
--   2. Transaction between 00:00 and 04:00 (after-hours)
--   3. Amount just below ₹2,00,000 (structuring)
--   4. Foreign transaction on non-international-enabled card
-- ─────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS fn_flag_suspicious_transaction;

DELIMITER //
CREATE FUNCTION fn_flag_suspicious_transaction(p_transaction_id CHAR(36))
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_amount       DECIMAL(18,2);
    DECLARE v_txn_time     TIME;
    DECLARE v_location     VARCHAR(50);
    DECLARE v_acct_country VARCHAR(50);
    DECLARE v_is_susp      BOOLEAN DEFAULT FALSE;

    SELECT t.amount, t.transaction_time, t.location_country,
           c.country_of_residence
    INTO   v_amount, v_txn_time, v_location, v_acct_country
    FROM   transactions t
    JOIN   accounts a ON a.account_id = t.account_id
    JOIN   customers c ON c.customer_id = a.customer_id
    WHERE  t.transaction_id = p_transaction_id;

    -- Rule 1: Large transaction (> ₹10 lakh)
    IF v_amount > 1000000 THEN
        SET v_is_susp = TRUE;
    END IF;

    -- Rule 2: After-hours transaction (midnight to 4 AM)
    IF v_txn_time BETWEEN '00:00:00' AND '04:00:00' THEN
        SET v_is_susp = TRUE;
    END IF;

    -- Rule 3: Structuring (just below ₹2 lakh threshold)
    IF v_amount BETWEEN 180000 AND 199999 THEN
        SET v_is_susp = TRUE;
    END IF;

    -- Rule 4: Foreign transaction (different country from residence)
    IF v_location IS NOT NULL AND v_acct_country IS NOT NULL
       AND v_location != v_acct_country THEN
        SET v_is_susp = TRUE;
    END IF;

    -- Update the transaction flag
    UPDATE transactions
    SET    is_suspicious = v_is_susp
    WHERE  transaction_id = p_transaction_id;

    RETURN v_is_susp;
END //
DELIMITER ;


-- ─────────────────────────────────────────────────────────────────────
-- PROCEDURE: sp_get_account_velocity
-- Returns transaction count and total amount in last N hours.
-- (MySQL functions cannot return result sets, so this is a procedure)
-- ─────────────────────────────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_get_account_velocity;

DELIMITER //
CREATE PROCEDURE sp_get_account_velocity(
    IN  p_account_id  CHAR(36),
    IN  p_hours       INT
)
BEGIN
    SELECT
        COUNT(*)            AS txn_count,
        COALESCE(SUM(amount), 0) AS total_amount,
        MIN(TIMESTAMP(transaction_date, transaction_time)) AS first_txn,
        MAX(TIMESTAMP(transaction_date, transaction_time)) AS last_txn
    FROM transactions
    WHERE account_id = p_account_id
      AND TIMESTAMP(transaction_date, transaction_time) >=
          DATE_SUB(NOW(), INTERVAL p_hours HOUR);
END //
DELIMITER ;


-- ─────────────────────────────────────────────────────────────────────
-- PROCEDURE: sp_generate_daily_alerts
-- Runs all rule checks and inserts new alerts for today.
-- Rules:
--   1. Large transactions (> ₹10 lakh)
--   2. Velocity breach (5+ txns in 1 hour)
--   3. Structuring suspicion (3+ txns between ₹1.8L–₹2L in a day)
--   4. Dormant account activity (first txn in 365+ days)
--   5. After-hours transactions (midnight–4AM)
--   6. Round amount pattern (exact multiples of ₹10,000 repeated)
-- ─────────────────────────────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_generate_daily_alerts;

DELIMITER //
CREATE PROCEDURE sp_generate_daily_alerts()
BEGIN
    DECLARE v_today DATE DEFAULT CURDATE();

    -- Rule 1: Large transactions (> ₹10,00,000)
    INSERT INTO alerts (customer_id, account_id, transaction_id,
                        alert_type, alert_severity, alert_message,
                        alert_date, alert_time, status)
    SELECT
        a.customer_id,
        t.account_id,
        t.transaction_id,
        'large_transaction',
        CASE
            WHEN t.amount > 5000000 THEN 'critical'
            WHEN t.amount > 2500000 THEN 'high'
            ELSE 'medium'
        END,
        CONCAT('Large transaction of ', FORMAT(t.amount, 2),
               ' detected via ', t.transaction_mode),
        t.transaction_date,
        t.transaction_time,
        'open'
    FROM transactions t
    JOIN accounts a ON a.account_id = t.account_id
    WHERE t.transaction_date = v_today
      AND t.amount > 1000000
      AND t.transaction_id NOT IN (
          SELECT COALESCE(transaction_id, '') FROM alerts
          WHERE alert_type = 'large_transaction'
      );

    -- Rule 2: Structuring suspicion
    INSERT INTO alerts (customer_id, account_id,
                        alert_type, alert_severity, alert_message,
                        alert_date, alert_time, status)
    SELECT
        a.customer_id,
        t.account_id,
        'structuring_suspicion',
        'high',
        CONCAT('Possible structuring: ', cnt, ' transactions between 1.8L–2L today'),
        v_today,
        CURTIME(),
        'open'
    FROM (
        SELECT account_id, COUNT(*) AS cnt
        FROM transactions
        WHERE transaction_date = v_today
          AND amount BETWEEN 180000 AND 199999
        GROUP BY account_id
        HAVING COUNT(*) >= 3
    ) t
    JOIN accounts a ON a.account_id = t.account_id;

    -- Rule 3: Dormant account activity
    INSERT INTO alerts (customer_id, account_id,
                        alert_type, alert_severity, alert_message,
                        alert_date, alert_time, status)
    SELECT
        a.customer_id,
        a.account_id,
        'dormant_account_activity',
        'high',
        CONCAT('Dormant account reactivated after ',
               DATEDIFF(v_today, a.last_transaction_date), ' days'),
        v_today,
        CURTIME(),
        'open'
    FROM accounts a
    WHERE a.account_status = 'dormant'
      AND a.account_id IN (
          SELECT DISTINCT account_id
          FROM transactions
          WHERE transaction_date = v_today
      );

    -- Rule 4: After-hours transactions (midnight–4AM)
    INSERT INTO alerts (customer_id, account_id, transaction_id,
                        alert_type, alert_severity, alert_message,
                        alert_date, alert_time, status)
    SELECT
        a.customer_id,
        t.account_id,
        t.transaction_id,
        'after_hours_transaction',
        'medium',
        CONCAT('After-hours transaction at ', t.transaction_time,
               ' for amount ', FORMAT(t.amount, 2)),
        t.transaction_date,
        t.transaction_time,
        'open'
    FROM transactions t
    JOIN accounts a ON a.account_id = t.account_id
    WHERE t.transaction_date = v_today
      AND t.transaction_time BETWEEN '00:00:00' AND '04:00:00'
      AND t.amount > 50000
      AND t.transaction_id NOT IN (
          SELECT COALESCE(transaction_id, '') FROM alerts
          WHERE alert_type = 'after_hours_transaction'
      );

    -- Rule 5: Round amount pattern
    INSERT INTO alerts (customer_id, account_id,
                        alert_type, alert_severity, alert_message,
                        alert_date, alert_time, status)
    SELECT
        a.customer_id,
        t.account_id,
        'round_amount_pattern',
        'medium',
        CONCAT('Round amount pattern: ', cnt,
               ' round-number transfers today'),
        v_today,
        CURTIME(),
        'open'
    FROM (
        SELECT account_id, COUNT(*) AS cnt
        FROM transactions
        WHERE transaction_date = v_today
          AND MOD(amount, 10000) = 0
          AND amount >= 10000
        GROUP BY account_id
        HAVING COUNT(*) >= 3
    ) t
    JOIN accounts a ON a.account_id = t.account_id;

    SELECT 'Daily alert generation complete' AS result;
END //
DELIMITER ;


-- ─────────────────────────────────────────────────────────────────────
-- PROCEDURE: sp_freeze_account
-- Freezes an account and logs the action in kyc_audit_log.
-- ─────────────────────────────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_freeze_account;

DELIMITER //
CREATE PROCEDURE sp_freeze_account(
    IN p_account_id CHAR(36),
    IN p_reason     TEXT
)
BEGIN
    DECLARE v_customer_id CHAR(36);
    DECLARE v_old_status  VARCHAR(30);

    -- Get current info
    SELECT customer_id, account_status
    INTO   v_customer_id, v_old_status
    FROM   accounts
    WHERE  account_id = p_account_id;

    IF v_customer_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Account not found';
    END IF;

    IF v_old_status = 'frozen' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Account is already frozen';
    END IF;

    -- Freeze the account
    UPDATE accounts
    SET    account_status = 'frozen'
    WHERE  account_id = p_account_id;

    -- Log the action
    INSERT INTO kyc_audit_log (customer_id, action, changed_fields,
                               changed_by, change_date, remarks)
    VALUES (
        v_customer_id,
        'updated',
        JSON_OBJECT(
            'table', 'accounts',
            'account_id', p_account_id,
            'old_status', v_old_status,
            'new_status', 'frozen'
        ),
        'system_sp_freeze',
        NOW(),
        p_reason
    );

    SELECT CONCAT('Account ', p_account_id, ' frozen successfully. Previous status: ',
                  v_old_status) AS result;
END //
DELIMITER ;


-- ─────────────────────────────────────────────────────────────────────
-- PROCEDURE: sp_close_fraud_case
-- Closes a fraud case with resolution notes and recovery amount.
-- ─────────────────────────────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_close_fraud_case;

DELIMITER //
CREATE PROCEDURE sp_close_fraud_case(
    IN p_case_id          INT,
    IN p_resolution       TEXT,
    IN p_recovery_amount  DECIMAL(18,2)
)
BEGIN
    DECLARE v_case_status  VARCHAR(30);
    DECLARE v_customer_id  CHAR(36);
    DECLARE v_account_id   CHAR(36);

    -- Validate case exists and is not already closed
    SELECT case_status, customer_id, account_id
    INTO   v_case_status, v_customer_id, v_account_id
    FROM   fraud_cases
    WHERE  case_id = p_case_id;

    IF v_case_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Fraud case not found';
    END IF;

    IF v_case_status IN ('confirmed', 'closed_no_fraud', 'filed_fir') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Fraud case is already closed or finalized';
    END IF;

    -- Close the case
    UPDATE fraud_cases
    SET    case_status       = 'confirmed',
           closed_date       = CURDATE(),
           confirmed_date    = CURDATE(),
           investigation_notes = CONCAT(
               COALESCE(investigation_notes, ''),
               '\n[CLOSED] ', NOW(), ': ', p_resolution
           ),
           recovery_amount   = p_recovery_amount
    WHERE  case_id = p_case_id;

    -- Log in KYC audit
    INSERT INTO kyc_audit_log (customer_id, action, changed_fields,
                               changed_by, change_date, remarks)
    VALUES (
        v_customer_id,
        'updated',
        JSON_OBJECT(
            'table', 'fraud_cases',
            'case_id', p_case_id,
            'old_status', v_case_status,
            'new_status', 'confirmed',
            'recovery_amount', p_recovery_amount
        ),
        'system_sp_close_fraud',
        NOW(),
        p_resolution
    );

    -- If account was under investigation, revert to active
    UPDATE accounts
    SET    account_status = 'active'
    WHERE  account_id = v_account_id
      AND  account_status = 'under_investigation';

    SELECT CONCAT('Fraud case #', p_case_id,
                  ' closed. Recovery: ₹', FORMAT(p_recovery_amount, 2)) AS result;
END //
DELIMITER ;


-- ═══════════════════════════════════════════════════════════════════════
-- ALL FUNCTIONS AND STORED PROCEDURES CREATED SUCCESSFULLY
-- ═══════════════════════════════════════════════════════════════════════
