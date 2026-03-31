-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 19: WINDOW FUNCTIONS
-- Perform calculations across rows RELATED to the current row
-- without collapsing rows like GROUP BY does.
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- SYNTAX: function() OVER (PARTITION BY col ORDER BY col)
-- PARTITION BY → like GROUP BY — resets the window for each group
-- ORDER BY     → defines the row sequence within the partition
-- ─────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────
-- 19.1 ROW_NUMBER() — Sequential row number within each partition
-- ─────────────────────────────────────────────────────────────────────────

-- Number each transaction per account (in date order):
SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount,
    ROW_NUMBER() OVER (
        PARTITION BY account_id
        ORDER BY transaction_date, transaction_id
    ) AS txn_sequence
FROM transactions
LIMIT 20;

-- Find the 1st transaction ever for each account:
SELECT *
FROM (
    SELECT
        transaction_id,
        account_id,
        transaction_date,
        amount,
        ROW_NUMBER() OVER (
            PARTITION BY account_id ORDER BY transaction_date
        ) AS rn
    FROM transactions
) AS ranked
WHERE rn = 1
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 19.2 RANK() — Rank with GAPS for ties
-- DENSE_RANK() — Rank WITHOUT gaps for ties
-- ─────────────────────────────────────────────────────────────────────────

-- Rank customers by income (ties get same rank, next rank is skipped):
SELECT
    full_name,
    annual_income,
    RANK()       OVER (ORDER BY annual_income DESC) AS income_rank,
    DENSE_RANK() OVER (ORDER BY annual_income DESC) AS income_dense_rank
FROM customers
LIMIT 20;

-- Rank accounts by balance within each account type:
SELECT
    account_number,
    account_type,
    current_balance,
    RANK() OVER (
        PARTITION BY account_type
        ORDER BY current_balance DESC
    ) AS balance_rank_in_type
FROM accounts
ORDER BY account_type, balance_rank_in_type
LIMIT 20;

-- Top 3 richest accounts per type:
SELECT *
FROM (
    SELECT
        account_number,
        account_type,
        current_balance,
        DENSE_RANK() OVER (
            PARTITION BY account_type ORDER BY current_balance DESC
        ) AS rnk
    FROM accounts
) t
WHERE rnk <= 3
ORDER BY account_type, rnk;

-- ─────────────────────────────────────────────────────────────────────────
-- 19.3 SUM() OVER — Running totals (cumulative sum)
-- ─────────────────────────────────────────────────────────────────────────

-- Running total of transactions per account over time:
SELECT
    account_id,
    transaction_date,
    amount,
    transaction_type,
    SUM(amount) OVER (
        PARTITION BY account_id
        ORDER BY transaction_date, transaction_id
    ) AS running_total
FROM transactions
ORDER BY account_id, transaction_date
LIMIT 20;

-- Cumulative fraud amount over time:
SELECT
    reported_date,
    fraud_amount,
    SUM(fraud_amount) OVER (
        ORDER BY reported_date
    ) AS cumulative_fraud_total
FROM fraud_cases
ORDER BY reported_date
LIMIT 20;

-- ─────────────────────────────────────────────────────────────────────────
-- 19.4 AVG() OVER — Moving/rolling average
-- ─────────────────────────────────────────────────────────────────────────

-- 3-transaction rolling average for each account:
SELECT
    account_id,
    transaction_date,
    amount,
    ROUND(AVG(amount) OVER (
        PARTITION BY account_id
        ORDER BY transaction_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW   -- 3-row window
    ), 2) AS rolling_avg_3_txns
FROM transactions
ORDER BY account_id, transaction_date
LIMIT 20;

-- Running average of daily transaction amounts:
SELECT
    transaction_date,
    AVG(amount) AS daily_avg,
    ROUND(AVG(AVG(amount)) OVER (
        ORDER BY transaction_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW   -- 7-day rolling avg
    ), 2) AS rolling_7day_avg
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date
LIMIT 30;

-- ─────────────────────────────────────────────────────────────────────────
-- 19.5 LAG() — Access the PREVIOUS row's value
-- ─────────────────────────────────────────────────────────────────────────

-- Previous transaction amount for each account (detect spikes):
SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount,
    LAG(amount, 1) OVER (
        PARTITION BY account_id
        ORDER BY transaction_date, transaction_id
    ) AS prev_amount,
    amount - LAG(amount, 1) OVER (
        PARTITION BY account_id
        ORDER BY transaction_date, transaction_id
    ) AS change_from_prev
FROM transactions
LIMIT 20;

-- Find transactions that are 10x larger than the previous one (anomaly):
SELECT *
FROM (
    SELECT
        transaction_id,
        account_id,
        amount,
        LAG(amount, 1) OVER (
            PARTITION BY account_id ORDER BY transaction_date
        ) AS prev_amount
    FROM transactions
) t
WHERE prev_amount > 0
  AND amount / prev_amount >= 10    -- 10x jump!
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────
-- 19.6 LEAD() — Access the NEXT row's value
-- ─────────────────────────────────────────────────────────────────────────

-- Time gap between consecutive logins for each customer:
SELECT
    customer_id,
    login_datetime,
    login_status,
    LEAD(login_datetime, 1) OVER (
        PARTITION BY customer_id
        ORDER BY login_datetime
    ) AS next_login,
    TIMESTAMPDIFF(MINUTE,
        login_datetime,
        LEAD(login_datetime, 1) OVER (
            PARTITION BY customer_id ORDER BY login_datetime
        )
    ) AS mins_to_next_login
FROM login_audit
LIMIT 20;

-- ─────────────────────────────────────────────────────────────────────────
-- 19.7 FIRST_VALUE() and LAST_VALUE()
-- ─────────────────────────────────────────────────────────────────────────

-- First and last transaction amount per account:
SELECT
    account_id,
    transaction_date,
    amount,
    FIRST_VALUE(amount) OVER (
        PARTITION BY account_id ORDER BY transaction_date
    ) AS first_txn_amount,
    LAST_VALUE(amount) OVER (
        PARTITION BY account_id ORDER BY transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_txn_amount
FROM transactions
LIMIT 20;

-- ─────────────────────────────────────────────────────────────────────────
-- 19.8 NTILE() — Divide rows into N buckets/percentiles
-- ─────────────────────────────────────────────────────────────────────────

-- Segment customers into income quartiles (4 equal groups):
SELECT
    full_name,
    annual_income,
    NTILE(4) OVER (ORDER BY annual_income) AS income_quartile
FROM customers
ORDER BY income_quartile, annual_income
LIMIT 20;
-- Quartile 1 = bottom 25%, Quartile 4 = top 25%

-- Segment accounts into 10 deciles by balance:
SELECT
    account_number,
    current_balance,
    NTILE(10) OVER (ORDER BY current_balance) AS balance_decile
FROM accounts
LIMIT 20;

-- ─────────────────────────────────────────────────────────────────────────
-- 19.9 PERCENT_RANK() and CUME_DIST()
-- ─────────────────────────────────────────────────────────────────────────

-- What percentile is each account's balance?
SELECT
    account_number,
    current_balance,
    ROUND(PERCENT_RANK() OVER (ORDER BY current_balance) * 100, 1) AS percentile,
    ROUND(CUME_DIST()    OVER (ORDER BY current_balance) * 100, 1) AS cumulative_pct
FROM accounts
ORDER BY current_balance DESC
LIMIT 15;

-- ─────────────────────────────────────────────────────────────────────────
-- 19.10 Real fraud detection using window functions
-- ─────────────────────────────────────────────────────────────────────────

-- Z-score: find transactions more than 2 std deviations above account average:
SELECT *
FROM (
    SELECT
        t.transaction_id,
        t.account_id,
        t.amount,
        AVG(t.amount) OVER (PARTITION BY t.account_id) AS acct_avg,
        STDDEV(t.amount) OVER (PARTITION BY t.account_id) AS acct_std,
        ROUND(
            (t.amount - AVG(t.amount) OVER (PARTITION BY t.account_id))
            / NULLIF(STDDEV(t.amount) OVER (PARTITION BY t.account_id), 0),
            2
        ) AS z_score
    FROM transactions t
) zs
WHERE z_score > 2
ORDER BY z_score DESC
LIMIT 15;
