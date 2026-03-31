-- ═══════════════════════════════════════════════════════════════════════════
-- BANK FRAUD ANALYST TRAINING DATABASE
-- 50 SQL EXERCISES — MySQL 8.0+
-- Levels: 1=Basics | 2=Transaction Analysis | 3=Fraud Detection
--         4=Aggregation | 5=Advanced | 6=Analyst Workflow
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  LEVEL 1 — BASICS (Customer & Account Queries)                      ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q1. Find all customers named "Ravi Kumar" with different addresses   │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT c.customer_id, c.full_name, c.date_of_birth, c.nationality,
       a.city, a.state, a.country
FROM   customers c
JOIN   customer_address a ON a.customer_id = c.customer_id AND a.is_current = TRUE
WHERE  c.full_name = 'Ravi Kumar'
ORDER  BY c.date_of_birth;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q2. List all accounts opened in last 30 days with balance > ₹5 lakhs│
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT a.account_id, a.account_number, c.full_name,
       a.account_type, a.current_balance, a.opened_date
FROM   accounts a
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  a.opened_date >= CURDATE() - INTERVAL 30 DAY
  AND  a.current_balance > 500000
ORDER  BY a.current_balance DESC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q3. Find customers with expired KYC documents                        │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT c.customer_id, c.full_name, c.kyc_status,
       d.document_type, d.document_number, d.expiry_date,
       DATEDIFF(CURDATE(), d.expiry_date) AS days_expired
FROM   customers c
JOIN   customer_identity_documents d ON d.customer_id = c.customer_id
WHERE  d.expiry_date < CURDATE()
ORDER  BY d.expiry_date ASC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q4. Show all NRI accounts with foreign currency transactions          │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT a.account_id, a.account_number, c.full_name,
       a.account_type, a.currency,
       COUNT(t.transaction_id) AS foreign_txn_count,
       SUM(t.amount)           AS total_amount
FROM   accounts a
JOIN   customers c ON c.customer_id = a.customer_id
JOIN   transactions t ON t.account_id = a.account_id
WHERE  a.account_type = 'nri'
  AND  t.currency != 'INR'
GROUP  BY a.account_id, a.account_number, c.full_name, a.account_type, a.currency
ORDER  BY foreign_txn_count DESC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q5. Find duplicate email addresses across customers                  │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT cc.email_primary, COUNT(*) AS num_customers,
       GROUP_CONCAT(c.full_name ORDER BY c.full_name SEPARATOR ' | ') AS names
FROM   customer_contact cc
JOIN   customers c ON c.customer_id = cc.customer_id
WHERE  cc.email_primary IS NOT NULL
GROUP  BY cc.email_primary
HAVING COUNT(*) > 1
ORDER  BY num_customers DESC;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  LEVEL 2 — TRANSACTION ANALYSIS                                     ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q6. Find all transactions above ₹10 lakhs in last 7 days            │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t.transaction_id, t.transaction_date, t.transaction_time,
       c.full_name, a.account_number, t.transaction_type,
       t.transaction_mode, t.amount, t.channel,
       t.location_city, t.location_country
FROM   transactions t
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  t.transaction_date >= CURDATE() - INTERVAL 7 DAY
  AND  t.amount > 1000000
ORDER  BY t.amount DESC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q7. Show accounts with more than 20 transactions in a single day     │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t.account_id, a.account_number, c.full_name,
       t.transaction_date, COUNT(*) AS txn_count,
       SUM(t.amount) AS total_amount
FROM   transactions t
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
GROUP  BY t.account_id, a.account_number, c.full_name, t.transaction_date
HAVING COUNT(*) > 20
ORDER  BY txn_count DESC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q8. Transactions done between midnight and 4 AM (suspicious hours)   │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t.transaction_id, t.transaction_date, t.transaction_time,
       c.full_name, a.account_number,
       t.transaction_type, t.amount, t.transaction_mode,
       t.channel, t.ip_address
FROM   transactions t
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  t.transaction_time BETWEEN '00:00:00' AND '04:00:00'
ORDER  BY t.amount DESC
LIMIT  100;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q9. Identify round-amount transactions (exact multiples of ₹10,000) │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t.transaction_id, t.transaction_date,
       c.full_name, a.account_number,
       t.amount, t.transaction_mode, t.beneficiary_name
FROM   transactions t
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  t.amount >= 10000
  AND  t.amount MOD 10000 = 0
  AND  t.transaction_type = 'debit'
ORDER  BY t.amount DESC
LIMIT  200;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q10. Top 10 accounts by total transaction value this month           │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t.account_id, a.account_number, c.full_name,
       COUNT(*) AS txn_count, SUM(t.amount) AS total_value
FROM   transactions t
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  MONTH(t.transaction_date) = MONTH(CURDATE())
  AND  YEAR(t.transaction_date)  = YEAR(CURDATE())
GROUP  BY t.account_id, a.account_number, c.full_name
ORDER  BY total_value DESC
LIMIT  10;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  LEVEL 3 — FRAUD DETECTION QUERIES                                  ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q11. Structuring: 3+ transactions between ₹1.8L–₹2L in a single day │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t.account_id, a.account_number, c.full_name,
       t.transaction_date, COUNT(*) AS structuring_count,
       SUM(t.amount) AS total_structured
FROM   transactions t
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  t.amount BETWEEN 180000 AND 199999
  AND  t.transaction_type = 'debit'
GROUP  BY t.account_id, a.account_number, c.full_name, t.transaction_date
HAVING COUNT(*) >= 3
ORDER  BY structuring_count DESC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q12. Velocity: 5+ transactions within any 1-hour window             │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t1.account_id, a.account_number, c.full_name,
       t1.transaction_date,
       t1.transaction_time AS window_start,
       COUNT(*) AS txn_in_hour
FROM   transactions t1
JOIN   transactions t2
    ON  t2.account_id = t1.account_id
   AND  t2.transaction_date = t1.transaction_date
   AND  TIMESTAMPDIFF(MINUTE,
            TIMESTAMP(t1.transaction_date, t1.transaction_time),
            TIMESTAMP(t2.transaction_date, t2.transaction_time)) BETWEEN 0 AND 60
JOIN   accounts a  ON a.account_id  = t1.account_id
JOIN   customers c ON c.customer_id = a.customer_id
GROUP  BY t1.account_id, a.account_number, c.full_name,
          t1.transaction_date, t1.transaction_time
HAVING COUNT(*) >= 5
ORDER  BY txn_in_hour DESC
LIMIT  50;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q13. Dormant revival: zero txns for 365 days then sudden large credit│
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT a.account_id, a.account_number, c.full_name,
       a.last_transaction_date,
       t.transaction_date      AS revival_date,
       t.amount                AS revival_amount,
       t.transaction_mode,
       DATEDIFF(t.transaction_date, a.last_transaction_date) AS gap_days
FROM   accounts a
JOIN   customers c ON c.customer_id = a.customer_id
JOIN   transactions t ON t.account_id = a.account_id
WHERE  t.transaction_type = 'credit'
  AND  t.amount > 100000
  AND  a.last_transaction_date < t.transaction_date - INTERVAL 365 DAY
ORDER  BY gap_days DESC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q14. Mule account: receiving from 20+ unique senders in one month   │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t.account_id, a.account_number, c.full_name,
       YEAR(t.transaction_date) AS yr, MONTH(t.transaction_date) AS mo,
       COUNT(DISTINCT t.beneficiary_name) AS unique_senders,
       SUM(t.amount) AS total_received
FROM   transactions t
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  t.transaction_type = 'credit'
GROUP  BY t.account_id, a.account_number, c.full_name, yr, mo
HAVING COUNT(DISTINCT t.beneficiary_name) >= 20
ORDER  BY unique_senders DESC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q15. Card geo-anomaly: same card, 2 countries within 4 hours        │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t1.account_id, a.account_number, c.full_name,
       t1.transaction_date,
       t1.location_country AS country_1, t1.transaction_time AS time_1,
       t2.location_country AS country_2, t2.transaction_time AS time_2,
       ABS(TIMESTAMPDIFF(MINUTE,
           TIMESTAMP(t1.transaction_date, t1.transaction_time),
           TIMESTAMP(t2.transaction_date, t2.transaction_time))) AS gap_minutes
FROM   transactions t1
JOIN   transactions t2
    ON  t2.account_id = t1.account_id
   AND  t2.transaction_id > t1.transaction_id
   AND  t2.transaction_date = t1.transaction_date
   AND  t2.location_country != t1.location_country
   AND  ABS(TIMESTAMPDIFF(MINUTE,
            TIMESTAMP(t1.transaction_date, t1.transaction_time),
            TIMESTAMP(t2.transaction_date, t2.transaction_time))) <= 240
JOIN   accounts a  ON a.account_id  = t1.account_id
JOIN   customers c ON c.customer_id = a.customer_id
ORDER  BY gap_minutes ASC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q16. Salary diversion: salary credit then full transfer within 2h   │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT s.account_id, a.account_number, c.full_name,
       s.transaction_date, s.amount AS salary_amount,
       d.amount AS diverted_amount, d.transaction_time AS divert_time,
       d.beneficiary_name,
       TIMESTAMPDIFF(MINUTE,
           TIMESTAMP(s.transaction_date, s.transaction_time),
           TIMESTAMP(d.transaction_date, d.transaction_time)) AS minutes_gap
FROM   transactions s
JOIN   transactions d
    ON  d.account_id = s.account_id
   AND  d.transaction_date = s.transaction_date
   AND  d.transaction_type = 'debit'
   AND  d.amount >= s.amount * 0.90
   AND  TIMESTAMPDIFF(MINUTE,
            TIMESTAMP(s.transaction_date, s.transaction_time),
            TIMESTAMP(d.transaction_date, d.transaction_time)) BETWEEN 1 AND 120
JOIN   accounts a  ON a.account_id  = s.account_id
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  s.transaction_mode = 'SALARY_CREDIT'
ORDER  BY minutes_gap ASC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q17. Round-trip: money returning to origin account within 72 hours  │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT out_t.account_id                      AS origin_account,
       a.account_number,
       c.full_name,
       out_t.amount                           AS sent_amount,
       in_t.amount                            AS received_amount,
       out_t.transaction_date                 AS sent_date,
       in_t.transaction_date                  AS return_date,
       DATEDIFF(in_t.transaction_date, out_t.transaction_date) AS days_gap
FROM   transactions out_t
JOIN   transactions in_t
    ON  in_t.account_id = out_t.account_id
   AND  in_t.transaction_type = 'credit'
   AND  in_t.transaction_date BETWEEN out_t.transaction_date
                                   AND out_t.transaction_date + INTERVAL 72 HOUR
   AND  ABS(in_t.amount - out_t.amount) / out_t.amount < 0.05  -- within 5%
   AND  in_t.transaction_id != out_t.transaction_id
JOIN   accounts a  ON a.account_id  = out_t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  out_t.transaction_type = 'debit'
  AND  out_t.amount > 50000
ORDER  BY days_gap ASC
LIMIT  50;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q18. New beneficiary + large transfer: 1st txn to benef > ₹5 lakhs │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT t.account_id, a.account_number, c.full_name,
       t.beneficiary_name, t.amount,
       t.transaction_date, t.transaction_mode,
       b.added_date AS beneficiary_added_date,
       DATEDIFF(t.transaction_date, b.added_date) AS days_since_added
FROM   transactions t
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
JOIN   beneficiaries b
    ON  b.customer_id = c.customer_id
   AND  b.beneficiary_name = t.beneficiary_name
WHERE  t.transaction_type = 'debit'
  AND  t.amount > 500000
  AND  DATEDIFF(t.transaction_date, b.added_date) BETWEEN 0 AND 3
ORDER  BY t.amount DESC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q19. Failed login spike: 5+ failed logins in 30 minutes             │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT l1.customer_id, c.full_name,
       l1.login_datetime AS window_start,
       COUNT(*) AS failed_logins_in_30min,
       l1.ip_address, l1.location_country
FROM   login_audit l1
JOIN   login_audit l2
    ON  l2.customer_id = l1.customer_id
   AND  l2.login_status = 'failed'
   AND  TIMESTAMPDIFF(MINUTE, l1.login_datetime, l2.login_datetime)
        BETWEEN 0 AND 30
JOIN   customers c ON c.customer_id = l1.customer_id
WHERE  l1.login_status = 'failed'
GROUP  BY l1.customer_id, c.full_name, l1.login_datetime, l1.ip_address, l1.location_country
HAVING COUNT(*) >= 5
ORDER  BY failed_logins_in_30min DESC;


-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ Q20. PEP transactions above ₹50,000                                 │
-- └──────────────────────────────────────────────────────────────────────┘
-- ANSWER:
SELECT c.customer_id, c.full_name, c.risk_category,
       t.transaction_date, t.amount, t.transaction_mode,
       t.transaction_type, t.beneficiary_name,
       a.account_number, t.location_country
FROM   customers c
JOIN   accounts a     ON a.customer_id  = c.customer_id
JOIN   transactions t ON t.account_id   = a.account_id
WHERE  c.pep_flag = TRUE
  AND  t.amount   > 50000
ORDER  BY t.amount DESC;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  LEVEL 4 — AGGREGATION & REPORTING                                  ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Q21. Monthly fraud loss report by fraud type
SELECT DATE_FORMAT(reported_date, '%Y-%m') AS month,
       case_type,
       COUNT(*)              AS cases,
       SUM(fraud_amount)     AS total_loss,
       SUM(recovery_amount)  AS recovered,
       SUM(fraud_amount) - SUM(recovery_amount) AS net_loss
FROM   fraud_cases
WHERE  case_status IN ('confirmed','filed_fir','reported_to_rbi')
GROUP  BY month, case_type
ORDER  BY month DESC, total_loss DESC;


-- Q22. Branch-wise NPA summary
SELECT a.branch_code,
       COUNT(DISTINCT l.loan_id)      AS npa_loans,
       SUM(l.outstanding_amount)      AS total_outstanding,
       AVG(l.interest_rate)           AS avg_interest_rate,
       COUNT(DISTINCT l.customer_id)  AS unique_customers
FROM   loans l
JOIN   accounts a ON a.account_id = l.account_id
WHERE  l.loan_status = 'npa'
GROUP  BY a.branch_code
ORDER  BY total_outstanding DESC;


-- Q23. Customer risk distribution (pie chart data)
SELECT risk_category,
       COUNT(*) AS customer_count,
       ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM customers),2) AS percentage
FROM   customers GROUP BY risk_category ORDER BY customer_count DESC;


-- Q24. Top 10 merchants with most suspicious/disputed transactions
SELECT merchant_name, COUNT(*) AS txn_count,
       SUM(amount) AS total_amount,
       SUM(CASE WHEN fraud_flag=TRUE THEN 1 ELSE 0 END) AS fraud_count
FROM   transactions
WHERE  merchant_name IS NOT NULL
GROUP  BY merchant_name
ORDER  BY fraud_count DESC, txn_count DESC
LIMIT  10;


-- Q25. Country-wise transaction heatmap
SELECT location_country,
       COUNT(*)       AS txn_count,
       SUM(amount)    AS total_value,
       AVG(amount)    AS avg_amount,
       SUM(fraud_flag) AS fraud_transactions
FROM   transactions
WHERE  location_country IS NOT NULL
GROUP  BY location_country
ORDER  BY total_value DESC;


-- Q26. Alert resolution time (avg days to resolve by severity)
SELECT alert_severity,
       COUNT(*)                                                AS total_alerts,
       SUM(CASE WHEN status='resolved' THEN 1 ELSE 0 END)     AS resolved,
       SUM(CASE WHEN status='open' THEN 1 ELSE 0 END)         AS still_open,
       ROUND(AVG(DATEDIFF(resolved_date, alert_date)),1)       AS avg_days_to_resolve
FROM   alerts
GROUP  BY alert_severity ORDER BY FIELD(alert_severity,'critical','high','medium','low');


-- Q27. Analyst productivity (alerts resolved per analyst per month)
SELECT assigned_to_analyst,
       DATE_FORMAT(resolved_date,'%Y-%m') AS month,
       COUNT(*) AS resolved_count,
       ROUND(AVG(DATEDIFF(resolved_date, alert_date)),1) AS avg_resolution_days
FROM   alerts
WHERE  status = 'resolved' AND assigned_to_analyst IS NOT NULL
GROUP  BY assigned_to_analyst, month
ORDER  BY month DESC, resolved_count DESC;


-- Q28. Year-over-year fraud case trend
SELECT YEAR(reported_date) AS year,
       COUNT(*) AS total_cases,
       SUM(fraud_amount) AS total_fraud_value,
       ROUND(SUM(recovery_amount)/SUM(fraud_amount)*100,1) AS recovery_rate_pct
FROM   fraud_cases
GROUP  BY year ORDER BY year;


-- Q29. Loan default prediction features (CTE)
WITH loan_features AS (
    SELECT l.loan_id, l.customer_id, l.loan_type, l.cibil_score_at_approval,
           l.interest_rate, l.tenure_months,
           l.principal_amount / NULLIF(c.annual_income,0)   AS loan_to_income_ratio,
           COUNT(r.repayment_id)                             AS total_emis,
           SUM(CASE WHEN r.payment_status='missed'  THEN 1 ELSE 0 END) AS missed_emis,
           SUM(CASE WHEN r.payment_status='bounced'  THEN 1 ELSE 0 END) AS bounced_emis,
           MAX(r.days_past_due)                              AS max_dpd,
           l.loan_status
    FROM   loans l
    JOIN   customers c ON c.customer_id = l.customer_id
    LEFT JOIN loan_repayments r ON r.loan_id = l.loan_id
    GROUP  BY l.loan_id, l.customer_id, l.loan_type, l.cibil_score_at_approval,
              l.interest_rate, l.tenure_months, loan_to_income_ratio, l.loan_status
)
SELECT *, CASE
    WHEN cibil_score_at_approval < 650 AND loan_to_income_ratio > 5 AND missed_emis > 2
        THEN 'HIGH RISK'
    WHEN cibil_score_at_approval < 700 OR max_dpd > 60
        THEN 'MEDIUM RISK'
    ELSE 'LOW RISK'
END AS default_risk_label
FROM loan_features
ORDER BY max_dpd DESC, missed_emis DESC;


-- Q30. AML high-risk customer list for RBI submission
SELECT c.customer_id, c.full_name, c.nationality, c.occupation,
       c.annual_income, c.pep_flag, c.risk_category,
       am.screening_date, am.risk_score, am.action_taken,
       am.watchlist_matched,
       fc.fraud_case_count, fc.total_fraud_loss
FROM   customers c
JOIN   aml_screening am ON am.customer_id = c.customer_id
LEFT JOIN (
    SELECT customer_id, COUNT(*) AS fraud_case_count,
           SUM(fraud_amount) AS total_fraud_loss
    FROM fraud_cases
    GROUP BY customer_id
) fc ON fc.customer_id = c.customer_id
WHERE  am.action_taken IN ('escalated','blocked','reported_fiu')
   OR  am.watchlist_matched = TRUE
   OR  c.risk_category = 'very_high'
ORDER  BY am.risk_score DESC;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  LEVEL 5 — ADVANCED (CTEs, Windows, Recursive, Subqueries)         ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Q31. Running balance validation
SELECT transaction_id, transaction_date, transaction_time,
       transaction_type, amount, balance_after_transaction,
       SUM(CASE WHEN transaction_type='credit' THEN amount ELSE -amount END)
           OVER (PARTITION BY account_id ORDER BY transaction_date, transaction_time) AS computed_running_total,
       balance_after_transaction -
       SUM(CASE WHEN transaction_type='credit' THEN amount ELSE -amount END)
           OVER (PARTITION BY account_id ORDER BY transaction_date, transaction_time) AS discrepancy
FROM transactions
ORDER BY account_id, transaction_date, transaction_time
LIMIT 100;


-- Q32. Rank each customer's transactions by amount (top 3 per customer)
WITH ranked AS (
    SELECT t.transaction_id, a.customer_id, c.full_name,
           t.amount, t.transaction_date, t.transaction_mode,
           RANK() OVER (PARTITION BY a.customer_id ORDER BY t.amount DESC) AS rnk
    FROM   transactions t
    JOIN   accounts a  ON a.account_id  = t.account_id
    JOIN   customers c ON c.customer_id = a.customer_id
)
SELECT * FROM ranked WHERE rnk <= 3 ORDER BY customer_id, rnk;


-- Q33. Rolling 30-day transaction average per account
SELECT account_id, transaction_date,
       amount,
       ROUND(AVG(amount) OVER (
           PARTITION BY account_id
           ORDER BY transaction_date
           ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
       ), 2) AS rolling_30d_avg
FROM transactions
ORDER BY account_id, transaction_date;


-- Q34. First and last transaction per account
SELECT account_id,
       FIRST_VALUE(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date)                  AS first_txn_date,
       FIRST_VALUE(amount)           OVER (PARTITION BY account_id ORDER BY transaction_date)                  AS first_txn_amount,
       FIRST_VALUE(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date DESC)             AS last_txn_date,
       FIRST_VALUE(amount)           OVER (PARTITION BY account_id ORDER BY transaction_date DESC)             AS last_txn_amount
FROM transactions
GROUP BY account_id  -- Note: Use subquery for actual dedup
LIMIT 100;


-- Q35. Cohort analysis: customers who joined in 2023, still active?
SELECT DATE_FORMAT(customer_since,'%Y-%m') AS cohort_month,
       COUNT(*)                             AS joined,
       SUM(is_active)                       AS still_active,
       ROUND(SUM(is_active)*100.0/COUNT(*),1) AS retention_pct
FROM   customers
WHERE  YEAR(customer_since) = 2023
GROUP  BY cohort_month
ORDER  BY cohort_month;


-- Q36. Self-join: find transactions between two accounts of same customer
SELECT t1.transaction_id AS txn1_id, t2.transaction_id AS txn2_id,
       c.full_name, a1.account_number AS from_acc, a2.account_number AS to_acc,
       t1.amount, t1.transaction_date
FROM   transactions t1
JOIN   accounts a1 ON a1.account_id = t1.account_id
JOIN   accounts a2 ON a2.customer_id = a1.customer_id AND a2.account_id != a1.account_id
JOIN   transactions t2 ON t2.account_id = a2.account_id
                      AND t2.transaction_date = t1.transaction_date
                      AND ABS(t2.amount - t1.amount) < 100
JOIN   customers c ON c.customer_id = a1.customer_id
WHERE  t1.transaction_type = 'debit'
  AND  t2.transaction_type = 'credit'
ORDER  BY t1.transaction_date DESC
LIMIT  50;


-- Q37. Pivot: monthly transaction count by channel
SELECT
    DATE_FORMAT(transaction_date,'%Y-%m') AS month,
    SUM(channel = 'mobile_app')          AS mobile_app,
    SUM(channel = 'internet_banking')    AS internet_banking,
    SUM(channel = 'atm')                 AS atm,
    SUM(channel = 'branch')              AS branch,
    SUM(channel = 'api')                 AS api,
    SUM(channel = 'pos')                 AS pos
FROM transactions
GROUP BY month ORDER BY month;


-- Q38. Recursive CTE: trace money trail A → B → C → D
-- (Traces up to 4 hops using transaction reference linking)
WITH RECURSIVE money_trail AS (
    -- anchor: pick a starting suspicious transaction
    SELECT transaction_id, account_id, beneficiary_account_id, amount,
           transaction_date, 1 AS hop,
           CAST(transaction_id AS CHAR(200)) AS trail
    FROM   transactions
    WHERE  fraud_type = 'mule_account'
      AND  transaction_type = 'debit'
    LIMIT  5

    UNION ALL

    SELECT t.transaction_id, t.account_id, t.beneficiary_account_id,
           t.amount, t.transaction_date, mt.hop + 1,
           CONCAT(mt.trail, ' -> ', t.transaction_id)
    FROM   transactions t
    JOIN   money_trail mt ON t.account_id = mt.beneficiary_account_id
                         AND t.transaction_date >= mt.transaction_date
    WHERE  mt.hop < 4
)
SELECT hop, account_id, beneficiary_account_id, amount, transaction_date, trail
FROM   money_trail ORDER BY trail, hop;


-- Q39. Gap analysis: accounts with NO transaction for exactly 30, 60, 90 days
SELECT account_id, account_number, last_transaction_date,
       DATEDIFF(CURDATE(), last_transaction_date) AS days_inactive,
       CASE
           WHEN DATEDIFF(CURDATE(), last_transaction_date) BETWEEN 28 AND 32 THEN '30-day gap'
           WHEN DATEDIFF(CURDATE(), last_transaction_date) BETWEEN 58 AND 62 THEN '60-day gap'
           WHEN DATEDIFF(CURDATE(), last_transaction_date) BETWEEN 88 AND 92 THEN '90-day gap'
       END AS gap_bucket
FROM   accounts
WHERE  DATEDIFF(CURDATE(), last_transaction_date) IN (
           28,29,30,31,32,58,59,60,61,62,88,89,90,91,92
       )
  AND  account_status = 'active';


-- Q40. Z-score anomaly: transactions > 3 std deviations from account avg
WITH stats AS (
    SELECT account_id,
           AVG(amount) AS mean_amt,
           STDDEV(amount) AS std_amt
    FROM   transactions
    GROUP  BY account_id
)
SELECT t.transaction_id, t.account_id, c.full_name,
       t.amount, t.transaction_date,
       s.mean_amt, s.std_amt,
       ROUND((t.amount - s.mean_amt) / NULLIF(s.std_amt,0), 2) AS z_score
FROM   transactions t
JOIN   stats s  ON s.account_id = t.account_id
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
WHERE  (t.amount - s.mean_amt) / NULLIF(s.std_amt,0) > 3
ORDER  BY z_score DESC
LIMIT  50;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  LEVEL 6 — ANALYST WORKFLOW QUERIES                                 ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Q41. Morning dashboard: today's critical alerts
SELECT al.alert_id, c.full_name, a.account_number,
       al.alert_type, al.alert_severity, al.alert_message,
       al.alert_time, al.status
FROM   alerts al
JOIN   customers c ON c.customer_id = al.customer_id
JOIN   accounts a  ON a.account_id  = al.account_id
WHERE  al.alert_date = CURDATE()
  AND  al.alert_severity = 'critical'
ORDER  BY al.alert_time;


-- Q42. Assign unassigned high-severity alerts to analysts
UPDATE alerts
SET    assigned_to_analyst = ELT(MOD(alert_id, 7) + 1,
           'Analyst_Meera','Analyst_Rohit','Analyst_Priya',
           'Analyst_Karthik','Analyst_Deepa','Analyst_Suresh','Analyst_Anjali'),
       status = 'under_review'
WHERE  status = 'open'
  AND  alert_severity IN ('high','critical')
  AND  assigned_to_analyst IS NULL
LIMIT  100;


-- Q43. Freeze all accounts in a fraud ring (given account list)
-- Replace the IN list with actual account IDs from your investigation:
-- CALL sp_freeze_account('account-uuid-here', 'Fraud ring investigation');

-- Example: freeze all accounts flagged for mule_account fraud
UPDATE accounts
SET    account_status = 'frozen'
WHERE  account_id IN (
    SELECT DISTINCT account_id FROM transactions
    WHERE  fraud_type = 'mule_account'
);


-- Q44. Generate STR (Suspicious Transaction Report) extract
SELECT 'STR_' || DATE_FORMAT(CURDATE(),'%Y%m%d') AS report_id,
       c.customer_id, c.full_name, c.nationality,
       a.account_number, t.transaction_date,
       t.amount, t.transaction_mode, t.transaction_type,
       t.beneficiary_name, t.beneficiary_bank, t.beneficiary_ifsc,
       t.location_country, t.fraud_type,
       al.alert_type, al.alert_message
FROM   transactions t
JOIN   accounts a  ON a.account_id  = t.account_id
JOIN   customers c ON c.customer_id = a.customer_id
LEFT JOIN alerts al ON al.transaction_id = t.transaction_id
WHERE  t.fraud_flag = TRUE
  AND  t.transaction_date >= CURDATE() - INTERVAL 30 DAY
ORDER  BY t.amount DESC;


-- Q45. Customer 360 for a given customer_id
-- Replace the UUID below with any real customer_id from your data
SELECT * FROM v_customer_360
WHERE  customer_id = (SELECT customer_id FROM customers LIMIT 1);


-- Q46. Fraud case aging: cases open more than 30 days
SELECT case_id, c.full_name, fc.case_type, fc.case_status,
       fc.fraud_amount, fc.reported_date,
       DATEDIFF(CURDATE(), fc.reported_date) AS days_open,
       fc.reported_by
FROM   fraud_cases fc
JOIN   customers c ON c.customer_id = fc.customer_id
WHERE  fc.case_status IN ('reported','investigating')
  AND  DATEDIFF(CURDATE(), fc.reported_date) > 30
ORDER  BY days_open DESC;


-- Q47. Watchlist matches this week
SELECT c.customer_id, c.full_name, c.nationality, c.risk_category,
       am.screening_date, am.screening_type, am.risk_score,
       am.match_details, am.action_taken
FROM   aml_screening am
JOIN   customers c ON c.customer_id = am.customer_id
WHERE  am.watchlist_matched = TRUE
  AND  am.screening_date >= CURDATE() - INTERVAL 7 DAY
ORDER  BY am.risk_score DESC;


-- Q48. Balance trend 30 days before and after a fraud confirmation
WITH fraud_accounts AS (
    SELECT DISTINCT account_id, confirmed_date
    FROM fraud_cases
    WHERE case_status = 'confirmed' AND confirmed_date IS NOT NULL
    LIMIT 5
),
balance_trend AS (
    SELECT t.account_id, fa.confirmed_date,
           t.transaction_date,
           DATEDIFF(t.transaction_date, fa.confirmed_date) AS day_offset,
           t.balance_after_transaction
    FROM   transactions t
    JOIN   fraud_accounts fa ON fa.account_id = t.account_id
    WHERE  t.transaction_date BETWEEN
               fa.confirmed_date - INTERVAL 30 DAY AND
               fa.confirmed_date + INTERVAL 30 DAY
)
SELECT account_id, day_offset, AVG(balance_after_transaction) AS avg_balance
FROM   balance_trend
GROUP  BY account_id, day_offset
ORDER  BY account_id, day_offset;


-- Q49. Network: find all accounts connected to a mule account
-- (2-hop network: mule → senders → their other accounts)
WITH mule_accounts AS (
    SELECT DISTINCT account_id FROM transactions WHERE fraud_type = 'mule_account'
),
connected_level1 AS (
    SELECT DISTINCT t.account_id AS connected_account, 'inbound_sender' AS relationship
    FROM   transactions t
    WHERE  t.beneficiary_account_id IN (SELECT account_id FROM mule_accounts)
      AND  t.transaction_type = 'debit'
)
SELECT cl.connected_account, cl.relationship,
       a.account_number, c.full_name, a.account_status
FROM   connected_level1 cl
JOIN   accounts a  ON a.account_id  = cl.connected_account
JOIN   customers c ON c.customer_id = a.customer_id
LIMIT 100;


-- Q50. Monthly CTR: all transactions above ₹10 lakhs (Cash Transaction Report)
SELECT DATE_FORMAT(transaction_date,'%Y-%m') AS month,
       COUNT(*) AS transactions_above_10L,
       SUM(amount) AS total_value,
       COUNT(DISTINCT account_id) AS unique_accounts_involved,
       SUM(transaction_type='credit') AS credits,
       SUM(transaction_type='debit')  AS debits,
       GROUP_CONCAT(DISTINCT transaction_mode) AS modes_used
FROM   transactions
WHERE  amount > 1000000
GROUP  BY month
ORDER  BY month DESC;


-- ═══════════════════════════════════════════════════════════════════════
-- END OF 50 EXERCISES
-- Happy fraud hunting! 🕵️
-- ═══════════════════════════════════════════════════════════════════════
