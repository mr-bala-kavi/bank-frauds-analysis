-- ═══════════════════════════════════════════════════════════════════════════
-- 🚨 REAL-TIME FRAUD DETECTION QUERIES — bank_fraud_db
-- Run these in MySQL Workbench to find actual fraud in your data
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 1: STRUCTURING / SMURFING
-- Customers splitting amounts just below ₹2,00,000 to avoid reporting
-- Real-world signal: 3+ transactions between ₹1.8L–₹2L on same day
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    t.account_id,
    a.account_number,
    c.full_name,
    c.risk_category,
    t.transaction_date,
    COUNT(*)            AS txn_count,
    SUM(t.amount)       AS total_structured_amount,
    MIN(t.amount)       AS min_txn,
    MAX(t.amount)       AS max_txn,
    GROUP_CONCAT(t.transaction_mode)  AS modes_used
FROM transactions t
JOIN accounts  a ON a.account_id  = t.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.amount BETWEEN 180000 AND 199999
  AND t.transaction_type = 'debit'
GROUP BY t.account_id, a.account_number, c.full_name, c.risk_category, t.transaction_date
HAVING COUNT(*) >= 3
ORDER BY txn_count DESC, total_structured_amount DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 2: VELOCITY FRAUD — Rapid fire transactions (account draining)
-- 10+ transactions in any 1-hour window = account takeover signal
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    t1.account_id,
    a.account_number,
    c.full_name,
    t1.transaction_date,
    t1.transaction_time                 AS window_start,
    COUNT(*)                            AS txns_in_1hr,
    SUM(t2.amount)                      AS total_drained,
    GROUP_CONCAT(DISTINCT t2.transaction_mode) AS modes
FROM transactions t1
JOIN transactions t2
    ON  t2.account_id       = t1.account_id
    AND t2.transaction_date = t1.transaction_date
    AND TIMESTAMPDIFF(MINUTE,
            TIMESTAMP(t1.transaction_date, t1.transaction_time),
            TIMESTAMP(t2.transaction_date, t2.transaction_time)
        ) BETWEEN 0 AND 60
JOIN accounts  a ON a.account_id  = t1.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE t1.transaction_type = 'debit'
GROUP BY t1.account_id, a.account_number, c.full_name,
         t1.transaction_date, t1.transaction_time
HAVING COUNT(*) >= 10
ORDER BY txns_in_1hr DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 3: DORMANT ACCOUNT REVIVAL
-- Account had NO activity for 365+ days then got a large credit
-- Classic money mule / account takeover pattern
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    a.account_id,
    a.account_number,
    c.full_name,
    c.risk_category,
    a.last_transaction_date             AS last_active_date,
    t.transaction_date                  AS revival_date,
    DATEDIFF(t.transaction_date, a.last_transaction_date) AS days_dormant,
    t.amount                            AS revival_amount,
    t.transaction_mode,
    t.transaction_type,
    t.channel
FROM accounts a
JOIN customers    c ON c.customer_id = a.customer_id
JOIN transactions t ON t.account_id  = a.account_id
WHERE t.transaction_type = 'credit'
  AND t.amount > 100000
  AND a.last_transaction_date < t.transaction_date - INTERVAL 365 DAY
ORDER BY days_dormant DESC, revival_amount DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 4: CARD CLONING — Same card in 2 countries within 4 hours
-- Physically impossible travel = cloned card being used simultaneously
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    t1.account_id,
    a.account_number,
    c.full_name,
    t1.transaction_date,
    t1.location_country                 AS country_1,
    t1.transaction_time                 AS time_in_country1,
    t1.amount                           AS amount_1,
    t2.location_country                 AS country_2,
    t2.transaction_time                 AS time_in_country2,
    t2.amount                           AS amount_2,
    ABS(TIMESTAMPDIFF(MINUTE,
        TIMESTAMP(t1.transaction_date, t1.transaction_time),
        TIMESTAMP(t2.transaction_date, t2.transaction_time)
    ))                                  AS gap_minutes
FROM transactions t1
JOIN transactions t2
    ON  t2.account_id        = t1.account_id
    AND t2.transaction_id   != t1.transaction_id
    AND t2.transaction_date  = t1.transaction_date
    AND t2.location_country != t1.location_country
    AND ABS(TIMESTAMPDIFF(MINUTE,
            TIMESTAMP(t1.transaction_date, t1.transaction_time),
            TIMESTAMP(t2.transaction_date, t2.transaction_time)
        )) <= 240
JOIN accounts  a ON a.account_id  = t1.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE t1.transaction_mode IN ('CARD_PURCHASE','ATM_CASH')
ORDER BY gap_minutes ASC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 5: GEO ANOMALY — Login from India, transaction in UAE/abroad
-- "Impossible travel" — login city and transaction country don't match
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    l.customer_id,
    c.full_name,
    c.risk_category,
    l.login_datetime,
    l.location_city                     AS login_city,
    l.location_country                  AS login_country,
    t.transaction_date,
    t.transaction_time,
    t.location_city                     AS txn_city,
    t.location_country                  AS txn_country,
    t.amount,
    TIMESTAMPDIFF(MINUTE, l.login_datetime,
        TIMESTAMP(t.transaction_date, t.transaction_time)) AS gap_minutes
FROM login_audit l
JOIN customers    c ON c.customer_id = l.customer_id
JOIN accounts     a ON a.customer_id = l.customer_id
JOIN transactions t ON t.account_id  = a.account_id
WHERE l.login_status   = 'success'
  AND l.location_country != t.location_country
  AND t.transaction_date  = DATE(l.login_datetime)
  AND TIMESTAMPDIFF(MINUTE, l.login_datetime,
        TIMESTAMP(t.transaction_date, t.transaction_time)
      ) BETWEEN 1 AND 30          -- within 30 minutes of login
  AND t.amount > 10000
ORDER BY gap_minutes ASC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 6: SALARY DIVERSION
-- Salary credited → 90%+ transferred out to unknown beneficiary in <2 hours
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    sal.account_id,
    a.account_number,
    c.full_name,
    sal.transaction_date,
    sal.transaction_time                AS salary_time,
    sal.amount                          AS salary_amount,
    div.transaction_time                AS divert_time,
    div.amount                          AS diverted_amount,
    ROUND(div.amount / sal.amount * 100, 1) AS pct_diverted,
    div.beneficiary_name,
    div.transaction_mode                AS mode_used,
    TIMESTAMPDIFF(MINUTE,
        TIMESTAMP(sal.transaction_date, sal.transaction_time),
        TIMESTAMP(div.transaction_date, div.transaction_time)
    )                                   AS minutes_gap
FROM transactions sal
JOIN transactions div
    ON  div.account_id      = sal.account_id
    AND div.transaction_date = sal.transaction_date
    AND div.transaction_type = 'debit'
    AND div.amount          >= sal.amount * 0.90
    AND TIMESTAMPDIFF(MINUTE,
            TIMESTAMP(sal.transaction_date, sal.transaction_time),
            TIMESTAMP(div.transaction_date, div.transaction_time)
        ) BETWEEN 1 AND 120
JOIN accounts  a ON a.account_id  = sal.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE sal.transaction_mode = 'SALARY_CREDIT'
ORDER BY minutes_gap ASC, pct_diverted DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 7: MULE ACCOUNTS — Receiving from 20+ unique senders per month
-- Money aggregator pattern: collects small amounts, forwards as bulk
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    t.account_id,
    a.account_number,
    c.full_name,
    c.risk_category,
    YEAR(t.transaction_date)  AS yr,
    MONTH(t.transaction_date) AS mo,
    COUNT(DISTINCT t.beneficiary_name)   AS unique_senders,
    COUNT(*)                             AS total_credits,
    SUM(t.amount)                        AS total_received,
    MAX(t.amount)                        AS largest_single_credit
FROM transactions t
JOIN accounts  a ON a.account_id  = t.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.transaction_type = 'credit'
GROUP BY t.account_id, a.account_number, c.full_name,
         c.risk_category, yr, mo
HAVING COUNT(DISTINCT t.beneficiary_name) >= 20
ORDER BY unique_senders DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 8: ROUND TRIP TRANSACTIONS (A → B → C → A within 72 hours)
-- Money sent out and returned within 5% of original amount
-- Used to create fake transaction history / layer funds
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    out_t.account_id                    AS origin_account,
    a.account_number,
    c.full_name,
    out_t.amount                        AS sent_amount,
    in_t.amount                         AS returned_amount,
    out_t.transaction_date              AS sent_date,
    in_t.transaction_date               AS return_date,
    DATEDIFF(in_t.transaction_date, out_t.transaction_date) AS days_gap,
    out_t.transaction_mode              AS send_mode,
    in_t.transaction_mode               AS return_mode
FROM transactions out_t
JOIN transactions in_t
    ON  in_t.account_id       = out_t.account_id
    AND in_t.transaction_type = 'credit'
    AND in_t.transaction_date BETWEEN out_t.transaction_date
                              AND out_t.transaction_date + INTERVAL 72 HOUR
    AND ABS(in_t.amount - out_t.amount) / out_t.amount < 0.05  -- within 5%
    AND in_t.transaction_id  != out_t.transaction_id
JOIN accounts  a ON a.account_id  = out_t.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE out_t.transaction_type = 'debit'
  AND out_t.amount > 50000
ORDER BY days_gap ASC, sent_amount DESC
LIMIT 50;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 9: AFTER-HOURS LARGE TRANSACTIONS
-- Big money moving between midnight and 4 AM is a major red flag
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    t.transaction_id,
    t.transaction_date,
    t.transaction_time,
    c.full_name,
    c.risk_category,
    a.account_number,
    a.account_status,
    t.transaction_type,
    t.transaction_mode,
    t.amount,
    t.location_city,
    t.location_country,
    t.channel,
    t.ip_address
FROM transactions t
JOIN accounts  a ON a.account_id  = t.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.transaction_time BETWEEN '00:00:00' AND '04:00:00'
  AND t.amount > 50000
ORDER BY t.amount DESC, t.transaction_time;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 10: ROUND AMOUNT PATTERN
-- Exact multiples of ₹10,000 repeated 3+ times = likely money laundering
-- Legitimate transactions almost never land on exact round numbers
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    t.account_id,
    a.account_number,
    c.full_name,
    c.risk_category,
    COUNT(*)                AS round_txn_count,
    SUM(t.amount)           AS total_round_amount,
    GROUP_CONCAT(DISTINCT CAST(t.amount AS CHAR) ORDER BY t.amount) AS amounts_used,
    MIN(t.transaction_date) AS first_on,
    MAX(t.transaction_date) AS last_on
FROM transactions t
JOIN accounts  a ON a.account_id  = t.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.amount >= 10000
  AND t.amount MOD 10000 = 0
  AND t.transaction_type = 'debit'
GROUP BY t.account_id, a.account_number, c.full_name, c.risk_category
HAVING COUNT(*) >= 3
ORDER BY round_txn_count DESC, total_round_amount DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 11: MULTIPLE FAILED LOGINS → Successful login (brute force)
-- 3+ failed logins followed by success = compromised account
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    f.customer_id,
    c.full_name,
    c.risk_category,
    COUNT(f.login_id)        AS failed_attempts,
    MIN(f.login_datetime)    AS first_fail,
    MAX(f.login_datetime)    AS last_fail,
    s.login_datetime         AS successful_login,
    s.ip_address             AS success_ip,
    f.ip_address             AS fail_ip,
    TIMESTAMPDIFF(MINUTE, MAX(f.login_datetime), s.login_datetime) AS mins_to_success
FROM login_audit f
JOIN login_audit s
    ON  s.customer_id    = f.customer_id
    AND s.login_status   = 'success'
    AND s.login_datetime > f.login_datetime
    AND s.login_datetime < f.login_datetime + INTERVAL 1 HOUR
JOIN customers c ON c.customer_id = f.customer_id
WHERE f.login_status = 'failed'
GROUP BY f.customer_id, c.full_name, c.risk_category,
         s.login_datetime, s.ip_address, f.ip_address
HAVING COUNT(f.login_id) >= 3
ORDER BY failed_attempts DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 12: PEP (Politically Exposed Persons) LARGE TRANSACTIONS
-- Any transaction >₹50,000 by a PEP customer requires enhanced due diligence
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    c.customer_id,
    c.full_name,
    c.nationality,
    c.occupation,
    c.risk_category,
    c.kyc_status,
    a.account_number,
    t.transaction_date,
    t.amount,
    t.transaction_type,
    t.transaction_mode,
    t.beneficiary_name,
    t.beneficiary_bank,
    t.location_country,
    t.channel
FROM customers c
JOIN accounts     a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id  = a.account_id
WHERE c.pep_flag = TRUE
  AND t.amount > 50000
ORDER BY t.amount DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 13: STATISTICAL ANOMALY — Z-Score > 3 (outlier transactions)
-- Transactions more than 3 standard deviations above an account's normal
-- ─────────────────────────────────────────────────────────────────────────

WITH account_stats AS (
    SELECT
        account_id,
        AVG(amount)    AS mean_amount,
        STDDEV(amount) AS std_amount
    FROM transactions
    GROUP BY account_id
)
SELECT
    t.transaction_id,
    t.account_id,
    a.account_number,
    c.full_name,
    c.risk_category,
    t.amount                            AS txn_amount,
    ROUND(s.mean_amount, 2)             AS account_avg,
    ROUND(s.std_amount, 2)              AS account_stddev,
    ROUND((t.amount - s.mean_amount) / NULLIF(s.std_amount, 0), 2) AS z_score,
    t.transaction_date,
    t.transaction_mode,
    t.location_country
FROM transactions t
JOIN account_stats s ON s.account_id = t.account_id
JOIN accounts      a ON a.account_id = t.account_id
JOIN customers     c ON c.customer_id = a.customer_id
WHERE (t.amount - s.mean_amount) / NULLIF(s.std_amount, 0) > 3
ORDER BY z_score DESC
LIMIT 50;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 14: SUSPICIOUS LOAN — High loan + minimal banking history
-- CIBIL < 650 + Loan-to-Income > 5x + First transaction < 6 months ago
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    l.loan_id,
    c.full_name,
    c.nationality,
    c.occupation,
    c.annual_income,
    l.loan_type,
    l.principal_amount,
    ROUND(l.principal_amount / NULLIF(c.annual_income, 0), 2)  AS loan_to_income_ratio,
    l.cibil_score_at_approval,
    l.interest_rate,
    l.loan_status,
    l.loan_start_date,
    MIN(t.transaction_date)  AS first_transaction_date,
    DATEDIFF(l.loan_start_date, MIN(t.transaction_date)) AS banking_history_days
FROM loans l
JOIN customers    c ON c.customer_id = l.customer_id
JOIN accounts     a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id  = a.account_id
WHERE l.cibil_score_at_approval < 650
  AND l.principal_amount > c.annual_income * 3
GROUP BY l.loan_id, c.full_name, c.nationality, c.occupation,
         c.annual_income, l.loan_type, l.principal_amount,
         l.cibil_score_at_approval, l.interest_rate,
         l.loan_status, l.loan_start_date
HAVING banking_history_days < 180    -- less than 6 months of history
ORDER BY loan_to_income_ratio DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 15: NEW BENEFICIARY + INSTANT LARGE TRANSFER
-- First transfer to a new beneficiary exceeding ₹5 lakhs within 0–3 days
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    t.account_id,
    a.account_number,
    c.full_name,
    c.risk_category,
    t.beneficiary_name,
    t.beneficiary_bank,
    t.amount,
    t.transaction_date,
    t.transaction_mode,
    b.added_date              AS beneficiary_added_date,
    DATEDIFF(t.transaction_date, b.added_date) AS days_since_added
FROM transactions t
JOIN accounts      a ON a.account_id   = t.account_id
JOIN customers     c ON c.customer_id  = a.customer_id
JOIN beneficiaries b
    ON  b.customer_id = c.customer_id
    AND b.beneficiary_name = t.beneficiary_name
WHERE t.transaction_type = 'debit'
  AND t.amount > 500000
  AND DATEDIFF(t.transaction_date, b.added_date) BETWEEN 0 AND 3
ORDER BY t.amount DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 16: AML WATCHLIST HITS
-- Customers flagged by Anti-Money Laundering screening
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    c.customer_id,
    c.full_name,
    c.nationality,
    c.occupation,
    c.annual_income,
    c.pep_flag,
    c.risk_category,
    c.kyc_status,
    am.screening_date,
    am.screening_type,
    am.risk_score,
    am.match_details,
    am.action_taken,
    am.analyst_notes
FROM aml_screening am
JOIN customers c ON c.customer_id = am.customer_id
WHERE am.watchlist_matched = TRUE
   OR am.action_taken IN ('escalated', 'blocked', 'reported_fiu')
   OR am.risk_score > 70
ORDER BY am.risk_score DESC, am.screening_date DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 17: OPEN FRAUD CASES AGING > 30 DAYS (Overdue Investigations)
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    fc.case_id,
    c.full_name,
    a.account_number,
    fc.case_type,
    fc.case_status,
    fc.fraud_amount,
    fc.reported_date,
    fc.reported_by,
    DATEDIFF(CURDATE(), fc.reported_date) AS days_open,
    fc.investigation_notes
FROM fraud_cases fc
JOIN customers c ON c.customer_id = fc.customer_id
JOIN accounts  a ON a.account_id  = fc.account_id
WHERE fc.case_status IN ('reported', 'investigating')
  AND DATEDIFF(CURDATE(), fc.reported_date) > 30
ORDER BY days_open DESC, fc.fraud_amount DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 📊 BLOCK 18: MORNING DASHBOARD — All open critical alerts (run daily)
-- ─────────────────────────────────────────────────────────────────────────

SELECT
    al.alert_id,
    al.alert_type,
    al.alert_severity,
    c.full_name,
    c.risk_category,
    a.account_number,
    a.account_status,
    al.alert_message,
    al.alert_date,
    al.alert_time,
    al.status,
    al.assigned_to_analyst
FROM alerts al
JOIN customers c ON c.customer_id = al.customer_id
JOIN accounts  a ON a.account_id  = al.account_id
WHERE al.alert_severity IN ('critical', 'high')
  AND al.status IN ('open', 'under_review')
ORDER BY
    FIELD(al.alert_severity, 'critical', 'high'),
    al.alert_date DESC,
    al.alert_time DESC;


-- ─────────────────────────────────────────────────────────────────────────
-- 📊 BLOCK 19: OVERALL FRAUD DASHBOARD — Summary metrics
-- ─────────────────────────────────────────────────────────────────────────

SELECT 'Total Transactions'              AS metric, COUNT(*)        AS value FROM transactions
UNION ALL
SELECT 'Fraud Flagged Transactions',       SUM(fraud_flag)          FROM transactions
UNION ALL
SELECT 'Suspicious Transactions',          SUM(is_suspicious)       FROM transactions
UNION ALL
SELECT 'Open Alerts',                      COUNT(*)                 FROM alerts WHERE status = 'open'
UNION ALL
SELECT 'Critical Open Alerts',             COUNT(*)                 FROM alerts WHERE status = 'open' AND alert_severity = 'critical'
UNION ALL
SELECT 'Active Fraud Cases',               COUNT(*)                 FROM fraud_cases WHERE case_status IN ('reported','investigating')
UNION ALL
SELECT 'Confirmed Fraud Cases',            COUNT(*)                 FROM fraud_cases WHERE case_status = 'confirmed'
UNION ALL
SELECT 'Total Fraud Amount (M)',           ROUND(SUM(fraud_amount)/1000000, 2) FROM fraud_cases
UNION ALL
SELECT 'AML Watchlist Hits',               COUNT(*)                 FROM aml_screening WHERE watchlist_matched = TRUE
UNION ALL
SELECT 'High/Very High Risk Customers',    COUNT(*)                 FROM customers WHERE risk_category IN ('high','very_high')
UNION ALL
SELECT 'Expired KYC Customers',            COUNT(*)                 FROM customers WHERE kyc_status = 'expired'
UNION ALL
SELECT 'Frozen Accounts',                  COUNT(*)                 FROM accounts  WHERE account_status = 'frozen'
UNION ALL
SELECT 'Under Investigation Accounts',     COUNT(*)                 FROM accounts  WHERE account_status = 'under_investigation';


-- ─────────────────────────────────────────────────────────────────────────
-- 🔴 BLOCK 20: RECURSIVE MONEY TRAIL — Follow the cash (up to 4 hops)
-- Trace how money moves: A → B → C → D using fraud_type = 'mule_account'
-- ─────────────────────────────────────────────────────────────────────────

WITH RECURSIVE money_trail AS (

    -- STEP 1: Start from mule account outgoing transactions
    SELECT
        transaction_id,
        account_id,
        beneficiary_account_id,
        amount,
        transaction_date,
        1                                       AS hop,
        CAST(transaction_id AS CHAR(500))       AS trail
    FROM transactions
    WHERE fraud_type = 'mule_account'
      AND transaction_type = 'debit'
    LIMIT 5

    UNION ALL

    -- STEP 2: Follow each hop
    SELECT
        t.transaction_id,
        t.account_id,
        t.beneficiary_account_id,
        t.amount,
        t.transaction_date,
        mt.hop + 1,
        CONCAT(mt.trail, ' → ', t.transaction_id)
    FROM transactions t
    JOIN money_trail mt
        ON  t.account_id = mt.beneficiary_account_id
        AND t.transaction_date >= mt.transaction_date
    WHERE mt.hop < 4

)
SELECT
    hop,
    account_id,
    beneficiary_account_id,
    ROUND(amount, 2)  AS amount,
    transaction_date,
    trail
FROM money_trail
ORDER BY trail, hop;

-- ═══════════════════════════════════════════════════════════════════════════
-- END OF FRAUD DETECTION QUERIES
-- ═══════════════════════════════════════════════════════════════════════════
