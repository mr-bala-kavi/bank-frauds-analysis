-- ═══════════════════════════════════════════════════════════════════════════
-- BANK FRAUD ANALYST TRAINING DATABASE
-- LEVEL 0 — VERY BEGINNER
-- ═══════════════════════════════════════════════════════════════════════════

USE bank_fraud_db;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  LEVEL 0 — VERY BEGINNER                                            ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Q51. Select all details of the first 10 customers
SELECT * FROM customers LIMIT 10;


-- Q52. Show only the full name and date of birth of 5 customers
SELECT full_name, date_of_birth FROM customers LIMIT 5;


-- Q53. Find all customers whose nationality is 'UK'
SELECT customer_id, full_name, nationality 
FROM customers 
WHERE nationality = 'UK';


-- Q54. Find all customers from 'USA' or 'Singapore'
SELECT customer_id, full_name, nationality 
FROM customers 
WHERE nationality IN ('USA', 'Singapore');


-- Q55. Find all accounts with a 'frozen' status
SELECT account_number, account_type, account_status 
FROM accounts 
WHERE account_status = 'frozen';


-- Q56. Show transactions where the amount is greater than ₹50,000
SELECT transaction_id, transaction_date, amount, transaction_type 
FROM transactions 
WHERE amount > 50000 
ORDER BY amount DESC 
LIMIT 20;


-- Q57. List all 'credit' transactions done via 'NEFT'
SELECT transaction_date, amount, transaction_mode, transaction_type 
FROM transactions 
WHERE transaction_type = 'credit' AND transaction_mode = 'NEFT'
LIMIT 20;


-- Q58. Find customers born between Jan 1, 1990 and Dec 31, 1999
SELECT full_name, date_of_birth 
FROM customers 
WHERE date_of_birth BETWEEN '1990-01-01' AND '1999-12-31';


-- Q59. Count the total number of customers in the database
SELECT COUNT(*) AS total_customers FROM customers;


-- Q60. Count the total number of 'active' accounts
SELECT COUNT(*) AS active_accounts 
FROM accounts 
WHERE account_status = 'active';


-- Q61. Find the maximum and minimum transaction amounts
SELECT MAX(amount) AS max_txn, MIN(amount) AS min_txn 
FROM transactions;


-- Q62. Calculate the average transaction amount for 'ATM_CASH' withdrawals
SELECT AVG(amount) AS avg_atm_withdrawal 
FROM transactions 
WHERE transaction_mode = 'ATM_CASH';


-- Q63. Find all customers whose first name starts with 'A'
SELECT first_name, last_name 
FROM customers 
WHERE first_name LIKE 'A%';


-- Q64. Find all branches that have 'BR1' in their code
SELECT DISTINCT branch_code 
FROM accounts 
WHERE branch_code LIKE '%BR1%';


-- Q65. Group customers by their risk category and count them
SELECT risk_category, COUNT(*) AS total 
FROM customers 
GROUP BY risk_category;


-- Q66. Find the total outstanding loan amount by loan type
SELECT loan_type, SUM(outstanding_amount) AS total_outstanding 
FROM loans 
GROUP BY loan_type;


-- Q67. List all distinct occupations of our customers
SELECT DISTINCT occupation FROM customers;


-- Q68. Sort the 10 highest balance accounts in descending order
SELECT account_number, current_balance 
FROM accounts 
ORDER BY current_balance DESC 
LIMIT 10;


-- Q69. Sort customers by their joining date (newest first)
SELECT full_name, customer_since 
FROM customers 
ORDER BY customer_since DESC 
LIMIT 10;


-- Q70. Find customers whose KYC is 'rejected' and risk is 'high' or 'very_high'
SELECT full_name, kyc_status, risk_category 
FROM customers 
WHERE kyc_status = 'rejected' 
  AND risk_category IN ('high', 'very_high');


-- Q71. Join customer names with their account numbers (Limit 15)
SELECT c.full_name, a.account_number 
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
LIMIT 15;


-- Q72. Join customer names with their primary email addresses
SELECT c.full_name, contact.email_primary 
FROM customers c
JOIN customer_contact contact ON c.customer_id = contact.customer_id
LIMIT 15;


-- Q73. Count how many accounts each customer has (Show top 10)
SELECT customer_id, COUNT(*) AS num_accounts 
FROM accounts 
GROUP BY customer_id 
ORDER BY num_accounts DESC 
LIMIT 10;


-- Q74. Check if there are any null values in transaction merchant names
SELECT COUNT(*) AS missing_merchants 
FROM transactions 
WHERE merchant_name IS NULL;


-- Q75. Simple IF/CASE statement: Label transactions > 1L as 'LARGE' else 'NORMAL'
SELECT transaction_id, amount, 
       CASE 
           WHEN amount > 100000 THEN 'LARGE' 
           ELSE 'NORMAL' 
       END AS size_category
FROM transactions 
LIMIT 20;
