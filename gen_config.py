# gen_config.py — Name pools, city lists, constants
import random, string

DB = dict(host="localhost", port=3306, user="root", password="kavi", database="bank_fraud_db")

BATCH = 5000          # rows per INSERT batch
TXN_COUNT   = 100_000
LOGIN_COUNT = 100_000
AML_COUNT   = 100_000

# ── Name pools ──────────────────────────────────────────────────────────
TAMIL_FIRST   = ["Arun","Karthik","Priya","Meena","Lakshmi","Murugan","Saravanan",
                 "Kavitha","Vijay","Suresh","Geetha","Ravi","Mani","Deepa","Senthil",
                 "Anitha","Bala","Saranya","Dinesh","Nithya"]
TELUGU_FIRST  = ["Srinivas","Venkat","Kavitha","Rani","Ravi","Suresh","Padma",
                 "Ramesh","Swathi","Naveen","Harish","Divya","Sai","Krishna","Mounika"]
HINDI_FIRST   = ["Amit","Sunita","Rajesh","Neha","Pooja","Vivek","Rahul","Sneha",
                 "Deepak","Ananya","Mohit","Priya","Vikas","Kavita","Sanjay","Rekha"]
MARATHI_FIRST = ["Sachin","Mangesh","Ashwini","Prashant","Snehal","Sumedha",
                 "Nilesh","Pradnya","Mahesh","Smita","Ganesh","Archana"]
BENGALI_FIRST = ["Anirban","Debjani","Sourav","Mithun","Sohini","Arnab",
                 "Shreya","Ayan","Priyanka","Subhajit","Riya","Dipankar"]
PUNJABI_FIRST = ["Harpreet","Gurpreet","Manpreet","Jaspreet","Navneet",
                 "Amandeep","Rajvir","Simran","Karanvir","Parminder"]
UK_FIRST      = ["James","Oliver","Harry","Jack","George","Charlie","Emily",
                 "Olivia","Amelia","Jessica","Sophie","Isabella","Thomas","William"]
USA_FIRST     = ["Liam","Noah","Elijah","Lucas","Mason","Ava","Emma","Charlotte",
                 "Sophia","Madison","Ethan","Aiden","Jayden","Michael","Daniel"]
UAE_FIRST     = ["Mohammed","Ahmed","Ali","Omar","Khalid","Fatima","Aisha",
                 "Mariam","Hassan","Ibrahim","Yusuf","Zainab","Rania","Samir"]
SG_FIRST      = ["Wei","Jing","Hui","Mei","Xiao","Kai","Jun","Ling",
                 "Ravi","Kumar","Priya","Arjun","Deepak","Siti","Ahmad"]

INDIAN_LAST   = ["Kumar","Sharma","Patel","Reddy","Iyer","Singh","Gupta","Nair",
                 "Pillai","Rao","Joshi","Mehta","Malhotra","Chopra","Bhatia",
                 "Mukherjee","Chatterjee","Banerjee","Das","Ghosh","Shah","Desai",
                 "Verma","Mishra","Pandey","Tiwari","Dubey","Srivastava","Agarwal",
                 "Naidu","Menon","Krishnan","Subramaniam","Venkatesh","Rajan"]
UK_LAST       = ["Smith","Jones","Williams","Taylor","Brown","Davies","Evans",
                 "Wilson","Thomas","Roberts","Johnson","White","Walker","Hall"]
USA_LAST      = ["Johnson","Miller","Davis","Garcia","Rodriguez","Martinez",
                 "Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas"]
UAE_LAST      = ["Al-Rashid","Al-Maktoum","Al-Nahyan","Al-Thani","Bin Laden",
                 "Al-Farsi","Al-Mansouri","Al-Suwaidi","Al-Shamsi","Al-Mazrouei"]
SG_LAST       = ["Tan","Lim","Lee","Ng","Wong","Chen","Goh","Teo","Ong","Koh",
                 "Rajan","Kumar","Singh","Pillai"]
OTHERS_LAST   = ["Müller","Dupont","Rossi","Santos","Kim","Park","Nakamura",
                 "Yamamoto","Petrov","Kovač","Nielsen","Johansson"]

INDIAN_CITIES = [("Chennai","Tamil Nadu"),("Mumbai","Maharashtra"),
                 ("Delhi","Delhi"),("Hyderabad","Telangana"),("Bengaluru","Karnataka"),
                 ("Kolkata","West Bengal"),("Pune","Maharashtra"),("Ahmedabad","Gujarat"),
                 ("Jaipur","Rajasthan"),("Lucknow","Uttar Pradesh"),("Surat","Gujarat"),
                 ("Kanpur","Uttar Pradesh"),("Nagpur","Maharashtra"),("Patna","Bihar"),
                 ("Indore","Madhya Pradesh"),("Thane","Maharashtra"),("Bhopal","Madhya Pradesh"),
                 ("Visakhapatnam","Andhra Pradesh"),("Coimbatore","Tamil Nadu"),("Kochi","Kerala")]
UK_CITIES     = [("London","England"),("Manchester","England"),("Birmingham","England"),
                 ("Glasgow","Scotland"),("Leeds","England"),("Edinburgh","Scotland")]
USA_CITIES    = [("New York","New York"),("Los Angeles","California"),("Chicago","Illinois"),
                 ("Houston","Texas"),("Phoenix","Arizona"),("Philadelphia","Pennsylvania")]
UAE_CITIES    = [("Dubai","Dubai"),("Abu Dhabi","Abu Dhabi"),("Sharjah","Sharjah"),
                 ("Ajman","Ajman"),("Al Ain","Abu Dhabi")]
SG_CITIES     = [("Singapore","Central Region"),("Jurong","West Region"),
                 ("Tampines","East Region"),("Woodlands","North Region")]
OTHER_CITIES  = [("Paris","Île-de-France"),("Berlin","Berlin"),("Toronto","Ontario"),
                 ("Sydney","New South Wales"),("Tokyo","Tokyo"),("Seoul","Seoul")]

OCCUPATIONS = ["Software Engineer","Doctor","Teacher","Business Owner","Retired",
               "Daily Wage Worker","Government Employee","Freelancer","Student",
               "Housewife","Chartered Accountant","Bank Employee","Lawyer","Architect",
               "Nurse","Police Officer","Army Personnel","Trader","Pharmacist","Engineer"]

INCOME_BY_OCC = {
    "Software Engineer":(600000,6000000),"Doctor":(1200000,12000000),
    "Teacher":(300000,1000000),"Business Owner":(500000,6000000),
    "Retired":(96000,600000),"Daily Wage Worker":(96000,240000),
    "Government Employee":(300000,1200000),"Freelancer":(240000,3000000),
    "Student":(0,120000),"Housewife":(0,0),"Chartered Accountant":(800000,4000000),
    "Bank Employee":(400000,2000000),"Lawyer":(600000,5000000),
    "Architect":(500000,3000000),"Nurse":(300000,900000),
    "Police Officer":(300000,800000),"Army Personnel":(400000,1200000),
    "Trader":(400000,5000000),"Pharmacist":(400000,1800000),"Engineer":(500000,3000000)
}

BANKS = [("State Bank of India","SBIN"),("HDFC Bank","HDFC"),("ICICI Bank","ICIC"),
         ("Axis Bank","UTIB"),("Kotak Mahindra Bank","KKBK"),("Punjab National Bank","PUNB"),
         ("Bank of Baroda","BARB"),("Canara Bank","CNRB"),("Union Bank","UBIN"),
         ("IndusInd Bank","INDB"),("Yes Bank","YESB"),("Federal Bank","FDRL"),
         ("Barclays","BARC"),("HSBC","HSBC"),("Standard Chartered","SCBL"),
         ("Emirates NBD","ENBD"),("DBS Bank","DBSS")]

TXN_MODES   = ["NEFT","RTGS","IMPS","UPI","ATM_CASH","BRANCH_CASH","CHEQUE",
               "ONLINE_TRANSFER","CARD_PURCHASE","EMI","INTEREST","CHARGES",
               "SALARY_CREDIT","REFUND"]
CHANNELS    = ["mobile_app","internet_banking","atm","branch","api","pos"]
CARD_NETS   = ["Visa","Mastercard","Rupay","Amex"]
LOAN_TYPES  = ["home_loan","personal_loan","auto_loan","education_loan",
               "gold_loan","business_loan","credit_card_loan"]
FRAUD_TYPES = ["account_takeover","identity_theft","card_fraud","loan_fraud",
               "money_laundering","phishing","upi_fraud","cheque_fraud",
               "internal_fraud","cyber_fraud"]
ANALYSTS    = ["Analyst_Meera","Analyst_Rohit","Analyst_Priya","Analyst_Karthik",
               "Analyst_Deepa","Analyst_Suresh","Analyst_Anjali"]

def rnd_phone(country):
    d = ''.join(random.choices(string.digits, k=10))
    return {
        "India":    f"+91-{d[:5]}-{d[5:]}",
        "UK":       f"+44-{d[:4]}-{d[4:]}",
        "USA":      f"+1-{d[:3]}-{d[3:7]}-{d[7:]}",
        "UAE":      f"+971-{d[:2]}-{d[2:9]}",
        "Singapore":f"+65-{d[:4]}-{d[4:8]}",
    }.get(country, f"+{d[:2]}-{d[2:]}")

def rnd_email(first, last):
    domains = ["gmail.com","yahoo.com","outlook.com","hotmail.com",
               "rediffmail.com","gmial.com","yahooo.com","gmail.co"]  # typos at end
    d = random.choice(domains)
    n = random.randint(10,999)
    p = random.choice([
        f"{first.lower()}.{last.lower()}",
        f"{first[0].lower()}{last.lower()}",
        f"{first.lower()}{last.lower()}{n}",
        f"{first.lower()}_{last.lower()}",
    ])
    return f"{p}@{d}"

def rnd_pan():
    alpha = string.ascii_uppercase
    return ''.join(random.choices(alpha,k=5)) + \
           ''.join(random.choices(string.digits,k=4)) + \
           random.choice(alpha)

def rnd_aadhaar():
    return ''.join(random.choices(string.digits, k=12))

def rnd_passport(country):
    p = {"India":"P","UK":"UK","USA":"USA","UAE":"UAE","Singapore":"S"}.get(country,"X")
    return p + ''.join(random.choices(string.ascii_uppercase+string.digits, k=7))

def rnd_ip():
    return f"{random.randint(1,254)}.{random.randint(0,254)}.{random.randint(0,254)}.{random.randint(1,254)}"

def rnd_ifsc(bank_code):
    return f"{bank_code}0{random.randint(100000,999999)}"
