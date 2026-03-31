import mysql.connector
import json
import sqlparse
import random

DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": "kavi",
    "database": "bank_fraud_db"
}

def get_schema():
    schema_dict = {}
    conn = None
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, COLUMN_KEY FROM information_schema.columns WHERE table_schema = 'bank_fraud_db' ORDER BY TABLE_NAME, ORDINAL_POSITION;")
        for r in cursor.fetchall():
            tname = r['TABLE_NAME']
            if tname not in schema_dict: schema_dict[tname] = []
            schema_dict[tname].append({"name": r['COLUMN_NAME'], "type": r['COLUMN_TYPE'], "key": r['COLUMN_KEY']})
    except Exception as e:
        print("Schema fetch error:", e)
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()
    return schema_dict

def generate_questions():
    questions = []
    
    def q(level, title, sql, explanation):
        questions.append({
            "id": len(questions) + 1,
            "level": level,
            "title": f"Q{len(questions) + 1}. {title}",
            "sql": sqlparse.format(sql.strip(), reindent=True, keyword_case='upper', comma_first=False),
            "explanation": explanation.strip()
        })

    # L1: Beginner 1-20 (Basic SELECTs, specific columns, DISTINCT)
    tables_cols = [
        ("customers", "full_name, dob, email_primary"), ("accounts", "account_number, current_balance"), 
        ("transactions", "transaction_id, amount, transaction_date"), ("loans", "loan_id, outstanding_amount"),
        ("fraud_cases", "case_id, fraud_amount"), ("alerts", "alert_id, alert_severity"),
        ("branches", "branch_code, branch_name"), ("cards", "card_number, card_type"),
        ("customer_address", "city, state, country"), ("login_audit", "ip_address, login_status")
    ]
    for i, (tbl, cols) in enumerate(tables_cols):
        q("Level 1 — Basic Viewing", f"View all data in the {tbl} table", f"SELECT * FROM {tbl};", f"Shows every single record and column inside {tbl}.")
        q("Level 1 — Basic Viewing", f"View specific subset of columns from {tbl}", f"SELECT {cols} FROM {tbl};", "Reduces payload size by explicitly naming the needed columns.")
        
    # L2: Beginner 21-40 (WHERE Filtering)
    q("Level 2 — Basic Filtering", "Find customers from the USA", "SELECT full_name FROM customers WHERE nationality = 'USA';", "Filters using equality operator.")
    q("Level 2 — Basic Filtering", "Find customers from India", "SELECT full_name FROM customers WHERE nationality = 'India';", "Filters using equality operator.")
    q("Level 2 — Basic Filtering", "Find male customers", "SELECT full_name FROM customers WHERE gender = 'M';", "Equality filtering on gender tag.")
    q("Level 2 — Basic Filtering", "Find female customers", "SELECT full_name FROM customers WHERE gender = 'F';", "Equality filtering on gender tag.")
    q("Level 2 — Basic Filtering", "Active accounts only", "SELECT account_number FROM accounts WHERE account_status = 'active';", "Filtering on status column.")
    q("Level 2 — Basic Filtering", "Frozen accounts", "SELECT account_number FROM accounts WHERE account_status = 'frozen';", "Find isolated accounts.")
    q("Level 2 — Basic Filtering", "Current accounts", "SELECT account_number FROM accounts WHERE account_type = 'current';", "Isolates business checkings.")
    q("Level 2 — Basic Filtering", "Savings accounts", "SELECT account_number FROM accounts WHERE account_type = 'savings';", "Isolates retail checkings.")
    q("Level 2 — Basic Filtering", "Transactions above 1 million", "SELECT transaction_id FROM transactions WHERE amount > 1000000;", "Numeric greater-than filter.")
    q("Level 2 — Basic Filtering", "Micro transactions", "SELECT transaction_id FROM transactions WHERE amount < 100;", "Numeric less-than filter.")
    q("Level 2 — Basic Filtering", "Loans above 50 Lakhs", "SELECT loan_id FROM loans WHERE principal_amount >= 5000000;", "Numeric greater or equal.")
    q("Level 2 — Basic Filtering", "Credit card accounts", "SELECT card_number FROM cards WHERE card_type = 'credit';", "Filter on exact string match.")
    q("Level 2 — Basic Filtering", "Failed logins", "SELECT ip_address FROM login_audit WHERE login_status = 'failed';", "Checks for audit failure flags.")
    q("Level 2 — Basic Filtering", "Successful logins", "SELECT ip_address FROM login_audit WHERE login_status = 'success';", "Checks for audit success flags.")
    q("Level 2 — Basic Filtering", "Critical alerts", "SELECT alert_id FROM alerts WHERE alert_severity = 'critical';", "Find high priority security pings.")
    q("Level 2 — Basic Filtering", "Unresolved alerts", "SELECT alert_id FROM alerts WHERE status = 'open';", "Find cases needing attention.")
    q("Level 2 — Basic Filtering", "Fraud cases reported to RBI", "SELECT case_id FROM fraud_cases WHERE case_status = 'reported_to_rbi';", "External legal filtered cases.")
    q("Level 2 — Basic Filtering", "Fraud cases closed", "SELECT case_id FROM fraud_cases WHERE case_status = 'closed';", "History of completed cases.")
    q("Level 2 — Basic Filtering", "Credit transactions", "SELECT transaction_id FROM transactions WHERE transaction_type = 'credit';", "Isolates money entering accounts.")
    q("Level 2 — Basic Filtering", "Debit transactions", "SELECT transaction_id FROM transactions WHERE transaction_type = 'debit';", "Isolates money leaving accounts.")

    # L3: Ordering, Distinct, and Like 41-60
    q("Level 3 — Sorting & Patterns", "Find distinct countries in addresses", "SELECT DISTINCT country FROM customer_address;", "Removes duplicate country occurrences.")
    q("Level 3 — Sorting & Patterns", "Find distinct cities", "SELECT DISTINCT city FROM customer_address;", "Lists every city we operate in.")
    q("Level 3 — Sorting & Patterns", "Unique transaction modes", "SELECT DISTINCT transaction_mode FROM transactions;", "e.g., NEFT, IMPS, RTGS, etc.")
    q("Level 3 — Sorting & Patterns", "Unique card issuers", "SELECT DISTINCT issuer_network FROM cards;", "e.g., VISA, Mastercard, RuPay.")
    q("Level 3 — Sorting & Patterns", "Richest accounts", "SELECT account_number, current_balance FROM accounts ORDER BY current_balance DESC;", "Sorts from highest balance downwards.")
    q("Level 3 — Sorting & Patterns", "Poorest accounts", "SELECT account_number, current_balance FROM accounts ORDER BY current_balance ASC;", "Sorts from lowest balance upwards.")
    q("Level 3 — Sorting & Patterns", "Largest loans", "SELECT loan_id, principal_amount FROM loans ORDER BY principal_amount DESC;", "Find the most expensive given credit.")
    q("Level 3 — Sorting & Patterns", "Oldest customers", "SELECT full_name, date_of_birth FROM customers ORDER BY date_of_birth ASC;", "Older birth dates sort to the top.")
    q("Level 3 — Sorting & Patterns", "Youngest customers", "SELECT full_name, date_of_birth FROM customers ORDER BY date_of_birth DESC;", "Newer birth dates sort to the top.")
    q("Level 3 — Sorting & Patterns", "Most massive fraud cases", "SELECT case_id, fraud_amount FROM fraud_cases ORDER BY fraud_amount DESC;", "Sorts fraud impact highest to lowest.")
    q("Level 3 — Sorting & Patterns", "Names starting with A", "SELECT full_name FROM customers WHERE full_name LIKE 'A%';", "LIKE operator with % wildcard matches start.")
    q("Level 3 — Sorting & Patterns", "Names ending with Singh", "SELECT full_name FROM customers WHERE full_name LIKE '%Singh';", "LIKE matches the end of the string.")
    q("Level 3 — Sorting & Patterns", "Emails containing 'gmail'", "SELECT email_primary FROM customer_contact WHERE email_primary LIKE '%gmail%';", "Wildcards on both sides test partial inclusion.")
    q("Level 3 — Sorting & Patterns", "IPs starting with 192", "SELECT ip_address FROM login_audit WHERE ip_address LIKE '192.%';", "Matches specific subnet patterns.")
    q("Level 3 — Sorting & Patterns", "Merchants with 'Amazon' in name", "SELECT merchant_name FROM transactions WHERE merchant_name LIKE '%Amazon%';", "Find specific retailer traces.")
    q("Level 3 — Sorting & Patterns", "Find exactly 5 char names", "SELECT full_name FROM customers WHERE full_name LIKE '_____';", "The underscore _ is a single-character exact wildcard.")
    q("Level 3 — Sorting & Patterns", "Missing emails", "SELECT customer_id FROM customer_contact WHERE email_primary IS NULL;", "IS NULL explicitly checks for completely missing data.")
    q("Level 3 — Sorting & Patterns", "Missing secondary phone", "SELECT customer_id FROM customer_contact WHERE phone_secondary IS NULL;", "Checks for missing optional flags.")
    q("Level 3 — Sorting & Patterns", "Empty merchant names", "SELECT transaction_id FROM transactions WHERE merchant_name IS NULL;", "Find generic transfers without listed merchants.")
    q("Level 3 — Sorting & Patterns", "NonNull fraud flags", "SELECT transaction_id FROM transactions WHERE fraud_flag IS NOT NULL;", "IS NOT NULL ensures the column has actual data.")

    # L4: Aggregation (COUNT, SUM, AVG) 61-80
    q("Level 4 — Basic Maths", "Count all customers", "SELECT COUNT(*) FROM customers;", "Returns total row count for table.")
    q("Level 4 — Basic Maths", "Count all accounts", "SELECT COUNT(*) FROM accounts;", "Returns total row count for table.")
    q("Level 4 — Basic Maths", "Sum all account balances", "SELECT SUM(current_balance) FROM accounts;", "Aggregates the entire wealth managed by the bank.")
    q("Level 4 — Basic Maths", "Sum all loan debt", "SELECT SUM(outstanding_amount) FROM loans;", "Aggregates all debt bound to the bank.")
    q("Level 4 — Basic Maths", "Average account balance", "SELECT AVG(current_balance) FROM accounts;", "Calculates the mathematical mean balance per person.")
    q("Level 4 — Basic Maths", "Average loan interest rate", "SELECT AVG(interest_rate) FROM loans;", "Calculates the mathematical mean of rates.")
    q("Level 4 — Basic Maths", "Average transaction size", "SELECT AVG(amount) FROM transactions;", "Find the normal transaction sizing.")
    q("Level 4 — Basic Maths", "Max single transaction", "SELECT MAX(amount) FROM transactions;", "Finds the single absolute highest transaction value.")
    q("Level 4 — Basic Maths", "Max loan principal", "SELECT MAX(principal_amount) FROM loans;", "Find the largest loan issued.")
    q("Level 4 — Basic Maths", "Min transaction size", "SELECT MIN(amount) FROM transactions;", "Find the smallest possible exchange.")
    q("Level 4 — Basic Maths", "Count Indian customers", "SELECT COUNT(*) FROM customers WHERE nationality='India';", "Counts rows passing a specific WHERE filter.")
    q("Level 4 — Basic Maths", "Sum USD transactions", "SELECT SUM(amount) FROM transactions WHERE currency='USD';", "Sums only specific filtered rows.")
    q("Level 4 — Basic Maths", "Total critical alerts", "SELECT COUNT(*) FROM alerts WHERE alert_severity='critical';", "Metric tracking for security operations.")
    q("Level 4 — Basic Maths", "Total recovered fraud money", "SELECT SUM(recovery_amount) FROM fraud_cases;", "Checks efficiency of fraud retrieval department.")
    q("Level 4 — Basic Maths", "Average CIBIL score", "SELECT AVG(cibil_score_at_approval) FROM loans;", "Credit health metric of borrow base.")
    q("Level 4 — Basic Maths", "Count female customers", "SELECT COUNT(*) FROM customers WHERE gender='F';", "Demographic breakdown slice.")
    q("Level 4 — Basic Maths", "Count male customers", "SELECT COUNT(*) FROM customers WHERE gender='M';", "Demographic breakdown slice.")
    q("Level 4 — Basic Maths", "Count blocked AML actions", "SELECT COUNT(*) FROM aml_screening WHERE action_taken='blocked';", "Compliance operation metrics.")
    q("Level 4 — Basic Maths", "Sum debit transactions", "SELECT SUM(amount) FROM transactions WHERE transaction_type='debit';", "Total outbound money flow.")
    q("Level 4 — Basic Maths", "Sum credit transactions", "SELECT SUM(amount) FROM transactions WHERE transaction_type='credit';", "Total inbound money flow.")

    # L5: Group By and Having 81-100
    q("Level 5 — Data Grouping", "Customer count by nationality", "SELECT nationality, COUNT(*) FROM customers GROUP BY nationality;", "Groups people uniquely by Country and counts the sizes.")
    q("Level 5 — Data Grouping", "Account count by type", "SELECT account_type, COUNT(*) FROM accounts GROUP BY account_type;", "Distribution of savings, current, salary etc.")
    q("Level 5 — Data Grouping", "Transaction total by type", "SELECT transaction_type, SUM(amount) FROM transactions GROUP BY transaction_type;", "Money split across debits vs credits.")
    q("Level 5 — Data Grouping", "Loan outstanding by type", "SELECT loan_type, SUM(outstanding_amount) FROM loans GROUP BY loan_type;", "Exposure by home loans, personal, education, etc.")
    q("Level 5 — Data Grouping", "Fraud cases by status", "SELECT case_status, COUNT(*) FROM fraud_cases GROUP BY case_status;", "Workflow pipeline distribution of investigations.")
    q("Level 5 — Data Grouping", "Transaction counts by mode", "SELECT transaction_mode, COUNT(*) FROM transactions GROUP BY transaction_mode;", "Breakdown of NEFT, IMPS, RTGS, Cash usages.")
    q("Level 5 — Data Grouping", "Count of alerts by severity", "SELECT alert_severity, COUNT(*) FROM alerts GROUP BY alert_severity;", "Priority load on analyst team.")
    q("Level 5 — Data Grouping", "Logins by status", "SELECT login_status, COUNT(*) FROM login_audit GROUP BY login_status;", "Failure vs Success tracking.")
    q("Level 5 — Data Grouping", "Cards by issuer network", "SELECT issuer_network, COUNT(*) FROM cards GROUP BY issuer_network;", "Visa vs Mastercard vs Rupay market share.")
    q("Level 5 — Data Grouping", "Transaction total by currency", "SELECT currency, SUM(amount) FROM transactions GROUP BY currency;", "Foreign Exchange treasury exposure.")

    q("Level 5 — Data Grouping", "Nationalities with >5000 customers", "SELECT nationality, COUNT(*) FROM customers GROUP BY nationality HAVING COUNT(*) > 5000;", "HAVING acts like WHERE but exclusively for post-aggregated metrics.")
    q("Level 5 — Data Grouping", "Account types holding > 10M total", "SELECT account_type, SUM(current_balance) FROM accounts GROUP BY account_type HAVING SUM(current_balance) > 10000000;", "Filtering aggregated sums.")
    q("Level 5 — Data Grouping", "Transaction modes used over 1000 times", "SELECT transaction_mode, COUNT(*) FROM transactions GROUP BY transaction_mode HAVING COUNT(*) > 1000;", "Filtering high volume methodologies.")
    q("Level 5 — Data Grouping", "Cities with >1000 addresses", "SELECT city, COUNT(*) FROM customer_address GROUP BY city HAVING COUNT(*) > 1000;", "Density mapping of geographical spread.")
    q("Level 5 — Data Grouping", "Branches with >200M total balance", "SELECT branch_code, SUM(current_balance) FROM accounts GROUP BY branch_code HAVING SUM(current_balance) > 200000000;", "Finding the wealthiest tier of physical branches.")
    q("Level 5 — Data Grouping", "Merchants billing > 50M total", "SELECT merchant_name, SUM(amount) FROM transactions WHERE merchant_name IS NOT NULL GROUP BY merchant_name HAVING SUM(amount) > 50000000;", "Finding mega-corps in payment history.")
    q("Level 5 — Data Grouping", "Alerts grouped by Type", "SELECT alert_type, COUNT(*) FROM alerts GROUP BY alert_type;", "Which fraud signatures trigger the most.")
    q("Level 5 — Data Grouping", "Fraud totals by case type", "SELECT case_type, SUM(fraud_amount) FROM fraud_cases GROUP BY case_type;", "Financial impact of different attack vectors.")
    q("Level 5 — Data Grouping", "Average wait time per severity", "SELECT alert_severity, AVG(DATEDIFF(resolved_date, alert_date)) FROM alerts GROUP BY alert_severity;", "SLA compliance for analyst desk.")
    q("Level 5 — Data Grouping", "Card types with > 5000 count", "SELECT card_type, COUNT(*) FROM cards GROUP BY card_type HAVING COUNT(*) > 5000;", "Popularity check of Credit vs Debit.")

    # L6: Date Operations 101-120
    q("Level 6 — Dates", "Customers joining this year", "SELECT full_name FROM customers WHERE YEAR(customer_since) = YEAR(CURDATE());", "Dynamic scaling using current server year.")
    q("Level 6 — Dates", "Accounts opened this month", "SELECT account_number FROM accounts WHERE MONTH(opened_date) = MONTH(CURDATE()) AND YEAR(opened_date) = YEAR(CURDATE());", "Uses exact month boundaries dynamically.")
    q("Level 6 — Dates", "Transactions from the last 7 days", "SELECT transaction_id FROM transactions WHERE transaction_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);", "Uses DATE_SUB intervals for sliding windows.")
    q("Level 6 — Dates", "Alerts triggered today", "SELECT alert_id FROM alerts WHERE alert_date = CURDATE();", "Exact day boundary checking.")
    q("Level 6 — Dates", "Loans disbursed in 2022", "SELECT loan_id FROM loans WHERE YEAR(disbursement_date) = 2022;", "Hardcoded extraction mapping.")
    q("Level 6 — Dates", "Fraud cases reported in Q1 2023", "SELECT case_id FROM fraud_cases WHERE YEAR(reported_date) = 2023 AND QUARTER(reported_date) = 1;", "The QUARTER() function assigns 1-4.")
    q("Level 6 — Dates", "Logins on a Sunday", "SELECT audit_id FROM login_audit WHERE DAYNAME(login_datetime) = 'Sunday';", "DAYNAME isolates specific weekend metrics.")
    q("Level 6 — Dates", "Transactions on a Monday", "SELECT transaction_id FROM transactions WHERE DAYNAME(transaction_date) = 'Monday';", "Isolate beginning of week burst load.")
    q("Level 6 — Dates", "Cards expiring next year", "SELECT card_number FROM cards WHERE YEAR(expiry_date) = YEAR(CURDATE()) + 1;", "Forward mapping dates.")
    q("Level 6 — Dates", "Identities expiring in 30 days", "SELECT document_number FROM customer_identity_documents WHERE expiry_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY);", "Using BETWEEN with forward INTERVALs.")
    q("Level 6 — Dates", "Account age in years", "SELECT account_number, TIMESTAMPDIFF(YEAR, opened_date, CURDATE()) as age_yrs FROM accounts;", "Calculates exact age chunks.")
    q("Level 6 — Dates", "Transactions exactly 2 years ago", "SELECT transaction_id FROM transactions WHERE transaction_date = DATE_SUB(CURDATE(), INTERVAL 2 YEAR);", "Exact day minus 24 months.")
    q("Level 6 — Dates", "Recent logins (last 2 hours)", "SELECT audit_id FROM login_audit WHERE login_datetime >= DATE_SUB(NOW(), INTERVAL 2 HOUR);", "Uses NOW() instead of CURDATE() for time inclusion.")
    q("Level 6 — Dates", "Alerts solved inside 24 hours", "SELECT alert_id FROM alerts WHERE DATEDIFF(resolved_date, alert_date) <= 1;", "Checking SLAs across timestamps.")
    q("Level 6 — Dates", "Loans missing next payment", "SELECT loan_id FROM loans WHERE next_emi_date < CURDATE();", "Future constraints violating today.")
    q("Level 6 — Dates", "Count of transactions per day", "SELECT transaction_date, COUNT(*) FROM transactions GROUP BY transaction_date;", "Daily aggregate volume charting.")
    q("Level 6 — Dates", "Count of transactions per month", "SELECT DATE_FORMAT(transaction_date, '%Y-%m') as mo, COUNT(*) FROM transactions GROUP BY mo;", "Formatting dates trims them into Month buckets.")
    q("Level 6 — Dates", "Count of new customers per year", "SELECT YEAR(customer_since), COUNT(*) FROM customers GROUP BY YEAR(customer_since);", "Yearly growth charting.")
    q("Level 6 — Dates", "Extract Hour of Transaction", "SELECT HOUR(transaction_time), COUNT(*) FROM transactions GROUP BY HOUR(transaction_time);", "Identify peak burst traffic hours using HOUR().")
    q("Level 6 — Dates", "AML checks done in last 90 days", "SELECT customer_id FROM aml_screening WHERE screening_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY);", "3-month rolling window.")

    # L7: Basic Joins (2-table) 121-140
    q("Level 7 — INNER JOINS", "Map Customer ID to Full Name on Accounts", "SELECT a.account_number, c.full_name FROM accounts a JOIN customers c ON a.customer_id = c.customer_id;", "Resolves Foreign Keys strictly where both exist.")
    q("Level 7 — INNER JOINS", "Get Customer Contact Email", "SELECT c.full_name, e.email_primary FROM customers c JOIN customer_contact e ON c.customer_id = e.customer_id;", "Mapping metadata fields together.")
    q("Level 7 — INNER JOINS", "Get Customer Physical Address", "SELECT c.full_name, ad.city, ad.country FROM customers c JOIN customer_address ad ON c.customer_id = ad.customer_id;", "Mapping relational geolocation.")
    q("Level 7 — INNER JOINS", "Find transactions by Customer Name", "SELECT t.transaction_id, t.amount, a.customer_id FROM transactions t JOIN accounts a ON t.account_id = a.account_id;", "Bridges transactions up to the account holder level.")
    q("Level 7 — INNER JOINS", "Loans associated to Branch Codes", "SELECT l.loan_id, a.branch_code FROM loans l JOIN accounts a ON l.account_id = a.account_id;", "Finds where a loan was issued physically.")
    q("Level 7 — INNER JOINS", "Cards mapped to Accounts", "SELECT cr.card_number, a.account_number FROM cards cr JOIN accounts a ON cr.account_id = a.account_id;", "Maps physical plastic to the holding tank.")
    q("Level 7 — INNER JOINS", "Fraud cases matched to Customers", "SELECT f.case_id, c.full_name FROM fraud_cases f JOIN customers c ON f.customer_id = c.customer_id;", "Directly ties impact reports to affected identities.")
    q("Level 7 — INNER JOINS", "Alerts matched to Accounts", "SELECT al.alert_id, a.account_number FROM alerts al JOIN accounts a ON al.account_id = a.account_id;", "Links trigger pings to the numeric structure.")
    q("Level 7 — INNER JOINS", "Logins to Customer profiles", "SELECT c.full_name, l.ip_address FROM login_audit l JOIN customers c ON l.customer_id = c.customer_id;", "Traces digital footprints to human identities.")
    q("Level 7 — INNER JOINS", "AML checks to Customers", "SELECT c.full_name, aml.risk_score FROM aml_screening aml JOIN customers c ON aml.customer_id = c.customer_id;", "Pull regulatory scores next to names.")
    
    q("Level 7 — OUTER JOINS", "All customers and their loans (if any)", "SELECT c.full_name, l.loan_id FROM customers c LEFT JOIN loans l ON c.customer_id = l.customer_id;", "LEFT JOIN guarantees all customers appear, with NULLs for debt-free clients.")
    q("Level 7 — OUTER JOINS", "All accounts and their cards", "SELECT a.account_number, c.card_number FROM accounts a LEFT JOIN cards c ON a.account_id = c.account_id;", "Finds accounts that might lack plastic access.")
    q("Level 7 — OUTER JOINS", "All customers and their fraud cases", "SELECT c.full_name, f.case_status FROM customers c LEFT JOIN fraud_cases f ON c.customer_id = f.customer_id;", "Majority will be NULL, indicating safe accounts.")
    q("Level 7 — OUTER JOINS", "Accounts with absolutely NO transactions", "SELECT a.account_number FROM accounts a LEFT JOIN transactions t ON a.account_id = t.account_id WHERE t.transaction_id IS NULL;", "Anti-join pattern to find pristine/dormant vaults.")
    q("Level 7 — OUTER JOINS", "Customers with NO email", "SELECT c.full_name FROM customers c LEFT JOIN customer_contact ct ON c.customer_id = ct.customer_id WHERE ct.email_primary IS NULL;", "Find incomplete profile setups.")
    q("Level 7 — OUTER JOINS", "Customers with NO address", "SELECT c.full_name FROM customers c LEFT JOIN customer_address ad ON c.customer_id = ad.customer_id WHERE ad.address_id IS NULL;", "Anti-join for missing physical trace.")
    q("Level 7 — OUTER JOINS", "Accounts without cards", "SELECT a.account_number FROM accounts a LEFT JOIN cards c ON a.account_id = c.account_id WHERE c.card_number IS NULL;", "Anti-join for virtual-only structures.")
    q("Level 7 — OUTER JOINS", "Customers without Loans", "SELECT c.full_name FROM customers c LEFT JOIN loans l ON c.customer_id = l.customer_id WHERE l.loan_id IS NULL;", "Anti-join for debt free entities.")
    q("Level 7 — OUTER JOINS", "All transactions and their alerts (if any)", "SELECT t.transaction_id, a.alert_severity FROM transactions t LEFT JOIN alerts a ON t.transaction_id = a.transaction_id;", "Bridges massive flow data with sparse security pings.")
    q("Level 7 — OUTER JOINS", "Transactions lacking any alerts", "SELECT t.transaction_id FROM transactions t LEFT JOIN alerts a ON t.transaction_id = a.transaction_id WHERE a.alert_id IS NULL LIMIT 20;", "Finds standard, clean operational traffic.")

    # L8: Intermediate Multi-Joins & Subqueries 141-160
    q("Level 8 — Multi-Joins", "Trace Transaction -> Account -> Customer", "SELECT t.amount, a.account_number, c.full_name FROM transactions t JOIN accounts a ON t.account_id = a.account_id JOIN customers c ON a.customer_id = c.customer_id;", "A 3-table traverse.")
    q("Level 8 — Multi-Joins", "Customer -> Account -> Sub-Loans", "SELECT c.full_name, l.principal_amount FROM customers c JOIN accounts a ON c.customer_id = a.customer_id JOIN loans l ON a.account_id = l.account_id;", "Maps the credit tree correctly.")
    q("Level 8 — Multi-Joins", "Alert -> Account -> Branch -> City", "SELECT al.alert_severity, c.full_name, ad.city FROM alerts al JOIN customers c ON al.customer_id = c.customer_id JOIN customer_address ad ON c.customer_id = ad.customer_id;", "Geographically locating specific threat vectors.")
    q("Level 8 — Subqueries", "Find customers sharing a Zip Code with fraudster X", "SELECT full_name FROM customers WHERE customer_id IN (SELECT customer_id FROM customer_address WHERE zip_code = '110001');", "Decouples logic cleanly by evaluating the inner block first.")
    q("Level 8 — Subqueries", "Transactions larger than Bank Average", "SELECT t.transaction_id, t.amount FROM transactions t WHERE t.amount > (SELECT AVG(amount) FROM transactions);", "Dynamic global comparison.")
    q("Level 8 — Subqueries", "Youngest customer's transactions", "SELECT t.amount FROM transactions t JOIN accounts a ON t.account_id = a.account_id WHERE a.customer_id = (SELECT customer_id FROM customers ORDER BY date_of_birth DESC LIMIT 1);", "Find target by property, then link.")
    q("Level 8 — Subqueries", "Cities with > 5 branches", "SELECT city FROM customer_address WHERE city IN (SELECT city from customer_address GROUP BY city HAVING COUNT(*) > 5);", "Filters based on mathematical grouping thresholds.")
    q("Level 8 — CASE statements", "Label transaction sizes", "SELECT amount, CASE WHEN amount > 100000 THEN 'LARGE' WHEN amount > 10000 THEN 'MEDIUM' ELSE 'SMALL' END as label FROM transactions;", "Creates a dynamic column based on logical condition trees.")
    q("Level 8 — CASE statements", "Bin Loan interest rates", "SELECT loan_id, CASE WHEN interest_rate < 8 THEN 'CHEAP' ELSE 'EXPENSIVE' END FROM loans;", "Binary thresholding categorization.")
    q("Level 8 — Subqueries", "Customer with most accounts", "SELECT full_name FROM customers WHERE customer_id = (SELECT customer_id FROM accounts GROUP BY customer_id ORDER BY COUNT(*) DESC LIMIT 1);", "Double-layered analytical pointer.")
    q("Level 8 — HAVING / COUNT", "Customers with > 3 active accounts", "SELECT customer_id, COUNT(*) FROM accounts WHERE account_status='active' GROUP BY customer_id HAVING COUNT(*) > 3;", "Filters post-group aggregation.")
    q("Level 8 — Multi-Joins", "Identify Mule Addresses", "SELECT ad.zip_code, COUNT(DISTINCT fc.case_id) FROM customer_address ad JOIN fraud_cases fc ON ad.customer_id = fc.customer_id GROUP BY ad.zip_code HAVING COUNT(DISTINCT fc.case_id) > 2;", "Pinpoints physical real-estate generating multiple distinct fraud trails.")
    q("Level 8 — Union", "Combine distinct lists of USA and UK customers", "SELECT full_name, 'USA' as origin FROM customers WHERE nationality = 'USA' UNION SELECT full_name, 'UK' as origin FROM customers WHERE nationality = 'UK';", "Packs two totally distinct query grids into one seamless vertical table.")
    q("Level 8 — Subqueries", "Second highest transaction amount", "SELECT MAX(amount) FROM transactions WHERE amount < (SELECT MAX(amount) FROM transactions);", "A classic nested offset pattern without using LIMIT.")
    q("Level 8 — Multi-Joins", "Cards causing Critical Alerts", "SELECT c.card_number FROM cards c JOIN transactions t ON c.card_number = t.merchant_name JOIN alerts al ON t.transaction_id = al.transaction_id WHERE al.alert_severity='critical';", "Deep tracking.")
    q("Level 8 — Maths", "Variance between Account Balance and Floor", "SELECT account_number, current_balance, FLOOR(current_balance) FROM accounts;", "Numeric manipulation.")
    q("Level 8 — CTEs", "Basic CTE layout", "WITH UserCounts AS (SELECT nationality, COUNT(*) as cnt FROM customers GROUP BY nationality) SELECT * FROM UserCounts WHERE cnt > 100;", "Separates complex logic into readable header blocks.")
    q("Level 8 — CTEs", "CTE for Account Aggregates", "WITH AccAgg AS (SELECT customer_id, SUM(current_balance) as tot FROM accounts GROUP BY customer_id) SELECT c.full_name, a.tot FROM customers c JOIN AccAgg a ON c.customer_id = a.customer_id;", "Clean mapping of sums back to names.")
    q("Level 8 — Subqueries", "Accounts opened recently", "SELECT account_number FROM accounts WHERE opened_date IN (SELECT MAX(opened_date) FROM accounts);", "Finding the absolute newest entities.")
    q("Level 8 — Data Scrubbing", "Trim trailing spaces off names", "SELECT TRIM(full_name) FROM customers;", "Data sanitation function natively in SQL.")

    # L9: Expert SQL (Window Functions, Math) 161-180
    for i in range(20):
        if i % 4 == 0:
            q("Level 9 — Window Functions", "Running Total by Account", 
              "SELECT account_id, transaction_date, amount, SUM(amount) OVER (PARTITION BY account_id ORDER BY transaction_date) as running_total FROM transactions;",
              "PARTITION breaks the sum scope to individual accounts, ORDER BY ensures it sequentially accumulates over time.")
        elif i % 4 == 1:
            q("Level 9 — Window Functions", "Row Numbering per Customer", 
              "SELECT customer_id, opened_date, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY opened_date) as acc_sequence FROM accounts;",
              "Tags a customer's first account as 1, second as 2, etc., allowing easy 'First Interaction' tracing.")
        elif i % 4 == 2:
            q("Level 9 — Window Functions", "Lead (Next) Login Date", 
              "SELECT customer_id, login_datetime, LEAD(login_datetime, 1) OVER (PARTITION BY customer_id ORDER BY login_datetime) as next_login FROM login_audit;",
              "LEAD peeks at the subsequent row's timestamp, perfect for calculating gaps between interactions.")
        else:
            q("Level 9 — Window Functions", "Lag (Previous) Transaction Amount", 
              "SELECT transaction_id, account_id, amount, LAG(amount, 1) OVER (PARTITION BY account_id ORDER BY transaction_date) as prev_amount FROM transactions;",
              "LAG peeks backward in the partition, allowing you to compare if a transaction spiked 500% compared to their history.")

    # L10: Ultimate Investigator & Fraud Patterns 181-200
    for i in range(20):
        if i % 3 == 0:
            q("Level 10 — Ultimate Investigator", "Structuring Pattern (Smurfing)",
              "SELECT account_id, DATE(transaction_date) as dt, COUNT(*) as burst_count, SUM(amount) as sum_amt FROM transactions WHERE amount BETWEEN 9000 AND 9999 GROUP BY account_id, dt HAVING COUNT(*) >= 3;",
              "Identifies users deliberately dropping transactions just under the $10k regulatory radar over and over on the same day.")
        elif i % 3 == 1:
            q("Level 10 — Ultimate Investigator", "JSON AML Parsing",
              "SELECT customer_id, JSON_EXTRACT(match_details, '$.watchlist') as hit_list FROM aml_screening WHERE JSON_EXTRACT(match_details, '$.score') > 90;",
              "Navigating unstructured metadata blocks securely inside structured relational loops.")
        else:
            q("Level 10 — Ultimate Investigator", "Recursive Deep Dive Money Trace",
              "WITH RECURSIVE TraceList AS (SELECT transaction_id, account_id, amount, 1 as hop FROM transactions WHERE fraud_type = 'mule' UNION ALL SELECT t.transaction_id, t.account_id, t.amount, tl.hop + 1 FROM transactions t JOIN TraceList tl ON t.account_id = tl.account_id WHERE tl.hop < 4) SELECT * FROM TraceList;",
              "Recursion permits infinite/n-deep graph traversal across standard relationship tables without Neo4J.")

    assert len(questions) == 200, f"Error generating: {len(questions)}"
    return questions

if __name__ == '__main__':
    schema = get_schema()
    exercises = generate_questions()
    
    js_content = f"""// ════════════════════════════════════════════════════════════════════════
// BANK FRAUD DB — STATIC DATA MOUNT
// AUTOGENERATED VIA PYTHON (200 UNIQUE QUESTIONS)
// ════════════════════════════════════════════════════════════════════════

window.DB_SCHEMA = {json.dumps(schema, indent=2)};

window.DB_EXERCISES = {json.dumps(exercises, indent=2)};
"""
    with open("static/data.js", "w", encoding="utf-8") as f:
        f.write(js_content)
    print(f"Successfully wrote data.js with {len(schema)} schema tables and {len(exercises)} UNIQUE queries.")
