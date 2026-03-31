-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 15: TRIGGERS
-- A trigger is SQL code that runs AUTOMATICALLY when INSERT/UPDATE/DELETE
-- happens on a table — you never call it manually.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- SETUP: Create supporting tables for trigger demos
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trigger_audit_log (
    log_id        INT AUTO_INCREMENT PRIMARY KEY,
    table_name    VARCHAR(100),
    action        VARCHAR(10),     -- INSERT / UPDATE / DELETE
    record_id     VARCHAR(100),
    old_value     TEXT,
    new_value     TEXT,
    changed_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    changed_by    VARCHAR(100)  DEFAULT CURRENT_USER()
);

CREATE TABLE IF NOT EXISTS trigger_demo_accounts (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    account_no    VARCHAR(30) UNIQUE,
    balance       DECIMAL(15,2) DEFAULT 0,
    status        VARCHAR(20) DEFAULT 'active',
    updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

DELIMITER $$

-- ─────────────────────────────────────────────────────────────────────────
-- 15.1 BEFORE INSERT trigger — Validate or transform data BEFORE inserting
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trg_before_insert_account
BEFORE INSERT ON trigger_demo_accounts
FOR EACH ROW
BEGIN
    -- Automatically uppercase the account number:
    SET NEW.account_no = UPPER(NEW.account_no);

    -- Enforce minimum balance rule:
    IF NEW.balance < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Balance cannot be negative!';
    END IF;
END$$

-- Test it:
INSERT INTO trigger_demo_accounts (account_no, balance) VALUES ('acc-001', 5000)$$
SELECT * FROM trigger_demo_accounts$$    -- account_no = 'ACC-001' (auto-uppercased)

-- This will fail:
-- INSERT INTO trigger_demo_accounts (account_no, balance) VALUES ('acc-002', -100)$$
-- ERROR: Balance cannot be negative!

-- ─────────────────────────────────────────────────────────────────────────
-- 15.2 AFTER INSERT trigger — Log new insertions into audit table
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trg_after_insert_account
AFTER INSERT ON trigger_demo_accounts
FOR EACH ROW
BEGIN
    INSERT INTO trigger_audit_log (table_name, action, record_id, new_value)
    VALUES (
        'trigger_demo_accounts',
        'INSERT',
        NEW.id,
        CONCAT('account_no=', NEW.account_no, ', balance=', NEW.balance)
    );
END$$

-- Test: Insert a row and check the audit log:
INSERT INTO trigger_demo_accounts (account_no, balance) VALUES ('ACC-003', 25000)$$
SELECT * FROM trigger_audit_log$$    -- should have a new log entry

-- ─────────────────────────────────────────────────────────────────────────
-- 15.3 BEFORE UPDATE trigger — Prevent invalid changes & log old/new values
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trg_before_update_account
BEFORE UPDATE ON trigger_demo_accounts
FOR EACH ROW
BEGIN
    -- Prevent unfreezing a frozen account without a proper reason:
    -- (simplified check — in real world, you'd pass a reason parameter)
    IF OLD.status = 'frozen' AND NEW.status = 'active' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot unfreeze account via direct UPDATE. Use sp_unfreeze_account().';
    END IF;

    -- Auto-set updated_at timestamp:
    SET NEW.updated_at = NOW();
END$$

-- ─────────────────────────────────────────────────────────────────────────
-- 15.4 AFTER UPDATE trigger — Audit balance changes
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trg_after_update_account
AFTER UPDATE ON trigger_demo_accounts
FOR EACH ROW
BEGIN
    -- Only log if balance actually changed:
    IF OLD.balance != NEW.balance THEN
        INSERT INTO trigger_audit_log (table_name, action, record_id, old_value, new_value)
        VALUES (
            'trigger_demo_accounts',
            'UPDATE',
            OLD.id,
            CONCAT('balance=', OLD.balance),
            CONCAT('balance=', NEW.balance)
        );
    END IF;
END$$

-- Test: Update balance and check audit:
UPDATE trigger_demo_accounts SET balance = 30000 WHERE account_no = 'ACC-003'$$
SELECT * FROM trigger_audit_log$$

-- ─────────────────────────────────────────────────────────────────────────
-- 15.5 BEFORE DELETE trigger — Prevent deletion of important records
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trg_before_delete_account
BEFORE DELETE ON trigger_demo_accounts
FOR EACH ROW
BEGIN
    -- Block deletion if account has balance > 0:
    IF OLD.balance > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot delete account with non-zero balance. Clear balance first.';
    END IF;
END$$

-- ─────────────────────────────────────────────────────────────────────────
-- 15.6 AFTER DELETE trigger — Archive deleted records
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER trg_after_delete_account
AFTER DELETE ON trigger_demo_accounts
FOR EACH ROW
BEGIN
    INSERT INTO trigger_audit_log (table_name, action, record_id, old_value)
    VALUES (
        'trigger_demo_accounts',
        'DELETE',
        OLD.id,
        CONCAT('account_no=', OLD.account_no, ', balance=', OLD.balance, ', status=', OLD.status)
    );
END$$

-- Test: Zero out balance, then delete:
UPDATE trigger_demo_accounts SET balance = 0 WHERE account_no = 'ACC-001'$$
DELETE FROM trigger_demo_accounts WHERE account_no = 'ACC-001'$$
SELECT * FROM trigger_audit_log$$

DELIMITER ;

-- ─────────────────────────────────────────────────────────────────────────
-- 15.7 SHOW and MANAGE triggers
-- ─────────────────────────────────────────────────────────────────────────

-- See all triggers in the database:
SHOW TRIGGERS FROM bank_fraud_db;

-- See triggers on a specific table:
SHOW TRIGGERS FROM bank_fraud_db LIKE 'trigger_demo_accounts';

-- See trigger definition:
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'bank_fraud_db'
ORDER BY event_object_table, action_timing;

-- ─────────────────────────────────────────────────────────────────────────
-- 15.8 CLEANUP
-- ─────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_before_insert_account;
DROP TRIGGER IF EXISTS trg_after_insert_account;
DROP TRIGGER IF EXISTS trg_before_update_account;
DROP TRIGGER IF EXISTS trg_after_update_account;
DROP TRIGGER IF EXISTS trg_before_delete_account;
DROP TRIGGER IF EXISTS trg_after_delete_account;

DROP TABLE IF EXISTS trigger_demo_accounts;
DROP TABLE IF EXISTS trigger_audit_log;
