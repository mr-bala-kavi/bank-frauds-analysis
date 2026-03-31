# 📚 SQL Learning — Complete Topic Guide
**Database:** `bank_fraud_db` | **Engine:** MySQL 8.0+

All SQL examples in this folder use the **Bank Fraud DB** schema  
(customers, accounts, transactions, loans, fraud_cases, alerts, etc.)

---

## 📁 File Index

| File | Topic | Key Commands |
|------|-------|-------------|
| `01_database_basics.sql` | Database Basics | SHOW DATABASES, CREATE DATABASE, USE, SHOW TABLES, DESCRIBE |
| `02_relational_concepts.sql` | Relational Concepts | Primary Key, Foreign Key, 1:1, 1:M, M:M relationships |
| `03_ddl_commands.sql` | DDL — Data Definition | CREATE TABLE, ALTER TABLE, DROP TABLE, TRUNCATE |
| `04_dml_commands.sql` | DML — Data Manipulation | INSERT, UPDATE, DELETE, INSERT IGNORE, UPSERT |
| `05_dql_select.sql` | DQL — SELECT | SELECT, aliases, calculations, string/date functions, DISTINCT |
| `06_filtering_data.sql` | Filtering Data | WHERE, AND, OR, NOT, IN, BETWEEN, LIKE, LIMIT |
| `07_sorting_and_grouping.sql` | Sorting & Grouping | ORDER BY, GROUP BY, HAVING |
| `08_aggregate_functions.sql` | Aggregate Functions | COUNT, SUM, AVG, MIN, MAX, ROLLUP |
| `09_joins.sql` | Joins | INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL JOIN, SELF JOIN, CROSS JOIN |
| `10_subqueries.sql` | Subqueries | Scalar, Column (IN), Correlated, EXISTS, Derived Tables |
| `11_indexes.sql` | Indexes | CREATE INDEX, COMPOSITE INDEX, FULLTEXT, EXPLAIN, DROP INDEX |
| `12_constraints.sql` | Constraints | PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL, CHECK, DEFAULT |
| `13_views.sql` | Views | CREATE VIEW, OR REPLACE, DROP VIEW |
| `14_stored_procedures.sql` | Stored Procedures | CREATE PROCEDURE, IN/OUT/INOUT params, IF, LOOP, CURSOR |
| `15_triggers.sql` | Triggers | BEFORE/AFTER INSERT/UPDATE/DELETE, NEW, OLD, SIGNAL |
| `16_transactions.sql` | Transactions | START TRANSACTION, COMMIT, ROLLBACK, SAVEPOINT, AUTOCOMMIT |
| `17_normalization.sql` | Normalization | 1NF, 2NF, 3NF, Partial Dependency, Transitive Dependency |
| `18_database_design.sql` | Database Design | Naming conventions, data types, ER design, best practices |
| `19_window_functions.sql` | Window Functions | ROW_NUMBER, RANK, DENSE_RANK, SUM OVER, LAG, LEAD, NTILE |
| `20_cte.sql` | CTE | WITH, Multiple CTEs, Recursive CTE, CTE vs Subquery vs View |
| `21_case_statements.sql` | CASE Statements | Simple CASE, Searched CASE, PIVOT, conditional aggregation |

---

## 🚀 How to Use

1. Open any file in **MySQL Workbench**
2. Make sure `bank_fraud_db` is loaded (`USE bank_fraud_db;` is at the top of each file)
3. Run queries **section by section** — each section has a comment header
4. Files with `CREATE TABLE demo_*` clean up after themselves with `DROP TABLE` at the end

---

## 📖 Recommended Learning Order

```
Beginner:
  01 → 02 → 03 → 04 → 05 → 06 → 07 → 08

Intermediate:
  09 → 10 → 11 → 12 → 13

Advanced:
  14 → 15 → 16 → 17 → 18

Expert:
  19 → 20 → 21
```

---

## 🗄️ Schema Quick Reference

```
customers          → 100,000 customers (customer_id PK)
  ├── customer_contact    → emails, phones (1:1)
  ├── customer_address    → city, state, country (1:1)
  ├── accounts            → bank accounts (1:M)
  │     ├── cards         → debit/credit cards (1:M)
  │     └── transactions  → all money movements (1:M)
  ├── loans               → loan records (1:M)
  ├── fraud_cases         → fraud investigations (1:M)
  ├── alerts              → auto fraud alerts (1:M)
  ├── aml_screening       → AML compliance records (1:M)
  └── login_audit         → login events (1:M)
branches           → physical branch offices
beneficiaries      → saved payee accounts
```

---

## ⚡ Key columns to remember

| Table | Primary Key | Important Columns |
|-------|-------------|-------------------|
| customers | customer_id | full_name, nationality, risk_category, annual_income |
| accounts | account_id | account_number, account_type, account_status, current_balance |
| transactions | transaction_id | amount, transaction_type, transaction_date, fraud_flag |
| loans | loan_id | principal_amount, interest_rate, cibil_score_at_approval |
| fraud_cases | case_id | case_type, case_status, fraud_amount |
| alerts | alert_id | alert_severity, alert_type, status |
| login_audit | audit_id | login_status, login_datetime, ip_address |

---

*All examples are read-safe on real data. Destructive examples (UPDATE/DELETE on real tables) are commented out.*
