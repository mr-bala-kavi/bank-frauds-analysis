-- ═══════════════════════════════════════════════════════════════════════════
-- BANK FRAUD ANALYST TRAINING DATABASE
-- LEVEL 7 — VERY EXPERT
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  LEVEL 7 — VERY EXPERT & INVESTIGATOR                               ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Q76. Gaps and Islands: Find customers with >= 3 consecutive days of failed logins
WITH login_runs AS (
    SELECT customer_id, DATE(login_datetime) as l_date,
           DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY DATE(login_datetime)) -
           DENSE_RANK() OVER (PARTITION BY customer_id, login_status ORDER BY DATE(login_datetime)) AS grp
    FROM login_audit
    WHERE login_status = 'failed'
)
SELECT customer_id, MIN(l_date) as start_date, MAX(l_date) as end_date, COUNT(*) as days_streak
FROM login_runs
GROUP BY customer_id, grp
HAVING COUNT(*) >= 3
ORDER BY days_streak DESC;


-- Q77. JSON Extraction: Extract mismatch reason from AML JSON match details
SELECT customer_id, action_taken,
       JSON_UNQUOTE(JSON_EXTRACT(match_details, '$.reason')) AS mismatch_reason,
       JSON_UNQUOTE(JSON_EXTRACT(match_details, '$.score_confidence')) AS confidence
FROM aml_screening
WHERE watchlist_matched = TRUE
  AND match_details IS NOT NULL
LIMIT 20;


-- Q78. Recursive CTE: Full money trail depth (Up to 10 hops)
WITH RECURSIVE deep_trail AS (
    SELECT transaction_id, account_id, beneficiary_account_id, amount, transaction_date, 1 AS depth
    FROM transactions WHERE amount > 1000000 AND transaction_type = 'debit' LIMIT 1
    
    UNION ALL

    SELECT t.transaction_id, t.account_id, t.beneficiary_account_id, t.amount, t.transaction_date, dt.depth + 1
    FROM transactions t
    JOIN deep_trail dt ON t.account_id = dt.beneficiary_account_id AND t.transaction_date >= dt.transaction_date
    WHERE dt.depth < 10 AND dt.amount * 0.90 <= t.amount
)
SELECT * FROM deep_trail ORDER BY depth;


-- Q79. Median Transaction Amount per Risk Category (MySQL 8.0 Windowed Median)
WITH RankedTxns AS (
    SELECT c.risk_category, t.amount,
           ROW_NUMBER() OVER(PARTITION BY c.risk_category ORDER BY t.amount) as rn,
           COUNT(*) OVER(PARTITION BY c.risk_category) as ct
    FROM transactions t
    JOIN accounts a ON a.account_id = t.account_id
    JOIN customers c ON c.customer_id = a.customer_id
)
SELECT risk_category, AVG(amount) as median_amount
FROM RankedTxns
WHERE rn IN (FLOOR((ct+1)/2), CEIL((ct+1)/2))
GROUP BY risk_category;


-- Q80. Dynamic Row to Column Pivot: Count Alert severities per Analyst
SELECT assigned_to_analyst,
       SUM(CASE WHEN alert_severity = 'critical' THEN 1 ELSE 0 END) as critical_alerts,
       SUM(CASE WHEN alert_severity = 'high' THEN 1 ELSE 0 END) as high_alerts,
       SUM(CASE WHEN alert_severity = 'medium' THEN 1 ELSE 0 END) as medium_alerts,
       SUM(CASE WHEN alert_severity = 'low' THEN 1 ELSE 0 END) as low_alerts
FROM alerts
WHERE status = 'resolved' AND assigned_to_analyst IS NOT NULL
GROUP BY assigned_to_analyst;


-- Q81. Anti-Join: Customers who have accounts but NO transactions ever
SELECT c.full_name, a.account_number 
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
LEFT JOIN transactions t ON t.account_id = a.account_id
WHERE t.transaction_id IS NULL;


-- Q82. Time-Series: Daily Transaction Volume YoY Growth
WITH DailyVol AS (
    SELECT DATE(transaction_date) as t_date, SUM(amount) as vol
    FROM transactions GROUP BY DATE(transaction_date)
)
SELECT curr.t_date, curr.vol as current_year_vol, prev.vol as last_year_vol,
       ROUND(((curr.vol - prev.vol) / prev.vol) * 100, 2) AS yoy_growth_pct
FROM DailyVol curr
LEFT JOIN DailyVol prev ON DATE_SUB(curr.t_date, INTERVAL 1 YEAR) = prev.t_date
WHERE prev.vol IS NOT NULL;


-- Q83. Fraud Ring Detection: Shared IP Addresses across multiple customers
SELECT ip_address, COUNT(DISTINCT customer_id) AS unique_customers, 
       GROUP_CONCAT(DISTINCT customer_id) as customer_list
FROM login_audit
WHERE ip_address IS NOT NULL
GROUP BY ip_address
HAVING COUNT(DISTINCT customer_id) > 2
ORDER BY unique_customers DESC;


-- Q84. Cross Apply (Correlated Subquery): Last 3 non-ATM transactions for each VIP
SELECT c.full_name, t1.transaction_date, t1.amount, t1.transaction_mode
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
JOIN transactions t1 ON t1.account_id = a.account_id
WHERE c.risk_category = 'very_high' AND t1.transaction_mode != 'ATM_CASH'
  AND (
      SELECT COUNT(*) FROM transactions t2 
      WHERE t2.account_id = a.account_id 
        AND t2.transaction_mode != 'ATM_CASH'
        AND t2.transaction_date >= t1.transaction_date
  ) <= 3
ORDER BY c.full_name, t1.transaction_date DESC
LIMIT 30;


-- Q85. Identify "Smurfing": Huge amounts broken into tiny random transfers
SELECT t.account_id, DATE(t.transaction_date) as smurf_date, 
       COUNT(*) as micro_txn_count, SUM(t.amount) as total_smurfed
FROM transactions t
WHERE t.amount BETWEEN 500 AND 2000
GROUP BY t.account_id, DATE(t.transaction_date)
HAVING COUNT(*) > 50 AND SUM(t.amount) > 100000
ORDER BY total_smurfed DESC;


-- Q86. Rollup/Cube: Transaction total sliced by branch and account type
SELECT a.branch_code, a.account_type, SUM(t.amount) as total_volume
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
GROUP BY a.branch_code, a.account_type WITH ROLLUP;


-- Q87. Extracting nested arrays/data from KYC Audit JSON
SELECT audit_id, changed_by, 
       JSON_UNQUOTE(JSON_EXTRACT(changes, '$.previous_status')) AS old_status,
       JSON_UNQUOTE(JSON_EXTRACT(changes, '$.new_status')) AS new_status
FROM kyc_audit_log
WHERE JSON_EXTRACT(changes, '$.new_status') = 'rejected'
LIMIT 20;


-- Q88. Percentage rank of CIBIL scores in loan distribution
SELECT loan_id, customer_id, cibil_score_at_approval,
       PERCENT_RANK() OVER (ORDER BY cibil_score_at_approval DESC) AS top_percentile
FROM loans
ORDER BY cibil_score_at_approval DESC
LIMIT 10;


-- Q89. Find users switching completely from APP to DESKTOP in same week
WITH UserChannels AS (
    SELECT a.customer_id, YEARWEEK(t.transaction_date) as wk, t.channel, COUNT(*) as ct
    FROM transactions t JOIN accounts a ON a.account_id = t.account_id
    GROUP BY a.customer_id, wk, t.channel
)
SELECT curr.customer_id, curr.wk
FROM UserChannels curr
JOIN UserChannels prev ON curr.customer_id = prev.customer_id AND curr.wk = prev.wk + 1
WHERE curr.channel = 'internet_banking' AND prev.channel = 'mobile_app'
  AND curr.ct > 5 AND prev.ct > 5;


-- Q90. Advanced String Manipulation: Regex replace domain in emails
SELECT email_primary, 
       REGEXP_REPLACE(email_primary, '@.*$', '@bank_internal.com') as masked_internal_email
FROM customer_contact
WHERE email_primary IS NOT NULL
LIMIT 10;


-- Q91. Unnesting: Find accounts with multiple KYC document types
SELECT c.customer_id, c.full_name, COUNT(DISTINCT d.document_type) as unique_doc_types
FROM customers c
JOIN customer_identity_documents d ON c.customer_id = d.customer_id
GROUP BY c.customer_id, c.full_name
HAVING COUNT(DISTINCT d.document_type) >= 3;


-- Q92. Overlapping loan dates: finding customers with multiple active loans at same time
SELECT l1.customer_id, l1.loan_id as first_loan, l2.loan_id as second_loan,
       l1.disbursement_date as l1_start, l1.closed_date as l1_end,
       l2.disbursement_date as l2_start, l2.closed_date as l2_end
FROM loans l1
JOIN loans l2 ON l1.customer_id = l2.customer_id AND l1.loan_id < l2.loan_id
WHERE l1.disbursement_date <= IFNULL(l2.closed_date, '2099-01-01')
  AND l2.disbursement_date <= IFNULL(l1.closed_date, '2099-01-01')
LIMIT 10;


-- Q93. Detect "Ghost Employees" via Salary Modes
SELECT a.account_number, t.beneficiary_name, COUNT(*) as deposits
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
WHERE t.transaction_mode = 'SALARY_CREDIT'
GROUP BY a.account_number, t.beneficiary_name
HAVING COUNT(*) > 2 AND DATEDIFF(MAX(t.transaction_date), MIN(t.transaction_date)) < 30;


-- Q94. Moving difference: daily change in total fraud value
WITH DailyFraud AS (
    SELECT DATE(reported_date) as d, SUM(fraud_amount) as total
    FROM fraud_cases GROUP BY DATE(reported_date)
)
SELECT d, total, 
       total - LAG(total, 1, 0) OVER (ORDER BY d) as diff_from_prev_day
FROM DailyFraud;


-- Q95. Self-referencing hierarchies: If investigators had managers
-- (Assuming we map alerts to analysts to managers based on alert strings)
SELECT a1.assigned_to_analyst as analyst, a2.assigned_to_analyst as escalated_to_manager
FROM alerts a1
JOIN alerts a2 ON a1.customer_id = a2.customer_id
WHERE a1.alert_severity = 'low' AND a2.alert_severity = 'critical'
LIMIT 5;


-- Q96. Compare Current Balance against Sum of historic transactions
SELECT a.account_id, a.current_balance as expected_current,
       SUM(CASE WHEN t.transaction_type='credit' THEN t.amount ELSE -t.amount END) as historic_calc,
       a.current_balance - SUM(CASE WHEN t.transaction_type='credit' THEN t.amount ELSE -t.amount END) as variance
FROM accounts a
LEFT JOIN transactions t ON a.account_id = t.account_id
GROUP BY a.account_id, a.current_balance
HAVING variance > 1000 OR variance < -1000
LIMIT 5;


-- Q97. Benford's Law check on Transaction Leading Digits
SELECT LEFT(CAST(amount AS CHAR), 1) as leading_digit, 
       COUNT(*) as digit_count,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 2) as actual_pct,
       ROUND(LOG10(1 + 1/CAST(LEFT(CAST(amount AS CHAR), 1) as FLOAT))*100, 2) as benfords_ideal_pct
FROM transactions
WHERE amount > 10 AND LEFT(CAST(amount AS CHAR), 1) IN ('1','2','3','4','5','6','7','8','9')
GROUP BY leading_digit
ORDER BY leading_digit;


-- Q98. Most complex single query: Full Portfolio stress test calculation
SELECT a.branch_code, 
       SUM(a.current_balance) as retail_deps,
       SUM(CASE WHEN l.loan_status = 'npa' THEN l.outstanding_amount ELSE 0 END) as npa_exposure,
       (SUM(CASE WHEN l.loan_status = 'npa' THEN l.outstanding_amount ELSE 0 END) / SUM(a.current_balance))*100 as stress_ratio
FROM accounts a
LEFT JOIN loans l ON a.account_id = l.account_id
WHERE a.account_type IN ('savings', 'current')
GROUP BY a.branch_code;


-- Q99. Deciles grouping for marketing targets
SELECT customer_id, annual_income,
       NTILE(10) OVER (ORDER BY annual_income DESC) as income_decile
FROM customers
LIMIT 20;


-- Q100. The Omni-Join: The grand analytics summary table
SELECT c.full_name, a.account_number, 
       IFNULL(SUM(t.amount), 0) as total_txns,
       COUNT(DISTINCT al.alert_id) as total_alerts,
       COUNT(DISTINCT fc.case_id) as total_fraud_cases,
       MAX(l.cibil_score_at_approval) as best_loan_score
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
LEFT JOIN transactions t ON t.account_id = a.account_id
LEFT JOIN alerts al ON al.customer_id = c.customer_id
LEFT JOIN fraud_cases fc ON fc.customer_id = c.customer_id
LEFT JOIN loans l ON l.customer_id = c.customer_id
GROUP BY c.full_name, a.account_number
ORDER BY total_fraud_cases DESC, total_alerts DESC
LIMIT 10;
