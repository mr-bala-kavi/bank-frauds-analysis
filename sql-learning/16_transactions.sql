-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 16: TRANSACTIONS
-- Commands: COMMIT, ROLLBACK, SAVEPOINT
-- A transaction is a group of SQL statements that must ALL succeed or ALL fail.
-- Bank operations are the PERFECT real-world example.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- SETUP: Create demo tables for transaction exercises
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS txn_demo_accounts (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    balance      DECIMAL(15,2) NOT NULL,
    CONSTRAINT chk_balance_non_negative CHECK (balance >= 0)
);

INSERT INTO txn_demo_accounts (account_name, balance) VALUES
    ('Karthik — Savings', 100000.00),
    ('Priya   — Savings',  50000.00),
    ('Fraud Reserve',       10000.00);

SELECT * FROM txn_demo_accounts;

-- ─────────────────────────────────────────────────────────────────────────
-- 16.1 ACID PROPERTIES (What transactions guarantee)
-- ─────────────────────────────────────────────────────────────────────────
-- A — Atomicity   : All steps succeed OR all are rolled back (no partial changes)
-- C — Consistency : Database always stays in a valid state
-- I — Isolation   : Concurrent transactions don't interfere with each other
-- D — Durability  : Committed changes survive crashes, power failures, etc.

-- ─────────────────────────────────────────────────────────────────────────
-- 16.2 START TRANSACTION / COMMIT — Group of statements that succeed together
-- ─────────────────────────────────────────────────────────────────────────

-- Transfer ₹20,000 from Karthik to Priya:
START TRANSACTION;

    UPDATE txn_demo_accounts
    SET balance = balance - 20000
    WHERE account_name = 'Karthik — Savings';

    UPDATE txn_demo_accounts
    SET balance = balance + 20000
    WHERE account_name = 'Priya   — Savings';

    -- Verify before committing:
    SELECT * FROM txn_demo_accounts;

COMMIT;  -- Make changes permanent

-- After COMMIT, both updates are saved permanently.
SELECT * FROM txn_demo_accounts;

-- ─────────────────────────────────────────────────────────────────────────
-- 16.3 ROLLBACK — Undo ALL changes since START TRANSACTION
-- ─────────────────────────────────────────────────────────────────────────

-- Attempt a transfer that should fail (insufficient funds):
START TRANSACTION;

    UPDATE txn_demo_accounts
    SET balance = balance - 200000   -- ₹2 lakhs (more than Karthik has!)
    WHERE account_name = 'Karthik — Savings';

    UPDATE txn_demo_accounts
    SET balance = balance + 200000
    WHERE account_name = 'Priya   — Savings';

    -- Check: Karthik's balance would go negative — invalid!
    SELECT * FROM txn_demo_accounts;

ROLLBACK;  -- Undo both updates as if nothing happened

-- After ROLLBACK, both accounts are unchanged:
SELECT * FROM txn_demo_accounts;

-- ─────────────────────────────────────────────────────────────────────────
-- 16.4 SAVEPOINT — Create a checkpoint within a transaction
-- ─────────────────────────────────────────────────────────────────────────
-- Lets you ROLLBACK to a specific point (not all the way to the start)

START TRANSACTION;

    -- Step 1: Debit Karthik:
    UPDATE txn_demo_accounts SET balance = balance - 10000
    WHERE account_name = 'Karthik — Savings';

    SAVEPOINT after_debit;   -- ← savepoint after first step

    -- Step 2: Credit Priya:
    UPDATE txn_demo_accounts SET balance = balance + 10000
    WHERE account_name = 'Priya   — Savings';

    SAVEPOINT after_credit;  -- ← savepoint after second step

    -- Step 3: Something goes wrong — rollback to after_debit:
    ROLLBACK TO SAVEPOINT after_debit;
    -- Note: Step 2 (credit to Priya) is undone, Step 1 (debit from Karthik) is kept

    -- Check current state:
    SELECT * FROM txn_demo_accounts;

    -- Decide to rollback everything:
ROLLBACK;   -- undo everything including Step 1

SELECT * FROM txn_demo_accounts;  -- back to original

-- Release a savepoint (optional — they are released automatically on COMMIT):
-- RELEASE SAVEPOINT after_debit;

-- ─────────────────────────────────────────────────────────────────────────
-- 16.5 AUTOCOMMIT — MySQL auto-commits each statement by default
-- ─────────────────────────────────────────────────────────────────────────

-- Check current autocommit mode:
SELECT @@autocommit;         -- 1 = ON (default)

-- Turn OFF autocommit (every statement needs explicit COMMIT/ROLLBACK):
SET autocommit = 0;

UPDATE txn_demo_accounts SET balance = balance - 5000
WHERE account_name = 'Karthik — Savings';

ROLLBACK;   -- undo (because autocommit is off)

SELECT * FROM txn_demo_accounts;   -- unchanged

-- Turn autocommit back ON:
SET autocommit = 1;

-- ─────────────────────────────────────────────────────────────────────────
-- 16.6 REAL WORLD — Money transfer procedure with transaction
-- ─────────────────────────────────────────────────────────────────────────

DELIMITER $$

CREATE PROCEDURE sp_safe_transfer(
    IN p_from_id  INT,
    IN p_to_id    INT,
    IN p_amount   DECIMAL(15,2)
)
BEGIN
    DECLARE v_from_balance DECIMAL(15,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Transfer failed — rolled back.' AS result;
    END;

    START TRANSACTION;

        -- Check sender has enough funds:
        SELECT balance INTO v_from_balance
        FROM txn_demo_accounts
        WHERE id = p_from_id
        FOR UPDATE;    -- lock the row during this transaction

        IF v_from_balance < p_amount THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Insufficient funds.';
        END IF;

        -- Debit sender:
        UPDATE txn_demo_accounts
        SET balance = balance - p_amount
        WHERE id = p_from_id;

        -- Credit receiver:
        UPDATE txn_demo_accounts
        SET balance = balance + p_amount
        WHERE id = p_to_id;

    COMMIT;
    SELECT CONCAT('Transferred ₹', p_amount, ' successfully.') AS result;
END$$

DELIMITER ;

-- Test the safe transfer:
SELECT * FROM txn_demo_accounts;
CALL sp_safe_transfer(1, 2, 15000);         -- valid: Karthik → Priya ₹15,000
SELECT * FROM txn_demo_accounts;

-- CALL sp_safe_transfer(2, 1, 999999);     -- will fail: insufficient funds → rollback

-- ─────────────────────────────────────────────────────────────────────────
-- 16.7 CLEANUP
-- ─────────────────────────────────────────────────────────────────────────
DROP PROCEDURE IF EXISTS sp_safe_transfer;
DROP TABLE IF EXISTS txn_demo_accounts;
