-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 14: STORED PROCEDURES
-- A stored procedure is a named, reusable block of SQL code
-- stored in the database and called by name.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- IMPORTANT: Change delimiter so MySQL doesn't end the procedure early
-- ─────────────────────────────────────────────────────────────────────────
DELIMITER $$

-- ─────────────────────────────────────────────────────────────────────────
-- 14.1 SIMPLE PROCEDURE — No parameters
-- ─────────────────────────────────────────────────────────────────────────

CREATE PROCEDURE sp_show_fraud_summary()
BEGIN
    SELECT
        case_type,
        COUNT(*)          AS cases,
        SUM(fraud_amount) AS total_fraud
    FROM fraud_cases
    GROUP BY case_type
    ORDER BY total_fraud DESC;
END$$

-- Call it:
CALL sp_show_fraud_summary()$$

-- ─────────────────────────────────────────────────────────────────────────
-- 14.2 PROCEDURE WITH IN parameter (input value passed in)
-- ─────────────────────────────────────────────────────────────────────────

CREATE PROCEDURE sp_get_customer_accounts(
    IN p_customer_id VARCHAR(100)    -- IN = input parameter
)
BEGIN
    SELECT
        a.account_number,
        a.account_type,
        a.account_status,
        a.current_balance,
        a.opened_date
    FROM accounts a
    WHERE a.customer_id = p_customer_id;
END$$

-- Call with a specific customer_id:
-- CALL sp_get_customer_accounts('some-customer-uuid')$$

-- ─────────────────────────────────────────────────────────────────────────
-- 14.3 PROCEDURE WITH OUT parameter (returns a value back to the caller)
-- ─────────────────────────────────────────────────────────────────────────

CREATE PROCEDURE sp_get_account_balance(
    IN  p_account_number VARCHAR(50),
    OUT p_balance        DECIMAL(15,2)    -- OUT = output parameter
)
BEGIN
    SELECT current_balance
    INTO   p_balance    -- store result in OUT variable
    FROM   accounts
    WHERE  account_number = p_account_number;
END$$

-- Call and retrieve the OUT parameter:
-- CALL sp_get_account_balance('ACC-00001', @balance)$$
-- SELECT @balance$$

-- ─────────────────────────────────────────────────────────────────────────
-- 14.4 PROCEDURE WITH INOUT parameter (value passed in AND returned)
-- ─────────────────────────────────────────────────────────────────────────

CREATE PROCEDURE sp_apply_interest(
    INOUT p_balance DECIMAL(15,2),  -- INOUT = both input and output
    IN    p_rate    DECIMAL(5,2)
)
BEGIN
    SET p_balance = p_balance + (p_balance * p_rate / 100);
END$$

-- Usage:
-- SET @my_balance = 100000$$
-- CALL sp_apply_interest(@my_balance, 5.0)$$
-- SELECT @my_balance$$    -- shows 105000

-- ─────────────────────────────────────────────────────────────────────────
-- 14.5 PROCEDURE WITH IF / ELSE logic
-- ─────────────────────────────────────────────────────────────────────────

CREATE PROCEDURE sp_classify_customer(
    IN  p_customer_id  VARCHAR(100),
    OUT p_segment      VARCHAR(50)
)
BEGIN
    DECLARE v_income      DECIMAL(15,2);
    DECLARE v_risk        VARCHAR(20);
    DECLARE v_case_count  INT;

    -- Fetch data into local variables:
    SELECT annual_income, risk_category
    INTO   v_income, v_risk
    FROM   customers
    WHERE  customer_id = p_customer_id;

    SELECT COUNT(*) INTO v_case_count
    FROM fraud_cases
    WHERE customer_id = p_customer_id;

    -- Apply business rules:
    IF v_case_count > 0 THEN
        SET p_segment = 'FLAGGED';
    ELSEIF v_risk = 'very_high' THEN
        SET p_segment = 'WATCHLIST';
    ELSEIF v_income > 2000000 THEN
        SET p_segment = 'PREMIUM';
    ELSEIF v_income > 500000 THEN
        SET p_segment = 'STANDARD';
    ELSE
        SET p_segment = 'BASIC';
    END IF;
END$$

-- ─────────────────────────────────────────────────────────────────────────
-- 14.6 PROCEDURE WITH LOOP (iterate over data)
-- ─────────────────────────────────────────────────────────────────────────

CREATE PROCEDURE sp_count_iterations(
    IN p_limit INT
)
BEGIN
    DECLARE counter INT DEFAULT 1;

    WHILE counter <= p_limit DO
        -- In real procedures you'd do something per iteration:
        SELECT CONCAT('Iteration: ', counter) AS step;
        SET counter = counter + 1;
    END WHILE;
END$$

-- CALL sp_count_iterations(3)$$

-- ─────────────────────────────────────────────────────────────────────────
-- 14.7 PROCEDURE WITH CURSOR (row-by-row processing)
-- ─────────────────────────────────────────────────────────────────────────

CREATE PROCEDURE sp_process_alerts()
BEGIN
    DECLARE done          INT DEFAULT FALSE;
    DECLARE v_alert_id    INT;
    DECLARE v_severity    VARCHAR(20);

    -- Declare cursor:
    DECLARE alert_cursor CURSOR FOR
        SELECT alert_id, alert_severity
        FROM alerts
        WHERE status = 'open' AND alert_severity = 'critical'
        LIMIT 10;

    -- Handler: when no more rows, set done = TRUE
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN alert_cursor;

    read_loop: LOOP
        FETCH alert_cursor INTO v_alert_id, v_severity;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Process each row:
        SELECT CONCAT('Processing alert: ', v_alert_id, ' Severity: ', v_severity) AS info;
    END LOOP;

    CLOSE alert_cursor;
END$$

-- ─────────────────────────────────────────────────────────────────────────
-- 14.8 REAL-WORLD PROCEDURE — Freeze an account with reason logging
-- ─────────────────────────────────────────────────────────────────────────

CREATE PROCEDURE sp_learn_freeze_account(
    IN p_account_id     VARCHAR(100),
    IN p_freeze_reason  VARCHAR(500)
)
BEGIN
    DECLARE v_current_status VARCHAR(50);

    -- Check current status:
    SELECT account_status
    INTO   v_current_status
    FROM   accounts
    WHERE  account_id = p_account_id;

    IF v_current_status = 'frozen' THEN
        SELECT 'Account is already frozen.' AS message;
    ELSE
        UPDATE accounts
        SET account_status = 'frozen'
        WHERE account_id = p_account_id;

        SELECT CONCAT('Account ', p_account_id, ' frozen. Reason: ', p_freeze_reason) AS message;
    END IF;
END$$

DELIMITER ;    -- restore delimiter back to ;

-- ─────────────────────────────────────────────────────────────────────────
-- 14.9 SHOW, VIEW, DROP procedures
-- ─────────────────────────────────────────────────────────────────────────

-- See all stored procedures in the database:
SHOW PROCEDURE STATUS WHERE Db = 'bank_fraud_db';

-- See the code of a stored procedure:
SHOW CREATE PROCEDURE sp_show_fraud_summary;

-- Drop a procedure:
DROP PROCEDURE IF EXISTS sp_show_fraud_summary;
DROP PROCEDURE IF EXISTS sp_get_customer_accounts;
DROP PROCEDURE IF EXISTS sp_get_account_balance;
DROP PROCEDURE IF EXISTS sp_apply_interest;
DROP PROCEDURE IF EXISTS sp_classify_customer;
DROP PROCEDURE IF EXISTS sp_count_iterations;
DROP PROCEDURE IF EXISTS sp_process_alerts;
DROP PROCEDURE IF EXISTS sp_learn_freeze_account;
