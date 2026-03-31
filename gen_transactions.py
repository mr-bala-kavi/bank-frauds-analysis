"""
gen_transactions.py — Transaction + fraud-pattern generation
Generates 1,00,000 transactions with 10 fraud patterns injected.
"""
import random, uuid, string
from datetime import date, datetime, timedelta
from gen_config import *

def new_uuid(): return str(uuid.uuid4())

def rnd_date(start, end):
    if end <= start:
        return start
    delta = (end - start).days
    if delta <= 0: return start
    return start + timedelta(days=random.randint(0, delta))

def rnd_time():
    return f"{random.randint(0,23):02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}"

def rnd_ref():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=16))

def rnd_narration(mode, amount, benef=None):
    templates = {
        "NEFT": f"NEFT/{rnd_ref()[:8]}/{benef or 'TRANSFER'}",
        "RTGS": f"RTGS/{rnd_ref()[:8]}/{benef or 'TRANSFER'}",
        "IMPS": f"IMPS/{rnd_ref()[:8]}/{random.randint(10000,99999)}",
        "UPI":  f"UPI/{random.choice(['ravi@okaxis','priya@ybl','amit@oksbi','suresh@okhdfc'])}/Pay",
        "ATM_CASH": f"ATM CASH WDL/{random.choice(['SBI','HDFC','ICICI'])} ATM/{random.randint(100,999)}",
        "BRANCH_CASH": "BRANCH CASH WITHDRAWAL",
        "CHEQUE": f"CHQ/{random.randint(100000,999999)}/{benef or 'SELF'}",
        "ONLINE_TRANSFER": f"ONLINE TRF TO {benef or 'BENEFICIARY'}",
        "CARD_PURCHASE": f"POS PURCHASE/{random.choice(['AMAZON','FLIPKART','ZOMATO','SWIGGY','MYNTRA','D-MART','BIG BAZAAR'])}",
        "EMI": f"EMI/{random.randint(100000,999999)}/LOAN",
        "INTEREST": "INTEREST CREDITED",
        "CHARGES": "MAINTENANCE CHARGES",
        "SALARY_CREDIT": f"SALARY/{rnd_ref()[:8]}/COMPANY",
        "REFUND": f"REFUND/{rnd_ref()[:8]}",
    }
    return templates.get(mode, f"TXN/{rnd_ref()[:8]}")


MERCHANTS = ["Amazon","Flipkart","Zomato","Swiggy","Myntra","Grofers","BigBasket",
             "Ola","Uber","PayTM","PhonePe","Google Pay","Airtel","Jio","Reliance Retail",
             "D-Mart","Big Bazaar","Spencer's","IRCTC","MakeMyTrip","Booking.com"]
MCC_CODES  = ["5411","5812","5912","5999","7011","4111","5732","5045","7372","8099"]


def generate_transactions(accounts_rows, n=100_000):
    """Generate n normal transactions across all accounts."""
    rows = []
    accounts = [(r[0], r[1], r[5], r[6], r[7]) for r in accounts_rows]
    # (account_id, customer_id, ifsc, currency, balance)
    active_accts = [a for a in accounts if True]

    modes    = TXN_MODES
    mode_wt  = [15,5,20,25,8,3,3,5,7,3,2,1,1,2]
    channels = CHANNELS
    chan_wt  = [30,25,15,10,10,10]
    ttypes   = ["credit","debit"]

    city_pool = [c for c,s in INDIAN_CITIES]

    for _ in range(n):
        acct   = random.choice(active_accts)
        aid    = acct[0]
        cur    = acct[3]
        bal    = float(acct[4])
        mode   = random.choices(modes, weights=mode_wt)[0]
        ch     = random.choices(channels, weights=chan_wt)[0]
        ttype  = "credit" if mode in ("INTEREST","SALARY_CREDIT","REFUND") else (
                 "debit"  if mode in ("ATM_CASH","BRANCH_CASH","EMI","CHARGES","CARD_PURCHASE") else
                 random.choice(ttypes))
        amt    = round(random.uniform(100, 200000), 2)
        dt     = rnd_date(date(2022,1,1), date(2025,3,1))
        tm     = rnd_time()
        bal_after = round(bal + amt if ttype=="credit" else max(bal - amt, 0), 2)
        benef  = f"{random.choice(HINDI_FIRST+TAMIL_FIRST)} {random.choice(INDIAN_LAST)}"
        bbank  = random.choice(BANKS)[0]
        bifsc  = rnd_ifsc(random.choice(BANKS)[1])
        city   = random.choice(city_pool)
        ip     = rnd_ip() if ch in ("mobile_app","internet_banking","api") else None
        dev    = ''.join(random.choices(string.hexdigits.lower(), k=12)) if ip else None
        mname  = random.choice(MERCHANTS) if mode in ("CARD_PURCHASE","ONLINE_TRANSFER") else None
        mcc    = random.choice(MCC_CODES) if mname else None
        narr   = rnd_narration(mode, amt, benef)

        rows.append((
            new_uuid(), aid, dt, tm, dt, ttype, mode, amt, cur, bal_after,
            narr, narr, rnd_ref(), None, benef, bbank, bifsc,
            ch, mname, mcc, city, "India", ip, dev,
            False, False, None,
        ))
    return rows


def inject_fraud_patterns(accounts_rows):
    """Generate 10 fraud pattern datasets. Returns (txn_rows, alert_rows, case_rows)."""
    txn_rows   = []
    alert_rows = []
    case_rows  = []

    accounts   = [(r[0], r[1]) for r in accounts_rows]  # (aid, cid)
    sample_all = random.sample(accounts, min(300, len(accounts)))

    city_pool  = [c for c,s in INDIAN_CITIES]

    def make_txn(aid, dt, tm, ttype, mode, amt, suspicious=True, fraud=False, ftype=None,
                 city="Chennai", country="India", ip=None, benef=None, bbank=None, bifsc=None):
        return (
            new_uuid(), aid, dt, tm, dt, ttype, mode, amt, "INR",
            round(random.uniform(1000,500000),2),  # balance_after
            f"FRAUD_TEST/{ftype or 'SUSPICIOUS'}", f"FRAUD_TEST/{ftype or 'SUSPICIOUS'}",
            rnd_ref(), None,
            benef or f"{random.choice(HINDI_FIRST)} {random.choice(INDIAN_LAST)}",
            bbank or "HDFC Bank", bifsc or rnd_ifsc("HDFC"),
            "mobile_app", None, None, city, country, ip or rnd_ip(),
            ''.join(random.choices(string.hexdigits.lower(), k=12)),
            suspicious, fraud, ftype,
        )

    def make_alert(cid, aid, atype, severity, msg):
        dt = rnd_date(date(2022,6,1), date(2025,3,1))
        return (
            cid, aid, None, atype, severity, msg,
            dt, f"{random.randint(0,23):02d}:{random.randint(0,59):02d}:00",
            random.choice(["open","under_review","escalated"]),
            random.choice(ANALYSTS), None, None,
        )

    def make_case(cid, aid, ctype, amount, ftype_desc):
        rdate = rnd_date(date(2022,6,1), date(2025,1,1))
        return (
            cid, aid, ctype,
            random.choice(["reported","investigating","confirmed"]),
            round(amount,2), rdate, None, None,
            random.choice(["customer","system","analyst"]),
            ftype_desc, 0, None,
        )

    # ── PATTERN 1: STRUCTURING (50 customers, 3+ txns just below ₹2L) ──
    struct_accts = sample_all[:50]
    for aid, cid in struct_accts:
        dt = rnd_date(date(2022,1,1), date(2025,1,1))
        for _ in range(random.randint(3, 6)):
            amt = round(random.uniform(185000, 199000), 2)
            txn = make_txn(aid, dt, rnd_time(), "debit", "NEFT", amt,
                           suspicious=True, fraud=True, ftype="structuring")
            txn_rows.append(txn)
        alert_rows.append(make_alert(cid, aid, "structuring_suspicion", "high",
            "Multiple transactions just below ₹2L reporting threshold detected"))
        case_rows.append(make_case(cid, aid, "money_laundering", 590000,
            "Structuring/smurfing: 3+ transactions below ₹2L threshold in single day"))

    # ── PATTERN 2: VELOCITY FRAUD (30 accounts, 10+ txns within 1 hour) ──
    vel_accts = sample_all[50:80]
    for aid, cid in vel_accts:
        dt  = rnd_date(date(2022,1,1), date(2025,1,1))
        h   = random.randint(1,22)
        for m in range(random.randint(10,15)):
            tm  = f"{h:02d}:{(m*3)%60:02d}:00"
            amt = round(random.uniform(500, 5000), 2)
            txn = make_txn(aid, dt, tm, "debit", "UPI", amt,
                           suspicious=True, fraud=True, ftype="velocity_fraud")
            txn_rows.append(txn)
        alert_rows.append(make_alert(cid, aid, "velocity_breach", "critical",
            "10+ transactions within 1 hour — possible account draining"))
        case_rows.append(make_case(cid, aid, "account_takeover", 45000,
            "Velocity fraud: rapid small debits draining account within 1 hour"))

    # ── PATTERN 3: DORMANT ACCOUNT REVIVAL (100 accounts) ──
    dormant_accts = random.sample(accounts, min(100, len(accounts)))
    for aid, cid in dormant_accts:
        # Old dormant date
        old_dt = date(2021, random.randint(1,12), random.randint(1,28))
        old_txn = make_txn(aid, old_dt, rnd_time(), "credit", "NEFT", 500000,
                            suspicious=False, fraud=False)
        txn_rows.append(old_txn)
        # Revival credit
        rev_dt = rnd_date(date(2024,6,1), date(2025,3,1))
        rev_txn = make_txn(aid, rev_dt, rnd_time(), "credit", "NEFT",
                            round(random.uniform(300000,1000000),2),
                            suspicious=True, fraud=True, ftype="dormant_revival")
        txn_rows.append(rev_txn)
        # Immediate withdrawal
        wd_tm = f"{random.randint(0,23):02d}:{random.randint(0,5):02d}:00"
        wd_txn = make_txn(aid, rev_dt, wd_tm, "debit", "IMPS",
                           round(random.uniform(250000,900000),2),
                           suspicious=True, fraud=True, ftype="dormant_revival")
        txn_rows.append(wd_txn)
        alert_rows.append(make_alert(cid, aid, "dormant_account_activity", "high",
            "Dormant account (2+ years inactive) suddenly received large credit followed by withdrawal"))

    # ── PATTERN 4: CARD CLONING (15 cards — same card, 2 countries in 3h) ──
    card_accts = sample_all[80:95]
    for aid, cid in card_accts:
        dt  = rnd_date(date(2023,1,1), date(2025,3,1))
        h   = random.randint(10,20)
        txn1 = make_txn(aid, dt, f"{h:02d}:10:00", "debit", "CARD_PURCHASE",
                         round(random.uniform(5000,50000),2),
                         suspicious=True, fraud=True, ftype="card_cloning",
                         city="Chennai", country="India")
        txn2 = make_txn(aid, dt, f"{h:02d}:55:00", "debit", "CARD_PURCHASE",
                         round(random.uniform(5000,50000),2),
                         suspicious=True, fraud=True, ftype="card_cloning",
                         city="London", country="UK")
        txn_rows.extend([txn1, txn2])
        alert_rows.append(make_alert(cid, aid, "card_cloning_suspicion", "critical",
            "Same card used in India and UK within 45 minutes — possible card cloning"))
        case_rows.append(make_case(cid, aid, "card_fraud", 55000,
            "Card cloning: simultaneous transactions in two countries"))

    # ── PATTERN 5: GEO ANOMALY (20 accounts — login India, txn UAE in 10 min) ──
    geo_accts = sample_all[95:115]
    for aid, cid in geo_accts:
        dt  = rnd_date(date(2022,6,1), date(2025,1,1))
        txn = make_txn(aid, dt, "14:05:00", "debit", "ONLINE_TRANSFER",
                        round(random.uniform(50000,500000),2),
                        suspicious=True, fraud=True, ftype="geo_anomaly",
                        city="Dubai", country="UAE")
        txn_rows.append(txn)
        alert_rows.append(make_alert(cid, aid, "geo_anomaly", "critical",
            "Login from India at 14:00, transaction in UAE at 14:05 — impossible travel"))

    # ── PATTERN 6: SALARY DIVERSION (25 accounts) ──
    sal_accts = random.sample(accounts, min(25, len(accounts)))
    for aid, cid in sal_accts:
        dt  = rnd_date(date(2022,1,1), date(2025,1,1))
        sal_amt = round(random.uniform(50000,200000),2)
        sal_txn = make_txn(aid, dt, "09:00:00", "credit", "SALARY_CREDIT", sal_amt,
                            suspicious=False, fraud=False)
        imm_txn = make_txn(aid, dt, "09:12:00", "debit", "IMPS", sal_amt*0.99,
                            suspicious=True, fraud=True, ftype="salary_diversion")
        txn_rows.extend([sal_txn, imm_txn])
        alert_rows.append(make_alert(cid, aid, "unusual_pattern", "high",
            "Salary credit immediately diverted to unregistered beneficiary"))

    # ── PATTERN 7: MULE ACCOUNTS (20 accounts receive from 50+ sources) ──
    mule_accts = random.sample(accounts, min(20, len(accounts)))
    other_accts = random.sample(accounts, min(60, len(accounts)))
    for aid, cid in mule_accts:
        dt  = rnd_date(date(2022,1,1), date(2025,1,1))
        sources = random.sample(other_accts, min(52, len(other_accts)))
        for src_aid, _ in sources[:30]:
            amt = round(random.uniform(2000,15000),2)
            txn = make_txn(aid, dt + timedelta(days=random.randint(0,30)),
                            rnd_time(), "credit", "IMPS", amt,
                            suspicious=True, fraud=True, ftype="mule_account")
            txn_rows.append(txn)
        # Forward all to one destination
        total = sum(2000 for _ in range(30))
        fwd   = make_txn(aid, dt + timedelta(days=31), rnd_time(),
                          "debit", "RTGS", round(total*0.98,2),
                          suspicious=True, fraud=True, ftype="mule_account")
        txn_rows.append(fwd)
        alert_rows.append(make_alert(cid, aid, "unusual_pattern", "critical",
            "Mule account pattern: receiving from 50+ sources, forwarding to single account"))
        case_rows.append(make_case(cid, aid, "money_laundering", total,
            "Mule account: aggregates funds from multiple sources and forwards onward"))

    # ── PATTERN 8: ROUND AMOUNT PATTERN (40 customers) ──
    round_accts = random.sample(accounts, min(40, len(accounts)))
    for aid, cid in round_accts:
        amounts = [10000,50000,100000]
        for _ in range(random.randint(3,6)):
            dt  = rnd_date(date(2022,1,1), date(2025,1,1))
            amt = random.choice(amounts)
            txn = make_txn(aid, dt, rnd_time(), "debit", "NEFT", float(amt),
                            suspicious=True, fraud=False, ftype=None)
            txn_rows.append(txn)
        alert_rows.append(make_alert(cid, aid, "round_amount_pattern", "medium",
            "Repeated exact round-number transactions of ₹10K/₹50K/₹1L"))

    # ── PATTERN 9: ROUND TRIP (A→B→C→A within 48h) ──
    if len(accounts) >= 3:
        for i in range(20):
            a_help = random.sample(accounts, 3)
            a_aid, a_cid = a_help[0]
            b_aid, b_cid = a_help[1]
            c_aid, c_cid = a_help[2]
            dt  = rnd_date(date(2022,6,1), date(2025,1,1))
            amt = round(random.uniform(100000, 500000), 2)
            t1  = make_txn(a_aid, dt, "10:00:00", "debit", "RTGS", amt,
                            suspicious=True, fraud=True, ftype="round_trip",
                            benef=f"Account B", bbank="HDFC Bank")
            t2  = make_txn(b_aid, dt+timedelta(hours=12), "22:00:00",
                            "debit", "RTGS", round(amt*0.99,2),
                            suspicious=True, fraud=True, ftype="round_trip")
            t3  = make_txn(c_aid, dt+timedelta(hours=36), "10:00:00",
                            "debit", "NEFT", round(amt*0.98,2),
                            suspicious=True, fraud=True, ftype="round_trip")
            txn_rows.extend([t1,t2,t3])
            alert_rows.append(make_alert(a_cid, a_aid, "unusual_pattern", "high",
                "Round-trip transaction detected: funds returned to origin within 48 hours"))

    # ── PATTERN 10: LOAN FRAUD (15 customers, big loan tiny history) ──
    for i in range(15):
        if i >= len(accounts): break
        aid, cid = accounts[i]
        alert_rows.append(make_alert(cid, aid, "unusual_pattern", "high",
            "Loan fraud indicator: high loan amount approved with minimal prior transaction history"))
        case_rows.append(make_case(cid, aid, "loan_fraud",
            round(random.uniform(500000,3000000),2),
            "Suspected loan fraud: inflated income documents, minimal banking history"))

    return txn_rows, alert_rows, case_rows


def generate_fraud_cases_extra(accounts, existing_count=0, target=2500):
    """Generate additional fraud cases to reach ~2500 total."""
    rows = []
    needed = target - existing_count
    if needed <= 0: return rows
    ctypes  = FRAUD_TYPES
    cstats  = ["reported","investigating","confirmed","closed_no_fraud","reported_to_rbi","filed_fir"]
    cstat_w = [20,30,25,10,10,5]
    reps    = ["customer","system","analyst","branch","regulator"]
    for _ in range(needed):
        aid, cid = random.choice(accounts)
        ctype    = random.choice(ctypes)
        cstat    = random.choices(cstats, weights=cstat_w)[0]
        amt      = round(random.uniform(1000,500000),2)
        rdate    = rnd_date(date(2022,1,1), date(2025,1,1))
        cdate    = rdt if (rdt:=rnd_date(rdate, date(2025,3,1))) and cstat not in ("reported","investigating") else None
        fir      = f"FIR/{random.randint(100,9999)}/2024" if cstat=="filed_fir" else None
        rows.append((
            cid, aid, ctype, cstat, amt, rdate, cdate, cdate,
            random.choice(reps),
            f"Case opened for {ctype.replace('_',' ').title()} investigation",
            round(amt*random.uniform(0,0.4),2), fir,
        ))
    return rows
