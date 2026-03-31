# 🏦 Bank Fraud Analyst Training Database

A complete MySQL database with **1,00,000 customers**, realistic Indian banking data, 10 injected fraud patterns, 50 graded SQL exercises, and **20 real-time fraud detection queries**.

---

## 📁 Files — Run in This Order

| # | File | Purpose |
|---|------|---------|
| 1 | `01_schema.sql` | Creates database + all 15 tables |
| 2 | `05_generate_data.py` | Populates all data (run BEFORE indexes) |
| 3 | `02_indexes.sql` | Creates 75 performance indexes |
| 4 | `03_views.sql` | Creates 7 analytical views |
| 5 | `04_functions.sql` | Creates functions + stored procedures |
| 6 | `06_verify_data.sql` | Verify row counts + data quality |
| 7 | `ANALYST_SQL_EXERCISES.sql` | 50 exercises for analyst training |
| 8 | `FRAUD_DETECTION_REALTIME.sql` | **20 real-time fraud detection queries** |

> **Why load data before indexes?** Bulk inserts are 5–10× faster without indexes.  
> Indexes are built once after all rows are in. 

---

## ⚙️ Prerequisites

### 1. MySQL 8.0+
Download from https://dev.mysql.com/downloads/mysql/  
Make sure MySQL is running and accessible.

### 2. Python 3.9+
Download from https://www.python.org/downloads/

### 3. Install Python Libraries
```bash
pip install mysql-connector-python tqdm sqlparse
```

---

## 🚀 Setup — Step by Step

### Step 1 — Configure DB Connection
Open `gen_config.py` and update the DB block at the top:
```python
DB = dict(
    host     = "localhost",
    port     = 3306,
    user     = "root",         # your MySQL username
    password = "root",         # your MySQL password
    database = "bank_fraud_db"
)
```

### Step 2 — Create the Schema
Run in MySQL Workbench (File → Open SQL Script → `01_schema.sql` → ⚡ Execute All):
```sql
-- Or from mysql CLI:
mysql -u root -p < 01_schema.sql
```

### Step 3 — Generate & Load Data
Open a terminal/PowerShell in the project folder:
```powershell
cd d:\bro\sql-data
python 05_generate_data.py
```
You'll see a progress bar for each table. Estimated time: **5–15 minutes**

### Step 4 — Create Indexes
```sql
source 02_indexes.sql
```

### Step 5 — Create Views
```sql
source 03_views.sql
```

### Step 6 — Create Functions & Stored Procedures
```sql
source 04_functions.sql
```

### Step 7 — Verify
```sql
source 06_verify_data.sql
```

---

## 🔍 Fraud Patterns Injected

| # | Pattern | Count | Exercise | Real-Time Query |
|---|---------|-------|----------|----------------|
| 1 | Structuring (below ₹2L threshold) | 50 customers | Q11 | Block 1 |
| 2 | Velocity fraud (10+ txns/hour) | 30 accounts | Q12 | Block 2 |
| 3 | Dormant account revival | 100 accounts | Q13 | Block 3 |
| 4 | Card cloning (2 countries, <1h) | 15 accounts | Q15 | Block 4 |
| 5 | Geo anomaly (login India, txn UAE) | 20 accounts | Q9 | Block 5 |
| 6 | Salary diversion | 25 accounts | Q16 | Block 6 |
| 7 | Mule accounts (50+ senders) | 20 accounts | Q14, Q49 | Block 7 |
| 8 | Loan fraud (fake income) | 15 customers | Q29 | Block 14 |
| 9 | Round-trip transactions (A→B→C→A) | 20 chains | Q17, Q38 | Block 8 |
| 10 | Round amount pattern | 40 customers | Q9 | Block 10 |

---

## 🚨 Real-Time Fraud Detection (`FRAUD_DETECTION_REALTIME.sql`)

Open `FRAUD_DETECTION_REALTIME.sql` in MySQL Workbench to run live fraud scans on your data.

### Fraud Pattern Queries

| Block | Pattern | What It Finds |
|-------|---------|--------------|
| **Block 1** | Structuring / Smurfing | 3+ txns between ₹1.8L–₹2L on the same day |
| **Block 2** | Velocity Fraud | 10+ debits within any 1-hour window |
| **Block 3** | Dormant Revival | Account silent 365+ days → sudden large credit |
| **Block 4** | Card Cloning | Same card used in 2 countries within 4 hours |
| **Block 5** | Geo Anomaly | Login from India → transaction in UAE within 30 min |
| **Block 6** | Salary Diversion | Salary credited → 90%+ sent out within 2 hours |
| **Block 7** | Mule Account | Receiving from 20+ unique senders per month |
| **Block 8** | Round Trip | Money sent and returned within 72 hours |
| **Block 9** | After-Hours | Large transactions between midnight and 4 AM |
| **Block 10** | Round Amount | 3+ exact ₹10K/₹50K/₹1L transfers |
| **Block 11** | Brute Force Login | 3+ failed logins → successful login |
| **Block 12** | PEP Transactions | Politically exposed persons moving >₹50K |
| **Block 13** | Z-Score Anomaly | Transactions >3 std deviations from normal |
| **Block 14** | Loan Fraud | CIBIL <650 + loan >3× income + <6 months history |
| **Block 15** | New Beneficiary | >₹5L sent to newly added beneficiary within 3 days |
| **Block 16** | AML Watchlist | Customers flagged in AML screening |

### Dashboard Queries

| Block | What It Shows |
|-------|--------------|
| **Block 17** | Overdue fraud cases open >30 days |
| **Block 18** | Morning dashboard — all critical/high open alerts |
| **Block 19** | Full fraud metrics summary (counts, amounts, frozen accounts) |
| **Block 20** | Recursive money trail — trace cash A → B → C → D (4 hops) |

### Quick Actions After Finding Fraud

```sql
-- Freeze a suspicious account immediately
CALL sp_freeze_account('account-uuid-here', 'Mule account pattern detected');

-- Get real-time velocity for an account
CALL sp_get_account_velocity('account-uuid-here', 24);

-- Close a confirmed fraud case
CALL sp_close_fraud_case(42, 'Confirmed structuring', 590000.00);

-- Run today's alert generation
CALL sp_generate_daily_alerts();
```

---

## 🌐 Web Portal (`webapp/`)

A fully offline SQL practice portal — no server needed, runs in any browser.

### Generate the Portal
```powershell
cd d:\bro\sql-data\webapp
pip install sqlparse
python generate_static_portal.py
```
This connects to your live MySQL DB and writes `static/data.js` with:
- All 15 table schemas with columns + keys
- 200 categorized SQL questions (Level 1–10)

### Open the Portal
Simply open `webapp/static/index.html` in your browser.

### Portal Features
- 📋 **Exercises tab** — 200 questions from basic SELECT to recursive CTEs
- 🗄️ **DB Schema tab** — All 15 tables with expandable column lists (PK/FK highlighted)
- 📖 **About tab** — Database overview and usage guide
- 🔍 Search bar to filter questions by keyword
- 📋 One-click **Copy SQL** button for every query
- 📈 Progress tracker — tracks how many questions you've viewed

---

## 🗄️ Connecting via MySQL Workbench

1. Open **MySQL Workbench**
2. Click ➕ → New Connection
3. Fill in: Hostname `localhost`, Port `3306`, Username `root`
4. Test connection → OK
5. Double-click connection → select `bank_fraud_db` from schemas panel

### Key Views
```sql
SELECT * FROM v_customer_360 LIMIT 10;
SELECT * FROM v_suspicious_transactions LIMIT 20;
SELECT * FROM v_dormant_accounts LIMIT 20;
SELECT * FROM v_high_risk_customers LIMIT 20;
SELECT * FROM v_loan_npa LIMIT 20;
SELECT * FROM v_daily_transaction_summary LIMIT 20;
```

---

## 📝 SQL Exercises (`ANALYST_SQL_EXERCISES.sql`)

Open in MySQL Workbench. Exercises are grouped into 6 levels:

| Level | Questions | Topic |
|-------|-----------|-------|
| **Level 1** | Q1–Q5 | Basic customer & account queries |
| **Level 2** | Q6–Q10 | Transaction analysis |
| **Level 3** | Q11–Q20 | Fraud detection patterns |
| **Level 4** | Q21–Q30 | Aggregation & regulatory reporting |
| **Level 5** | Q31–Q40 | Advanced — CTEs, window functions, recursive queries |
| **Level 6** | Q41–Q50 | Analyst workflow — morning dashboard, STR, case management |

Each question has the answer immediately below it in a comment block.

---

## 🛠️ Useful Objects

### Functions
```sql
-- Customer risk score (0-100)
SELECT fn_get_customer_risk_score('customer-uuid-here');

-- Check if a transaction is suspicious
SELECT fn_flag_suspicious_transaction('transaction-uuid-here');
```

### Stored Procedures
```sql
-- Get account velocity (txns in last N hours)
CALL sp_get_account_velocity('account-uuid-here', 24);

-- Freeze an account
CALL sp_freeze_account('account-uuid-here', 'Fraud investigation');

-- Close a fraud case
CALL sp_close_fraud_case(42, 'Confirmed money laundering', 50000.00);

-- Generate today's alerts
CALL sp_generate_daily_alerts();
```

---

## 🔧 Troubleshooting

| Problem | Fix |
|---------|-----|
| `Access denied` | Update password in `gen_config.py` |
| `Unknown database` | Run `01_schema.sql` first |
| `Module not found` | Run `pip install mysql-connector-python tqdm sqlparse` |
| `Packet too large` | Add `max_allowed_packet=256M` to `my.cnf` |
| Slow generation | Normal — progress bar shows ETA |
| `Duplicate entry` | Safe to ignore — script uses `INSERT IGNORE` |
| Portal shows no data | Run `generate_static_portal.py` to regenerate `data.js` |

---

## 📂 Full File Reference

```
sql-data/
├── 01_schema.sql                    # Database + 15 tables
├── 02_indexes.sql                   # 75 performance indexes
├── 03_views.sql                     # 7 analytical views
├── 04_functions.sql                 # 2 functions + 4 stored procedures
├── 05_generate_data.py              # Main data generator (orchestrator)
├── 06_verify_data.sql               # Post-load verification queries
├── ANALYST_SQL_EXERCISES.sql        # 50 graded exercises with answers
├── FRAUD_DETECTION_REALTIME.sql     # 20 real-time fraud detection queries ← NEW
├── gen_config.py                    # DB config, name pools, constants
├── gen_core.py                      # Core data generators (customers, loans, etc.)
├── gen_transactions.py              # Transaction + fraud pattern generator
├── README.md                        # This file
└── webapp/
    ├── generate_static_portal.py    # Generates the web portal data
    └── static/
        ├── index.html               # The SQL practice web portal
        └── data.js                  # Auto-generated (schema + 200 questions)
```

---

*Built for bank fraud analyst training. All data is synthetic and randomly generated.*
