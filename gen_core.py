"""
gen_core.py — Core data generation logic for bank_fraud_db
Generates: customers, documents, contacts, addresses, accounts,
           cards, loans, repayments, beneficiaries, kyc_audit,
           aml_screening, login_audit
"""
import random, uuid, string
from datetime import date, datetime, timedelta
from gen_config import *

def new_uuid(): return str(uuid.uuid4())

def rnd_date(start, end):
    if end <= start:
        return start
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

def generate_customers(n=100_000):
    rows = []
    nation_dist = (
        [("India",60),("UK",10),("USA",10),("UAE",8),("Singapore",5),("Other",7)]
    )
    nat_pool = []
    for nat, pct in nation_dist:
        nat_pool.extend([nat]*pct)

    salutations = ["Mr","Mrs","Ms","Dr","Prof"]
    kyc_choices = ["verified","pending","rejected","expired"]
    kyc_wt      = [70,15,7,8]
    risk_choices= ["low","medium","high","very_high"]
    risk_wt     = [55,28,12,5]

    for i in range(n):
        nat = random.choice(nat_pool)
        cid = new_uuid()

        # Pick name pool
        if nat == "India":
            region = random.choice(["Tamil","Telugu","Hindi","Marathi","Bengali","Punjabi"])
            fp = {"Tamil":TAMIL_FIRST,"Telugu":TELUGU_FIRST,"Hindi":HINDI_FIRST,
                  "Marathi":MARATHI_FIRST,"Bengali":BENGALI_FIRST,"Punjabi":PUNJABI_FIRST}[region]
            first = random.choice(fp)
            last  = random.choice(INDIAN_LAST)
        elif nat == "UK":
            first, last = random.choice(UK_FIRST), random.choice(UK_LAST)
        elif nat == "USA":
            first, last = random.choice(USA_FIRST), random.choice(USA_LAST)
        elif nat == "UAE":
            first, last = random.choice(UAE_FIRST), random.choice(UAE_LAST)
        elif nat == "Singapore":
            first, last = random.choice(SG_FIRST), random.choice(SG_LAST)
        else:
            first = random.choice(UK_FIRST + USA_FIRST)
            last  = random.choice(OTHERS_LAST)

        # Inject duplicate names (realistic)
        if i in range(0,5):   first,last = "Ravi","Kumar"
        elif i in range(5,10): first,last = "Amit","Sharma"
        elif i in range(10,14): first,last = "Priya","Gupta"
        elif i in range(14,18): first,last = "Suresh","Patel"

        sal    = random.choice(salutations)
        gender = "F" if sal in ("Mrs","Ms") else ("M" if sal in ("Mr","Dr","Prof") else random.choice("MF"))
        dob    = rnd_date(date(1945,1,1), date(2003,12,31))
        occ    = random.choice(OCCUPATIONS)
        lo,hi  = INCOME_BY_OCC.get(occ,(100000,1000000))
        income = round(random.uniform(lo,hi) if hi>0 else 0, 2)
        kyc    = random.choices(kyc_choices, weights=kyc_wt)[0]
        kyc_dt = rnd_date(date(2018,1,1), date(2025,1,1)) if kyc=="verified" else None
        pep    = random.random() < 0.005
        risk   = random.choices(risk_choices, weights=risk_wt)[0]
        since  = rnd_date(date(2010,1,1), date(2024,6,1))

        rows.append((
            cid, f"{first} {last}", first, last, sal, dob, gender,
            nat, nat if nat!="Other" else random.choice(["Germany","France","Australia","Japan","Brazil"]),
            occ, income, kyc, kyc_dt, pep, risk, since, True,
        ))
    return rows


def generate_documents(customers):
    rows = []
    for cid, _, _, _, _, _, _, nat, _, _, _, kyc, _, _, _, _, _ in customers:
        types = []
        if nat == "India":
            types = ["aadhaar","pan"]
            if random.random() < 0.4: types.append("passport")
        elif nat == "UK":
            types = ["passport","driving_license"]
        elif nat == "USA":
            types = ["ssn","passport"]
            if random.random() < 0.4: types.append("driving_license")
        elif nat == "UAE":
            types = ["emirates_id","passport"]
        elif nat == "Singapore":
            types = ["nic","passport"]
        else:
            types = ["passport"]
            if random.random() < 0.3: types.append("driving_license")

        for j, dt in enumerate(types):
            if dt == "aadhaar":  num = rnd_aadhaar()
            elif dt == "pan":    num = rnd_pan()
            elif dt == "ssn":    num = f"{random.randint(100,999)}-{random.randint(10,99)}-{random.randint(1000,9999)}"
            elif dt == "nic":    num = ''.join(random.choices(string.ascii_uppercase+string.digits, k=9))
            elif dt == "emirates_id": num = f"784-{random.randint(1000,9999)}-{random.randint(1000000,9999999)}-{random.randint(1,9)}"
            else:                num = rnd_passport(nat)

            iss  = rnd_date(date(2010,1,1), date(2022,1,1))
            exp  = iss + timedelta(days=365*10) if dt not in ("aadhaar","ssn","nic") else None
            rows.append((cid, dt, num, nat, iss, exp, j==0))
    return rows


def generate_contacts(customers):
    rows = []
    for cid, _, first, last, _, _, _, nat, _, _, _, _, _, _, _, _, _ in customers:
        ph1 = rnd_phone(nat)
        ph2 = rnd_phone(nat) if random.random() < 0.4 else None
        em1 = rnd_email(first, last)
        em2 = rnd_email(first, last) if random.random() < 0.25 else None
        rows.append((cid, ph1, ph2, em1, em2,
                     random.choice(["phone","email","sms"]),
                     random.random() < 0.03,
                     rnd_date(date(2023,1,1), date(2025,3,29))))
    return rows


def generate_addresses(customers):
    rows = []
    for cid, _, _, _, _, _, _, nat, country, _, _, _, _, _, _, _, _ in customers:
        if nat == "India":
            city, state = random.choice(INDIAN_CITIES)
            line1 = f"{random.randint(1,999)} {random.choice(['Anna Salai','MG Road','Brigade Road','Park Street','Linking Road','Connaught Place'])}"
            postal = ''.join(random.choices(string.digits, k=6))
            ctry   = "India"
        elif nat == "UK":
            city, state = random.choice(UK_CITIES)
            line1 = f"{random.randint(1,300)} {random.choice(['High Street','Church Road','Station Road','Park Avenue'])}"
            postal = f"{random.choice('ABCDEFGHJKLMNPRSTUVWXY')}{random.randint(1,20)} {random.randint(1,9)}{random.choice('ABDEFGHJLNPQRSTUVWXYZ')}{random.choice('ABDEFGHJLNPQRSTUVWXYZ')}"
            ctry   = "UK"
        elif nat == "USA":
            city, state = random.choice(USA_CITIES)
            line1 = f"{random.randint(100,9999)} {random.choice(['Main St','Oak Ave','Maple Dr','Cedar Ln'])}"
            postal = ''.join(random.choices(string.digits, k=5))
            ctry   = "USA"
        elif nat == "UAE":
            city, state = random.choice(UAE_CITIES)
            line1 = f"Villa {random.randint(1,500)}, {random.choice(['Al Barsha','Deira','Jumeirah','Bur Dubai','Karama'])} District"
            postal = ""
            ctry   = "UAE"
        elif nat == "Singapore":
            city, state = random.choice(SG_CITIES)
            line1 = f"Block {random.randint(1,999)} {random.choice(['Ang Mo Kio','Bedok','Clementi','Jurong'])} Ave {random.randint(1,9)}"
            postal = ''.join(random.choices(string.digits, k=6))
            ctry   = "Singapore"
        else:
            city, state = random.choice(OTHER_CITIES)
            line1 = f"{random.randint(1,500)} Sample Street"
            postal = ''.join(random.choices(string.digits, k=5))
            ctry   = country

        rows.append((cid, "residential", line1, None, city, state, postal, ctry, True,
                     rnd_date(date(2010,1,1), date(2022,1,1)), None))
    return rows


def generate_accounts(customers):
    rows = []
    acc_types  = ["savings","current","salary","nri","fixed_deposit","recurring_deposit","joint"]
    acc_wt     = [55,15,15,5,4,4,2]
    currencies = {"India":"INR","UK":"GBP","USA":"USD","UAE":"AED","Singapore":"SGD"}
    statuses   = ["active","dormant","frozen","closed","under_investigation"]
    status_wt  = [80,10,3,5,2]
    bank_pool  = BANKS

    acc_num_counter = [10000000000]

    def next_acc():
        acc_num_counter[0] += 1
        return f"BANK{acc_num_counter[0]:018d}"

    customer_accounts = {}  # cid -> [account_id, ...]

    for cid, _, _, _, _, _, _, nat, _, _, income, _, _, _, _, since, _ in customers:
        n_accounts = 2 if random.random() < 0.20 else 1
        cur = currencies.get(nat, "INR")
        accs = []
        for k in range(n_accounts):
            aid     = new_uuid()
            acctype = random.choices(acc_types, weights=acc_wt)[0]
            bcode   = f"BR{random.randint(1000,9999)}"
            bank    = random.choice(bank_pool)
            ifsc    = rnd_ifsc(bank[1])
            balance = round(random.uniform(500, income/12*3 if income and income>0 else 50000), 2)
            min_bal = 1000 if acctype == "savings" else 5000
            status  = random.choices(statuses, weights=status_wt)[0]
            opened  = rnd_date(since, date(2024,6,1))
            dormant_end = min(date(2022,12,31), date(2025,3,1))
            last_tx = rnd_date(opened, date(2025,3,1)) if status != "dormant" else rnd_date(opened, max(opened, dormant_end))
            closed_end = max(last_tx, date(2025,3,1))
            closed  = rnd_date(last_tx, closed_end) if status == "closed" else None
            odlimit = round(random.uniform(5000,50000),2) if acctype == "current" else 0
            ir      = round(random.uniform(2.5, 7.5), 2) if acctype not in ("current",) else round(random.uniform(0,1),2)
            rows.append((
                aid, cid, next_acc(), acctype, bcode, ifsc, cur,
                balance, balance*0.95, min_bal, status,
                opened, closed, last_tx, odlimit, ir, None
            ))
            accs.append(aid)
        customer_accounts[cid] = accs

    return rows, customer_accounts


def generate_cards(accounts_rows, customer_accounts):
    rows = []
    networks = ["Visa","Mastercard","Rupay","Amex"]
    net_wt   = [35,30,30,5]
    stati    = ["active","blocked","expired","hotlisted","pending_activation"]
    stat_wt  = [75,10,8,5,2]

    for acct in accounts_rows:
        aid, cid = acct[0], acct[1]
        if random.random() < 0.05:   # 5% no card
            continue
        ctype   = random.choice(["debit"]*6 + ["credit"]*3 + ["prepaid"] + ["forex"])
        net     = random.choices(networks, weights=net_wt)[0]
        status  = random.choices(stati, weights=stat_wt)[0]
        iss     = rnd_date(date(2018,1,1), date(2024,1,1))
        exp     = iss + timedelta(days=365*4)
        n1      = ''.join(random.choices(string.digits, k=4))
        n2      = ''.join(random.choices(string.digits, k=4))
        masked  = f"{n1} **** **** {n2}"
        climit  = round(random.uniform(50000,500000),2) if ctype=="credit" else None
        outstanding = round(random.uniform(0, climit*0.6),2) if climit else None
        intl    = random.random() < 0.3
        last_dt = rnd_date(iss, date(2025,3,1)) if status == "active" else None

        rows.append((
            new_uuid(), aid, cid, masked, ctype, net, status,
            iss, exp, climit, outstanding,
            25000, 100000, 100000, intl, True,
            last_dt,
            random.choice([c for city,state in INDIAN_CITIES for c in [city]])
        ))
    return rows


def generate_loans(customers, customer_accounts):
    rows = []
    ltypes   = LOAN_TYPES
    lstat    = ["active","closed","npa","written_off","under_collection"]
    lstat_wt = [65,20,8,4,3]

    sample = random.sample(customers, 15000)
    for cust in sample:
        cid    = cust[0]
        income = cust[10] or 300000
        accs   = customer_accounts.get(cid)
        if not accs: continue
        aid    = accs[0]
        ltype  = random.choice(ltypes)
        prin   = round(random.uniform(50000, min(income*10, 10000000)), 2)
        sane   = prin
        disb   = round(prin * random.uniform(0.95,1.0), 2)
        ir     = round(random.uniform(7.5, 18.0), 2)
        itype  = random.choice(["fixed","floating"])
        tenure = random.choice([12,24,36,48,60,84,120,180,240])
        remain = random.randint(0, tenure)
        emi    = round((prin * ir/1200) / (1-(1+ir/1200)**(-tenure)), 2)
        paid   = tenure - remain
        outst  = round(prin - (emi * paid * 0.6), 2)
        status = random.choices(lstat, weights=lstat_wt)[0]
        start  = rnd_date(date(2019,1,1), date(2023,12,31))
        end    = start + timedelta(days=30*tenure)
        cibil  = random.randint(550, 900)
        rows.append((
            new_uuid(), cid, aid, ltype, prin, sane, disb, max(outst,0),
            ir, itype, tenure, remain, emi, random.randint(1,28),
            status, start, end if status=="closed" else None,
            None, None, f"{ltype.replace('_',' ').title()} for personal use",
            cibil, None
        ))
    return rows


def generate_repayments(loans):
    rows = []
    for loan in loans:
        lid   = loan[0]
        emi   = loan[12]
        outst = loan[7]
        start = loan[15]
        stat  = loan[14]
        n     = random.randint(2, 6)
        for i in range(n):
            due  = start + timedelta(days=30*(i+1))
            paid_date = due + timedelta(days=random.randint(-3,15))
            pstatus = random.choices(["paid","partial","missed","bounced"],
                                     weights=[70,10,12,8])[0]
            amtpaid = emi if pstatus=="paid" else (
                      emi*0.5 if pstatus=="partial" else 0)
            dpd = max(0, (paid_date-due).days) if pstatus in ("paid","partial") else random.randint(10,90)
            bounce = random.choice(["Insufficient funds","Mandate error","Account frozen"]) if pstatus=="bounced" else None
            prin_comp = round(amtpaid * 0.6, 2)
            int_comp  = round(amtpaid * 0.4, 2)
            penalty   = round(random.uniform(0,500),2) if pstatus in ("missed","bounced") else 0
            rows.append((
                lid, due, paid_date if pstatus!="missed" else None,
                emi, amtpaid, prin_comp, int_comp, penalty,
                max(outst - prin_comp*i, 0), pstatus, bounce, dpd
            ))
    return rows


def generate_beneficiaries(customers, customer_accounts):
    rows = []
    banks = [b[0] for b in BANKS]
    btypes = ["own_account","registered","unregistered"]
    bwt    = [15,65,20]
    for cust in customers:
        cid   = cust[0]
        n     = random.randint(0, 4)
        for _ in range(n):
            accno = f"BANK{random.randint(10000000000000000000,99999999999999999999)}"[:22]
            bank  = random.choice(banks)
            bt    = random.choices(btypes, weights=bwt)[0]
            added = rnd_date(date(2020,1,1), date(2025,1,1))
            rows.append((
                cid,
                f"{random.choice(HINDI_FIRST+TAMIL_FIRST)} {random.choice(INDIAN_LAST)}",
                accno[:22],
                rnd_ifsc("SBIN"),
                bank, bt, added, True,
                round(random.uniform(10000,500000),2),
                round(random.uniform(0,200000),2)
            ))
    return rows


def generate_kyc_audit(customers):
    rows = []
    for cust in customers:
        cid = cust[0]
        # Creation event
        rows.append((cid,"created",'{"event":"customer_created"}',
                     "system",cust[15],"Customer onboarded"))
        if random.random() < 0.6:
            rows.append((cid,"verified",'{"kyc_status":"verified"}',
                         random.choice(ANALYSTS),
                         rnd_date(date(2021,1,1), date(2025,1,1)),
                         "KYC verified successfully"))
    return rows


def generate_aml(customers):
    rows = []
    types  = ["onboarding","periodic","transaction_triggered","manual"]
    acts   = ["cleared","escalated","blocked","reported_fiu"]
    act_wt = [80,12,5,3]
    for cust in customers:
        cid     = cust[0]
        risk    = cust[14]
        stype   = random.choice(types)
        sdate   = rnd_date(date(2022,1,1), date(2025,3,1))
        matched = random.random() < (0.05 if risk in ("high","very_high") else 0.01)
        rscore  = random.randint(60,95) if matched else random.randint(0,40)
        action  = random.choices(acts, weights=act_wt)[0] if matched else "cleared"
        details = '{"match":"PEP list"}' if matched else 'null'
        rows.append((
            cid, sdate, stype, matched, details, rscore, action,
            "Automated screening" if action=="cleared" else "Manual review needed"
        ))
    return rows


def generate_logins(customers, customer_accounts, n=100_000):
    rows = []
    channels = ["mobile_app","internet_banking","api"]
    os_list  = ["iOS","Android","Windows","macOS","Linux"]
    browsers = ["Chrome","Firefox","Safari","Edge","Mobile App"]
    stati    = ["success","failed","blocked","suspicious"]
    stat_wt  = [80,14,3,3]

    all_cids = [c[0] for c in customers]
    all_nats = {c[0]: c[7] for c in customers}

    city_by_nat = {
        "India":[c for c,s in INDIAN_CITIES],
        "UK":[c for c,s in UK_CITIES],
        "USA":[c for c,s in USA_CITIES],
        "UAE":[c for c,s in UAE_CITIES],
        "Singapore":[c for c,s in SG_CITIES],
    }

    for _ in range(n):
        cid    = random.choice(all_cids)
        nat    = all_nats.get(cid,"India")
        ch     = random.choice(channels)
        dt     = rnd_date(date(2022,1,1), date(2025,3,29))
        tm     = f"{random.randint(0,23):02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}"
        ldt    = datetime.strptime(f"{dt} {tm}", "%Y-%m-%d %H:%M:%S")
        ip     = rnd_ip()
        dev    = ''.join(random.choices(string.hexdigits.lower(), k=16))
        devt   = random.choice(["smartphone","tablet","laptop","desktop"])
        os_    = random.choice(os_list)
        brow   = random.choice(browsers)
        cities = city_by_nat.get(nat, ["Unknown"])
        city   = random.choice(cities)
        lstat  = random.choices(stati, weights=stat_wt)[0]
        freason= random.choice(["Wrong password","OTP expired","Account locked"]) if lstat=="failed" else None
        sess   = random.randint(1,120) if lstat=="success" else None
        rows.append((cid, ldt, ch, ip, dev, devt, os_, brow, city, nat,
                     lstat, freason, sess))
    return rows
