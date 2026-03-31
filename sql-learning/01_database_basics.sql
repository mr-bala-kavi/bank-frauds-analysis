-- ═══════════════════════════════════════════════════════════════════════════
-- 📘 TOPIC 01: DATABASE BASICS
-- Learn: What is a database, how to create, select, and drop databases
-- Using: bank_fraud_db
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────
-- 1.1 SHOW ALL DATABASES ON THE SERVER
-- ─────────────────────────────────────────────────────────────────────────
SHOW DATABASES;
-- Lists every database available on your MySQL server

-- ─────────────────────────────────────────────────────────────────────────
-- 1.2 CREATE A NEW DATABASE
-- ─────────────────────────────────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS bank_fraud_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- CHARACTER SET defines which characters can be stored (utf8mb4 = all unicode + emoji)
-- COLLATE defines how strings are sorted and compared

-- ─────────────────────────────────────────────────────────────────────────
-- 1.3 SELECT (USE) A DATABASE TO WORK ON
-- ─────────────────────────────────────────────────────────────────────────
USE bank_fraud_db;
-- Everything after this command runs inside bank_fraud_db

-- ─────────────────────────────────────────────────────────────────────────
-- 1.4 SHOW ALL TABLES INSIDE THE CURRENT DATABASE
-- ─────────────────────────────────────────────────────────────────────────
SHOW TABLES;
-- Lists all 15 tables: customers, accounts, transactions, loans, etc.

-- ─────────────────────────────────────────────────────────────────────────
-- 1.5 SEE THE STRUCTURE (COLUMNS) OF A TABLE
-- ─────────────────────────────────────────────────────────────────────────
DESCRIBE customers;
-- Shows: column name, data type, NULL allowed, key type, default value

DESCRIBE accounts;
DESCRIBE transactions;

-- Alternative syntax:
SHOW COLUMNS FROM fraud_cases;

-- ─────────────────────────────────────────────────────────────────────────
-- 1.6 SEE THE CREATE STATEMENT OF A TABLE (reverse-engineer schema)
-- ─────────────────────────────────────────────────────────────────────────
SHOW CREATE TABLE customers\G
-- Shows the full CREATE TABLE statement used to build the table

-- ─────────────────────────────────────────────────────────────────────────
-- 1.7 CHECK DATABASE SIZE (storage used)
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    table_schema                        AS database_name,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)  AS size_mb
FROM information_schema.tables
WHERE table_schema = 'bank_fraud_db'
GROUP BY table_schema;

-- ─────────────────────────────────────────────────────────────────────────
-- 1.8 CHECK ROW COUNT OF ALL TABLES
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    table_name,
    table_rows         AS approximate_row_count
FROM information_schema.tables
WHERE table_schema = 'bank_fraud_db'
ORDER BY table_rows DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- 1.9 VIEW ALL COLUMN METADATA FOR THE DATABASE
-- ─────────────────────────────────────────────────────────────────────────
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_key
FROM information_schema.columns
WHERE table_schema = 'bank_fraud_db'
ORDER BY table_name, ordinal_position;

-- ─────────────────────────────────────────────────────────────────────────
-- 1.10 DROP A DATABASE (⚠️ DANGER — deletes everything permanently)
-- ─────────────────────────────────────────────────────────────────────────
-- DROP DATABASE IF EXISTS bank_fraud_db;  -- COMMENTED OUT — do not run!
-- Use DROP DATABASE only when you want to completely remove the database.
