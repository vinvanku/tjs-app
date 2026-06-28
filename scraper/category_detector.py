"""
category_detector.py — Job Category Auto-Detection for TJS App
===============================================================
Normalizes categories to exactly 17 standard values using
keyword matching in both English and Telugu.

Standard categories:
  general, police, health, engineering, revenue, teaching,
  banking, railway, research, education, agriculture, forest,
  judicial, defense, postal, insurance, staff_selection
"""

# Valid category values (matches Supabase check constraint)
VALID_CATEGORIES = [
    'general', 'police', 'health', 'engineering', 'revenue',
    'teaching', 'banking', 'railway', 'research', 'education',
    'agriculture', 'forest', 'judicial', 'defense', 'postal',
    'insurance', 'staff_selection',
]

# Category detection rules — ordered by specificity (most specific first)
CATEGORY_RULES = [
    ('police', [
        'POLICE', 'CONSTABLE', 'SI ', 'SUB INSPECTOR', 'DSP',
        'TSLPRB', 'LPRB', 'HEAD CONSTABLE', 'ASI ',
        # Telugu
        'పోలీసు', 'కానిస్టేబుల్', 'ఎస్.ఐ',
    ]),
    ('teaching', [
        'TEACHER', 'TRT', 'LECTURER', 'DSC', 'TET', 'DIET',
        'ANGANWADI', 'HEAD MASTER', 'PROFESSOR', 'FACULTY',
        'EDUCATIONAL', 'SCHOOL ASSISTANT', 'VIDYA', 'GURUKULAM',
        'TREIRB', 'ICDS', 'PGT', 'TGT', 'PRT',
        # Telugu
        'టీచర్', 'ఉపాధ్యాయ', 'అంగన్‌వాడి', 'లెక్చరర్',
    ]),
    ('health', [
        'NURSE', 'HEALTH', 'MEDICAL', 'ANM', 'PHARMACIST', 'DOCTOR',
        'MHSRB', 'NURSING', 'DMHO', 'LAB TECHNICIAN', 'SURGEON',
        'HOSPITAL', 'AIIMS', 'NIMS', 'TIMS', 'PARAMEDIC',
        'DENTIST', 'PHYSIOTHERAPIST', 'RADIOGRAPHER', 'ASHA ',
        'STAFF NURSE', 'MBBS', 'MD ', 'MS ',
        # Telugu
        'నర్సు', 'వైద్య', 'ఆరోగ్య', 'డాక్టర్',
    ]),
    ('engineering', [
        'ENGINEER', 'AEE', 'AE ', 'JLM', 'TRANSCO', 'GENCO',
        'SPDCL', 'NPDCL', 'TECHNICAL', 'LINEMAN', 'WIREMAN',
        'ELECTRICIAN', 'MECHANIC', 'FITTER', 'WELDER', 'TURNER',
        'JE ', 'JUNIOR ENGINEER', 'ASSISTANT ENGINEER',
        'B.TECH', 'B.E.', 'DIPLOMA',
        # Telugu
        'ఇంజనీర్', 'లైన్‌మ్యాన్',
    ]),
    ('banking', [
        'BANK', 'DCCB', 'COOPERATIVE', 'RBI', 'SBI', 'IBPS',
        'NIACL', 'NABARD', 'PNB', 'BOB', 'BOI', 'CANARA',
        'CLERK', 'PO ', 'PROBATIONARY OFFICER', 'BANKING',
        'LIC', 'GIC', 'UIIC', 'NICL',
        # Telugu
        'బ్యాంక్', 'క్లర్క్',
    ]),
    ('railway', [
        'RAILWAY', 'RRB', 'RRC', 'NTPC TRAIN', 'LOCO PILOT',
        'STATION MASTER', 'TICKET COLLECTOR', 'RPF',
        'RAIL', 'TRAIN', 'ALP ',
        # Telugu
        'రైల్వే',
    ]),
    ('defense', [
        'ARMY', 'NAVY', 'AIR FORCE', 'COAST GUARD', 'DEFENCE',
        'DEFENSE', 'MILITARY', 'BSF', 'CRPF', 'CISF', 'ITBP',
        'SSB ', 'NDA', 'CDS', 'AFCAT', 'AGNIVEER', 'SOLDIER',
        'SAILOR', 'AIRMAN', 'TERRITORIAL',
        # Telugu
        'సైన్యం', 'నౌకాదళం',
    ]),
    ('judicial', [
        'JUDGE', 'JUDICIAL', 'COURT', 'MAGISTRATE', 'ADVOCATE',
        'LEGAL', 'LAW CLERK', 'STENOGRAPHER', 'PEON',
        'JUNIOR ASSISTANT', 'HIGH COURT', 'DISTRICT COURT',
        # Telugu
        'న్యాయ', 'కోర్టు',
    ]),
    ('revenue', [
        'VRO', 'VRA', 'REVENUE', 'PATWARI', 'VILLAGE',
        'PANCHAYAT', 'TAHSILDAR', 'MANDAL', 'COLLECTOR',
        'DEPUTY COLLECTOR', 'AMIN',
        # Telugu
        'రెవెన్యూ', 'గ్రామ', 'పంచాయతీ',
    ]),
    ('research', [
        'RESEARCH', 'JRF', 'SRF', 'FELLOW', 'SCIENTIST',
        'PROJECT ASSISTANT', 'ISRO', 'DRDO', 'CSIR', 'ICAR',
        'ICMR', 'BARC', 'IGCAR', 'NRSC', 'LAB ASSISTANT',
        # Telugu
        'పరిశోధన', 'శాస్త్రవేత్త',
    ]),
    ('agriculture', [
        'AGRICULTURE', 'HORTICULTURE', 'FISHERIES', 'VETERINARY',
        'ANIMAL HUSBANDRY', 'SERICULTURE', 'FOREST',
        'FRO', 'FOREST RANGE OFFICER', 'BEAT OFFICER',
        # Telugu
        'వ్యవసాయం', 'అటవీ',
    ]),
    ('forest', [
        'FOREST RANGER', 'FOREST GUARD', 'FOREST BEAT',
        'FOREST SECTION', 'FBO', 'FSO',
    ]),
    ('postal', [
        'POST OFFICE', 'POSTAL', 'POSTMAN', 'MAILGUARD',
        'GDS', 'GRAMIN DAK', 'INDIA POST', 'POSTMASTER',
    ]),
    ('insurance', [
        'INSURANCE', 'LIC', 'GIC', 'NIACL', 'UIIC', 'NICL',
        'OICL', 'NEIA', 'ACTUARIAL',
    ]),
    ('staff_selection', [
        'SSC CGL', 'SSC CHSL', 'SSC MTS', 'SSC GD',
        'SSC JE', 'SSC CPO', 'STAFF SELECTION',
    ]),
    ('education', [
        'UNIVERSITY', 'COLLEGE', 'ACADEMIC', 'UGC', 'NET ',
        'ADMISSION', 'SCHOLARSHIP', 'NTA', 'CBSE', 'ICSE',
    ]),
]


def detect_category(text: str) -> str:
    """
    Auto-detect job category from title/description text.
    Returns one of the 17 standard category values.
    """
    if not text:
        return 'general'
    
    t = text.upper()
    
    for category, keywords in CATEGORY_RULES:
        if any(kw in t for kw in keywords):
            return category
    
    return 'general'


def normalize_category(raw_category: str) -> str:
    """
    Normalize a raw category string (from various sources) to
    one of the 17 standard values.
    """
    if not raw_category:
        return 'general'
    
    raw = raw_category.lower().strip()
    
    # Direct match
    if raw in VALID_CATEGORIES:
        return raw
    
    # Map common variants
    CATEGORY_MAP = {
        'medical': 'health', 'medical jobs': 'health',
        'medical/healthcare': 'health', 'healthcare': 'health',
        'medical/health': 'health', 'medical/teaching': 'health',
        'nursing': 'health',
        'police jobs': 'police', 'police/security': 'police',
        'police/law enforcement': 'police', 'police/medical': 'police',
        'teaching jobs': 'teaching', 'teaching/education': 'teaching',
        'teaching/faculty': 'teaching', 'academic/teaching': 'teaching',
        'education/teaching': 'teaching',
        'engineering jobs': 'engineering', 'engineering/power': 'engineering',
        'technical': 'engineering', 'state psc/engineering': 'engineering',
        'banking jobs': 'banking', 'banking/finance': 'banking',
        'banking/cooperative': 'banking', 'banking/apprenticeship': 'banking',
        'private/banking': 'banking', 'cooperative/banking': 'banking',
        'railway jobs': 'railway', 'railways': 'railway',
        'defence': 'defense', 'defence/support staff': 'defense',
        'defence/paramilitary': 'defense',
        'research/academic': 'research', 'research/university jobs': 'research',
        'research/scientific': 'research', 'research/science': 'research',
        'academic/technical': 'research',
        'judicial/legal': 'judicial', 'judiciary': 'judicial',
        'judiciary/legal': 'judicial', 'judiciary/court': 'judicial',
        'judicial/ministerial': 'judicial',
        'revenue department': 'revenue',
        'agriculture/farming': 'agriculture', 'academic/agriculture': 'agriculture',
        'postal jobs': 'postal',
        'central government': 'general', 'central govt. jobs': 'general',
        'central government jobs': 'general', 'state govt. jobs': 'general',
        'state government': 'general', 'state government jobs': 'general',
        'telangana govt jobs': 'general', 'ts govt jobs': 'general',
        'ts police jobs': 'police', 'tgpsc jobs': 'general',
        'government/social welfare': 'general',
        'government/tribal welfare': 'general',
        'psu': 'engineering', 'psu/power': 'engineering',
        'psu/manufacturing': 'engineering', 'psu/defence': 'defense',
        'psu/electronics': 'engineering', 'psu/petroleum': 'engineering',
        'psu/medical': 'health', 'psu - mining/metal': 'engineering',
        'it/technology': 'engineering',
        'anganwadi jobs': 'teaching',
        'nuclear/medical': 'health',
        'admissions/counselling': 'education',
        'skill development/training': 'education',
    }
    
    if raw in CATEGORY_MAP:
        return CATEGORY_MAP[raw]
    
    # Try partial match
    for key, val in CATEGORY_MAP.items():
        if key in raw or raw in key:
            return val
    
    # Fallback: try detect_category on the raw string
    detected = detect_category(raw)
    if detected != 'general':
        return detected
    
    return 'general'
