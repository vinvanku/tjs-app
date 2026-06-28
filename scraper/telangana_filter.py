"""
telangana_filter.py — Telangana-Only Job Filter for TJS App
============================================================
Rejects jobs clearly from other states while keeping:
  - All Telangana-specific jobs
  - National-level jobs (SSC, RRB, Banks, Defence) relevant to TS candidates
  - Jobs from TS-specific sources (TGPSC, TSLPRB, etc.)
"""


# ═══════════════════════════════════════════════════════════════
# State rejection patterns — jobs with these are NOT Telangana
# ═══════════════════════════════════════════════════════════════

NON_TS_PATTERNS = [
    # Other state PSC/recruitment abbreviations
    'UPPSC', 'MPPSC', 'BPSC', 'RPSC', 'GPSC', 'KPSC', 'TNPSC',
    'APPSC', 'HPSC', 'JPSC', 'UKPSC', 'CGPSC', 'WBPSC',
    'UPSSSC', 'UKSSSC', 'HSSC', 'JSSC', 'OSSSC', 'BSSC',
    # State-specific orgs
    'UPSRLM', 'MPSRLM', 'BPSRLM', 'RPSRLM',
    'UP Police', 'MP Police', 'Bihar Police', 'Rajasthan Police',
    'Maharashtra Police', 'Gujarat Police', 'Karnataka Police',
    'Tamil Nadu Police', 'Kerala Police', 'Punjab Police',
    'Haryana Police', 'Odisha Police', 'Jharkhand Police',
    'Chhattisgarh Police', 'West Bengal Police',
    'Andhra Pradesh Police',
    # Full state names (uppercase matching)
    'UTTAR PRADESH', 'MADHYA PRADESH', 'BIHAR', 'RAJASTHAN',
    'GUJARAT', 'MAHARASHTRA', 'KARNATAKA', 'TAMIL NADU',
    'KERALA', 'ODISHA', 'JHARKHAND', 'CHHATTISGARH',
    'WEST BENGAL', 'PUNJAB', 'HARYANA', 'UTTARAKHAND',
    'HIMACHAL', 'ASSAM', 'MANIPUR', 'MEGHALAYA', 'TRIPURA',
    'MIZORAM', 'NAGALAND', 'ARUNACHAL', 'SIKKIM', 'GOA',
    'JAMMU', 'KASHMIR', 'LADAKH',
]

# ═══════════════════════════════════════════════════════════════
# Telangana whitelist — jobs with these are ALWAYS kept
# ═══════════════════════════════════════════════════════════════

TS_WHITELIST = [
    # State orgs
    'Telangana', 'TGPSC', 'TSPSC', 'TSLPRB', 'TSGENCO', 'TGSPDCL',
    'TGNPDCL', 'TSRTC', 'HMWSSB', 'GHMC', 'TOMCOM', 'DEET',
    'TREI-RB', 'TREIRB', 'TSDSC', 'TS DSC', 'TG ', 'KISCE',
    'TIMS', 'NIMS',
    # Cities/districts
    'Hyderabad', 'Warangal', 'Karimnagar', 'Khammam', 'Nalgonda',
    'Nizamabad', 'Medak', 'Adilabad', 'Rangareddy', 'Mahbubnagar',
    'Siddipet', 'Kamareddy', 'Peddapalli', 'Mancherial', 'Suryapet',
    'Sangareddy', 'Jagtial', 'Bhupalpally', 'Nagarkurnool',
    'Wanaparthy', 'Vikarabad', 'Medchal', 'Secunderabad',
    'Shamirpet', 'Bhongir',
]

# ═══════════════════════════════════════════════════════════════
# National-level orgs (keep — they post TS-relevant vacancies)
# ═══════════════════════════════════════════════════════════════

NATIONAL_KEEP = [
    'SSC', 'RRB', 'IBPS', 'SBI', 'RBI', 'UPSC', 'NTA',
    'ISRO', 'DRDO', 'HAL', 'BHEL', 'NTPC', 'ONGC', 'IOCL',
    'Indian Army', 'Indian Navy', 'Indian Air Force', 'Coast Guard',
    'Railway', 'India Post', 'NVS', 'KVS', 'AIIMS',
    'Central', 'National', 'All India', 'Bank', 'Defence',
    'ECIL', 'BEL', 'BSNL', 'MTNL', 'LIC', 'GIC',
]

# ═══════════════════════════════════════════════════════════════
# TS-specific sources (always trust these)
# ═══════════════════════════════════════════════════════════════

TS_SOURCES = [
    'freejobalert', 'tgpsc', 'tslprb', 'treirb', 'tsdsc',
    'deet', 'tgspdcl', 'tgnpdcl', 'tsgenco', 'tomcom',
    'kisce_sat', 'eenadu', 'eenadu_pratibha', 'sakshi',
    'sakshi_english', 'sakshi_education_en', 'andhrajyothy',
    'nipuna_ntnews',
]


def is_telangana_relevant(job: dict) -> bool:
    """
    Returns True if job is relevant to Telangana users.
    
    Logic:
    1. Always keep if from a TS-specific source
    2. Always keep if title/org contains TS whitelist keyword
    3. Reject if title/org contains another state's keyword
    4. Keep if it's a national-level org (relevant to all states)
    5. Default: keep (benefit of doubt)
    """
    title = str(job.get('title', ''))
    org = str(job.get('organization', ''))
    source = str(job.get('source', ''))
    combined = f"{title} {org}"
    combined_upper = combined.upper()
    combined_lower = combined.lower()
    
    # Rule 1: Trust TS-specific sources
    if source.lower() in TS_SOURCES:
        return True
    
    # Rule 2: Contains TS keyword → always keep
    for kw in TS_WHITELIST:
        if kw.lower() in combined_lower:
            return True
    
    # Rule 3: Contains other state keyword → reject
    for pattern in NON_TS_PATTERNS:
        if pattern.upper() in combined_upper:
            return False
    
    # Rule 4: National-level orgs → keep
    for nat in NATIONAL_KEEP:
        if nat.upper() in combined_upper:
            return True
    
    # Rule 5: Default keep (benefit of doubt)
    return True


def filter_telangana_jobs(jobs: list) -> tuple:
    """
    Filter jobs list, keeping only Telangana-relevant ones.
    
    Returns:
        (kept_jobs, rejected_jobs) tuple
    """
    kept = []
    rejected = []
    
    for job in jobs:
        if is_telangana_relevant(job):
            kept.append(job)
        else:
            rejected.append(job)
    
    return kept, rejected
