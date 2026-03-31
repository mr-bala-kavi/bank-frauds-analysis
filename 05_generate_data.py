"""
05_generate_data.py
────────────────────────────────────────────────────────────────────────
Bank Fraud Analyst Training DB — Main Data Generator
MySQL 8.0+  |  Target: 1,00,000 customers + all related data
────────────────────────────────────────────────────────────────────────
Run:
    pip install mysql-connector-python tqdm
    python 05_generate_data.py

Requires:
    gen_config.py
    gen_core.py
    gen_transactions.py
────────────────────────────────────────────────────────────────────────
"""
import sys, time, random
from datetime import datetime

# ── Third-party (install if missing) ────────────────────────────────────
try:
    import mysql.connector
    from mysql.connector import Error
except ImportError:
    sys.exit("❌  mysql-connector-python not installed.\n    Run: pip install mysql-connector-python tqdm")

try:
    from tqdm import tqdm
except ImportError:
    sys.exit("❌  tqdm not installed.\n    Run: pip install mysql-connector-python tqdm")

from gen_config import DB, BATCH
from gen_core   import (generate_customers, generate_documents,
                         generate_contacts, generate_addresses,
                         generate_accounts, generate_cards,
                         generate_loans, generate_repayments,
                         generate_beneficiaries, generate_kyc_audit,
                         generate_aml, generate_logins)
from gen_transactions import (generate_transactions, inject_fraud_patterns,
                               generate_fraud_cases_extra)

# ── DB connect ──────────────────────────────────────────────────────────
def connect():
    print("\n🔗  Connecting to MySQL …")
    try:
        conn = mysql.connector.connect(**DB)
        print(f"✅  Connected — MySQL {conn.get_server_info()}")
        return conn
    except Error as e:
        sys.exit(f"❌  Connection failed: {e}\n    Check DB credentials in gen_config.py")

# ── Batch insert helper ──────────────────────────────────────────────────
def bulk_insert(cur, table, cols, rows, desc=""):
    if not rows: return
    ph  = "(" + ",".join(["%s"]*len(cols)) + ")"
    sql = f"INSERT IGNORE INTO {table} ({','.join(cols)}) VALUES {ph}"
    n   = len(rows)
    with tqdm(total=n, desc=f"  ↳ {desc or table}", ncols=80,
              bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}]") as bar:
        for i in range(0, n, BATCH):
            chunk = rows[i:i+BATCH]
            cur.executemany(sql, chunk)
            bar.update(len(chunk))

# ── Row-count summary ─────────────────────────────────────────────────
def print_summary(cur):
    tables = [
        "customers","customer_identity_documents","customer_contact",
        "customer_address","accounts","transactions","cards","loans",
        "loan_repayments","beneficiaries","alerts","fraud_cases",
        "kyc_audit_log","login_audit","aml_screening",
    ]
    print("\n" + "═"*54)
    print(f"{'TABLE':<35} {'ROWS':>10}")
    print("─"*54)
    for t in tables:
        cur.execute(f"SELECT COUNT(*) FROM {t}")
        cnt = cur.fetchone()[0]
        print(f"  {t:<33} {cnt:>10,}")
    print("─"*54)

    # Disk usage
    cur.execute("""
        SELECT table_name,
               ROUND((data_length + index_length)/1024/1024, 2) AS size_mb
        FROM   information_schema.tables
        WHERE  table_schema = 'bank_fraud_db'
        ORDER  BY (data_length + index_length) DESC
    """)
    print(f"\n{'TABLE':<35} {'SIZE (MB)':>10}")
    print("─"*54)
    for row in cur.fetchall():
        print(f"  {row[0]:<33} {row[1]:>10}")
    print("═"*54)


# ════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════
def main():
    t0   = time.time()
    conn = connect()
    conn.autocommit = False
    cur  = conn.cursor()

    cur.execute("USE bank_fraud_db")
    cur.execute("SET foreign_key_checks = 0")
    cur.execute("SET unique_checks     = 0")
    cur.execute("SET sql_mode          = ''")
    conn.commit()

    print("\n" + "═"*54)
    print("   BANK FRAUD DB — DATA GENERATION (1 Lakh Customers)")
    print("═"*54)

    # ── 1. CUSTOMERS ─────────────────────────────────────────────────
    print("\n[1/15] Generating customers …")
    customers = generate_customers(100_000)
    cols = ["customer_id","full_name","first_name","last_name","salutation",
            "date_of_birth","gender","nationality","country_of_residence",
            "occupation","annual_income","kyc_status","kyc_verified_date",
            "pep_flag","risk_category","customer_since","is_active"]
    bulk_insert(cur, "customers", cols, customers, "customers")
    conn.commit()
    print(f"  ✅  {len(customers):,} customers inserted")

    # ── 2. IDENTITY DOCUMENTS ──────────────────────────────────────
    print("\n[2/15] Generating identity documents …")
    docs = generate_documents(customers)
    bulk_insert(cur, "customer_identity_documents",
                ["customer_id","document_type","document_number",
                 "issued_country","issued_date","expiry_date","is_primary"],
                docs, "identity docs")
    conn.commit()
    print(f"  ✅  {len(docs):,} documents inserted")

    # ── 3. CONTACTS ───────────────────────────────────────────────
    print("\n[3/15] Generating contacts …")
    contacts = generate_contacts(customers)
    bulk_insert(cur, "customer_contact",
                ["customer_id","phone_primary","phone_secondary",
                 "email_primary","email_secondary","preferred_contact_method",
                 "do_not_call","last_contact_date"],
                contacts, "contacts")
    conn.commit()
    print(f"  ✅  {len(contacts):,} contacts inserted")

    # ── 4. ADDRESSES ──────────────────────────────────────────────
    print("\n[4/15] Generating addresses …")
    addresses = generate_addresses(customers)
    bulk_insert(cur, "customer_address",
                ["customer_id","address_type","address_line1","address_line2",
                 "city","state","postal_code","country","is_current",
                 "from_date","to_date"],
                addresses, "addresses")
    conn.commit()
    print(f"  ✅  {len(addresses):,} addresses inserted")

    # ── 5. ACCOUNTS ───────────────────────────────────────────────
    print("\n[5/15] Generating accounts …")
    accounts_rows, customer_accounts = generate_accounts(customers)
    bulk_insert(cur, "accounts",
                ["account_id","customer_id","account_number","account_type",
                 "branch_code","ifsc_code","currency","current_balance",
                 "available_balance","minimum_balance","account_status",
                 "opened_date","closed_date","last_transaction_date",
                 "overdraft_limit","interest_rate","joint_holder_customer_id"],
                accounts_rows, "accounts")
    conn.commit()
    print(f"  ✅  {len(accounts_rows):,} accounts inserted")

    # ── 6. TRANSACTIONS (normal) ───────────────────────────────────
    print("\n[6/15] Generating 1,00,000 transactions …")
    txn_rows = generate_transactions(accounts_rows, n=100_000)
    bulk_insert(cur, "transactions",
                ["transaction_id","account_id","transaction_date",
                 "transaction_time","value_date","transaction_type",
                 "transaction_mode","amount","currency",
                 "balance_after_transaction","description","narration",
                 "reference_number","beneficiary_account_id","beneficiary_name",
                 "beneficiary_bank","beneficiary_ifsc","channel",
                 "merchant_name","merchant_category_code","location_city",
                 "location_country","ip_address","device_id",
                 "is_suspicious","fraud_flag","fraud_type"],
                txn_rows, "transactions (normal)")
    conn.commit()
    print(f"  ✅  {len(txn_rows):,} normal transactions inserted")

    # ── 7. FRAUD PATTERN TRANSACTIONS ────────────────────────────
    print("\n[7/15] Injecting fraud patterns …")
    fraud_txns, fraud_alerts, fraud_cases = inject_fraud_patterns(accounts_rows)

    bulk_insert(cur, "transactions",
                ["transaction_id","account_id","transaction_date",
                 "transaction_time","value_date","transaction_type",
                 "transaction_mode","amount","currency",
                 "balance_after_transaction","description","narration",
                 "reference_number","beneficiary_account_id","beneficiary_name",
                 "beneficiary_bank","beneficiary_ifsc","channel",
                 "merchant_name","merchant_category_code","location_city",
                 "location_country","ip_address","device_id",
                 "is_suspicious","fraud_flag","fraud_type"],
                fraud_txns, "fraud-pattern transactions")
    conn.commit()
    print(f"  ✅  {len(fraud_txns):,} fraud-pattern transactions injected")

    # ── 8. CARDS ──────────────────────────────────────────────────
    print("\n[8/15] Generating cards …")
    cards = generate_cards(accounts_rows, customer_accounts)
    bulk_insert(cur, "cards",
                ["card_id","account_id","customer_id","card_number_masked",
                 "card_type","card_network","card_status","issue_date",
                 "expiry_date","credit_limit","outstanding_amount",
                 "daily_atm_limit","daily_pos_limit","daily_online_limit",
                 "international_transactions_enabled","contactless_enabled",
                 "last_used_date","last_used_location"],
                cards, "cards")
    conn.commit()
    print(f"  ✅  {len(cards):,} cards inserted")

    # ── 9. LOANS ──────────────────────────────────────────────────
    print("\n[9/15] Generating loans …")
    loans = generate_loans(customers, customer_accounts)
    bulk_insert(cur, "loans",
                ["loan_id","customer_id","account_id","loan_type",
                 "principal_amount","sanctioned_amount","disbursed_amount",
                 "outstanding_amount","interest_rate","interest_type",
                 "tenure_months","remaining_months","emi_amount","emi_due_date",
                 "loan_status","loan_start_date","loan_end_date",
                 "collateral_type","collateral_value","purpose_of_loan",
                 "cibil_score_at_approval","co_applicant_customer_id"],
                loans, "loans")
    conn.commit()
    print(f"  ✅  {len(loans):,} loans inserted")

    # ── 10. LOAN REPAYMENTS ───────────────────────────────────────
    print("\n[10/15] Generating loan repayments …")
    repayments = generate_repayments(loans)
    bulk_insert(cur, "loan_repayments",
                ["loan_id","due_date","paid_date","emi_amount","amount_paid",
                 "principal_component","interest_component","penalty_charges",
                 "outstanding_after_payment","payment_status","bounce_reason",
                 "days_past_due"],
                repayments, "loan repayments")
    conn.commit()
    print(f"  ✅  {len(repayments):,} repayments inserted")

    # ── 11. BENEFICIARIES ─────────────────────────────────────────
    print("\n[11/15] Generating beneficiaries …")
    beneficiaries = generate_beneficiaries(customers, customer_accounts)
    bulk_insert(cur, "beneficiaries",
                ["customer_id","beneficiary_name","beneficiary_account_number",
                 "beneficiary_ifsc","beneficiary_bank_name","beneficiary_type",
                 "added_date","is_active","max_transfer_limit_per_day",
                 "total_transferred_lifetime"],
                beneficiaries, "beneficiaries")
    conn.commit()
    print(f"  ✅  {len(beneficiaries):,} beneficiaries inserted")

    # ── 12. ALERTS (fraud pattern + extra to reach ~25K) ─────────
    print("\n[12/15] Generating alerts …")
    from gen_core import rnd_date as _rd
    from datetime import date

    def fill_alerts(needed, accounts_rows):
        """Top up alerts with generic entries to hit target."""
        types  = ["large_transaction","unusual_pattern","foreign_transaction",
                  "multiple_failed_attempts","velocity_breach","after_hours_transaction"]
        sevs   = ["low","medium","high","critical"]
        sev_w  = [30,40,20,10]
        stats  = ["open","under_review","resolved","false_positive","escalated"]
        stat_w = [35,25,20,15,5]
        rows   = []
        for _ in range(needed):
            ar = random.choice(accounts_rows)
            aid, cid = ar[0], ar[1]
            atype = random.choice(types)
            sev   = random.choices(sevs, weights=sev_w)[0]
            dt    = _rd(date(2022,1,1), date(2025,3,1))
            stat  = random.choices(stats, weights=stat_w)[0]
            rdate = _rd(dt, date(2025,3,29)) if stat in ("resolved","false_positive") else None
            rows.append((
                cid, aid, None, atype, sev,
                f"Automated alert: {atype.replace('_',' ').title()} detected on account",
                dt, f"{random.randint(0,23):02d}:{random.randint(0,59):02d}:00",
                stat, random.choice(ANALYSTS) if stat in ("under_review","resolved") else None,
                None, rdate,
            ))
        return rows

    from gen_config import ANALYSTS
    all_alerts = list(fraud_alerts) + fill_alerts(25000 - len(fraud_alerts), accounts_rows)

    bulk_insert(cur, "alerts",
                ["customer_id","account_id","transaction_id","alert_type",
                 "alert_severity","alert_message","alert_date","alert_time",
                 "status","assigned_to_analyst","resolution_notes","resolved_date"],
                all_alerts, "alerts")
    conn.commit()
    print(f"  ✅  {len(all_alerts):,} alerts inserted")

    # ── 13. FRAUD CASES ───────────────────────────────────────────
    print("\n[13/15] Generating fraud cases …")
    accounts_slim = [(r[0], r[1]) for r in accounts_rows]
    extra_cases   = generate_fraud_cases_extra(accounts_slim,
                                               len(fraud_cases), 2500)
    all_cases     = list(fraud_cases) + extra_cases
    bulk_insert(cur, "fraud_cases",
                ["customer_id","account_id","case_type","case_status",
                 "fraud_amount","reported_date","confirmed_date","closed_date",
                 "reported_by","investigation_notes","recovery_amount","fir_number"],
                all_cases, "fraud cases")
    conn.commit()
    print(f"  ✅  {len(all_cases):,} fraud cases inserted")

    # ── 14. KYC AUDIT LOG ─────────────────────────────────────────
    print("\n[14/15] Generating KYC audit log …")
    kyc_logs = generate_kyc_audit(customers)
    bulk_insert(cur, "kyc_audit_log",
                ["customer_id","action","changed_fields","changed_by",
                 "change_date","remarks"],
                kyc_logs, "KYC audit log")
    conn.commit()
    print(f"  ✅  {len(kyc_logs):,} KYC log entries inserted")

    # ── 15. LOGIN AUDIT ───────────────────────────────────────────
    print("\n[15/15] Generating login audit (1,00,000 records) …")
    logins = generate_logins(customers, customer_accounts, n=100_000)
    bulk_insert(cur, "login_audit",
                ["customer_id","login_datetime","login_channel","ip_address",
                 "device_id","device_type","os","browser","location_city",
                 "location_country","login_status","failure_reason",
                 "session_duration_minutes"],
                logins, "login audit")
    conn.commit()
    print(f"  ✅  {len(logins):,} login records inserted")

    # ── AML SCREENING ─────────────────────────────────────────────
    print("\n[+]  Generating AML screening (1,00,000 records) …")
    aml = generate_aml(customers)
    bulk_insert(cur, "aml_screening",
                ["customer_id","screening_date","screening_type",
                 "watchlist_matched","match_details","risk_score",
                 "action_taken","analyst_notes"],
                aml, "AML screening")
    conn.commit()
    print(f"  ✅  {len(aml):,} AML records inserted")

    # ── Re-enable checks ───────────────────────────────────────────
    cur.execute("SET foreign_key_checks = 1")
    cur.execute("SET unique_checks     = 1")
    conn.commit()

    # ── Summary ────────────────────────────────────────────────────
    elapsed = time.time() - t0
    print(f"\n⏱️   Total time: {elapsed/60:.1f} min ({elapsed:.0f}s)\n")
    print_summary(cur)
    print("\n🎉  Database ready! Open MySQL Workbench and query bank_fraud_db\n")

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
