"""
TJS Final Scraper — Production-ready using curl_cffi (Chrome TLS impersonation)
All 5 working sources in one file, ready for TJS App integration.

Sources:
1. FreeJobAlert (structured table — BEST quality)
2. TGPSC Official (notifications + PDF links)
3. Sarkari Result (filtered for Telangana only)
4. Eenadu Pratibha (Telugu-first)
5. Sakshi Education (Telugu-first)

Method: curl_cffi with impersonate="chrome" — fastest, most reliable.
"""
import re
import time
import json
import os
from datetime import datetime
from bs4 import BeautifulSoup
from curl_cffi import requests as curl_requests


# ═══════════════════════════════════════════════════════════════════
# CORE UTILITIES
# ═══════════════════════════════════════════════════════════════════

def fetch(url, retries=3, timeout=30):
    """Fetch URL using curl_cffi with Chrome TLS impersonation."""
    for attempt in range(retries):
        try:
            resp = curl_requests.get(url, impersonate="chrome", timeout=timeout)
            if resp.status_code == 200:
                return resp.text
            print(f"    [{resp.status_code}] attempt {attempt+1} for {url}")
        except Exception as e:
            print(f"    [ERROR] attempt {attempt+1}: {str(e)[:60]}")
        time.sleep(1.5 ** attempt)
    return None


def detect_category(text):
    """Auto-categorize job by title keywords."""
    t = text.upper()
    rules = [
        ('police', ['POLICE', 'CONSTABLE', 'SI ', 'SUB INSPECTOR', 'DSP', 'LPRB']),
        ('teaching', ['TEACHER', 'TRT', 'LECTURER', 'DSC', 'TET', 'DIET',
                      'ANGANWADI', 'HEAD MASTER', 'EDUCATIONAL', 'SCHOOL']),
        ('health', ['NURSE', 'HEALTH', 'MEDICAL', 'ANM', 'PHARMACIST', 'DOCTOR',
                    'MHSRB', 'NURSING', 'DMHO', 'LAB TECHNICIAN', 'SURGEON']),
        ('engineering', ['ENGINEER', 'AEE', 'AE ', 'JLM', 'TRANSCO', 'GENCO',
                         'ENVIRONMENTAL ENGINEER', 'TECHNICAL']),
        ('revenue', ['VRO', 'REVENUE', 'PATWARI', 'VILLAGE', 'PANCHAYAT']),
        ('banking', ['BANK', 'DCCB', 'COOPERATIVE', 'RBI', 'SBI', 'IBPS', 'NIACL']),
        ('railway', ['RAILWAY', 'RRB', 'NTPC TRAIN']),
        ('civil_services', ['GROUP-I', 'GROUP 1', 'GROUP-II', 'GROUP 2',
                            'GROUP-III', 'GROUP-IV', 'GROUP I', 'GROUP II']),
        ('research', ['RESEARCH', 'JRF', 'FELLOW', 'SCIENTIST', 'PROJECT ASSISTANT']),
    ]
    for category, keywords in rules:
        if any(kw in t for kw in keywords):
            return category
    return 'general'


def parse_date(date_str):
    """Parse Indian date formats."""
    if not date_str or date_str.strip() in ('–', '-', '', 'N/A'):
        return None
    cleaned = date_str.strip()
    for fmt in ['%d-%m-%Y', '%d/%m/%Y', '%d %b %Y', '%d %B %Y', '%d.%m.%Y']:
        try:
            return datetime.strptime(cleaned, fmt).strftime('%Y-%m-%d')
        except ValueError:
            continue
    return None


def extract_vacancies(text):
    """Extract vacancy count from text."""
    m = re.search(r'[–\-]\s*(\d+)\s*Posts?', text, re.IGNORECASE)
    if m: return int(m.group(1))
    m = re.search(r'(\d+)\s*(?:Posts?|Vacanc)', text, re.IGNORECASE)
    if m: return int(m.group(1))
    return 0


# ═══════════════════════════════════════════════════════════════════
# 1. FREEJOBALERT — Structured table (BEST quality)
# ═══════════════════════════════════════════════════════════════════

def scrape_freejobalert():
    """Scrape FreeJobAlert Telangana — table.lattbl with 7 columns."""
    print("\n📰 1. FreeJobAlert")
    jobs = []
    
    html = fetch("https://www.freejobalert.com/telangana-government-jobs/")
    if not html:
        print("   ❌ Failed")
        return jobs
    
    soup = BeautifulSoup(html, 'html.parser')
    table = soup.find('table', class_='lattbl')
    if not table:
        print("   ⚠️ Table not found")
        return jobs
    
    for row in table.find_all('tr')[1:]:  # skip header
        cols = row.find_all('td')
        if len(cols) < 7:
            continue
        
        post_date = cols[0].get_text(strip=True)
        board = cols[1].get_text(strip=True)
        post_name = cols[2].get_text(strip=True)
        qualification = cols[3].get_text(strip=True)
        advt_no = cols[4].get_text(strip=True)
        last_date = cols[5].get_text(strip=True)
        link = cols[6].find('a')
        
        jobs.append({
            'title': f"{board} – {post_name}",
            'organization': board,
            'category': detect_category(post_name),
            'qualification': qualification[:150] if qualification else None,
            'advt_no': advt_no if advt_no != '–' else None,
            'last_date': parse_date(last_date),
            'posted_date': parse_date(post_date),
            'apply_url': link['href'] if link else None,
            'source': 'freejobalert',
            'vacancies': extract_vacancies(post_name),
            'districts': ['All Telangana'],
        })
    
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════════
# 2. TGPSC OFFICIAL — Notifications + PDF links
# ═══════════════════════════════════════════════════════════════════

def scrape_tgpsc():
    """Scrape TGPSC official site for recruitment notifications."""
    print("\n🏛️ 2. TGPSC Official")
    jobs = []
    
    html = fetch("https://websitenew.tgpsc.gov.in/")
    if not html:
        print("   ❌ Failed")
        return jobs
    
    soup = BeautifulSoup(html, 'html.parser')
    keywords = ['RECRUITMENT', 'NOTIFICATION', 'VACANCIES', 'GENERAL RECRUITMENT',
                'TEACHER', 'GROUP', 'TRT', 'AEE', 'VRO', 'DEO', 'SELECTION']
    seen = set()
    
    for link in soup.find_all('a', href=True):
        text = link.get_text(strip=True)
        if len(text) < 15:
            continue
        if not any(kw in text.upper() for kw in keywords):
            continue
        dedup = text[:80].lower()
        if dedup in seen:
            continue
        seen.add(dedup)
        
        href = link['href']
        pdf_url = None
        if href.lower().endswith('.pdf'):
            pdf_url = href if href.startswith('http') else f"https://www.tgpsc.gov.in/{href.lstrip('/')}"
        
        jobs.append({
            'title': text[:200],
            'organization': 'TGPSC',
            'category': detect_category(text),
            'qualification': None,
            'advt_no': None,
            'last_date': None,
            'posted_date': None,
            'apply_url': 'https://www.tgpsc.gov.in',
            'pdf_url': pdf_url,
            'source': 'tgpsc',
            'vacancies': extract_vacancies(text),
            'districts': ['All Telangana'],
        })
    
    print(f"   ✅ {len(jobs)} notifications")
    return jobs


# ═══════════════════════════════════════════════════════════════════
# 3. SARKARI RESULT — Filtered for Telangana
# ═══════════════════════════════════════════════════════════════════

def scrape_sarkariresult():
    """Scrape Sarkari Result Telangana section with strict filtering."""
    print("\n📋 3. Sarkari Result")
    jobs = []
    
    html = fetch("https://www.sarkariresult.com/telangana/")
    if not html:
        print("   ❌ Failed")
        return jobs
    
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    
    # Filter rules: only actual job links, not navigation/promo
    skip_patterns = ['youtube', 'android app', 'apple', 'ios app', 'telegram',
                     'sarkari result®', 'whatsapp', 'instagram', 'facebook',
                     'privacy policy', 'about us', 'contact', 'disclaimer']
    
    job_keywords = ['ONLINE FORM', 'ADMIT CARD', 'RESULT', 'RECRUITMENT',
                    'NOTIFICATION', 'VACANCY', 'APPLY ONLINE', 'WALK-IN',
                    'ANSWER KEY', 'SYLLABUS']
    
    for link in soup.find_all('a', href=True):
        text = link.get_text(strip=True)
        href = link['href']
        
        if len(text) < 15 or len(text) > 200:
            continue
        
        text_lower = text.lower()
        # Skip navigation/promo links
        if any(skip in text_lower for skip in skip_patterns):
            continue
        
        # Must contain a job keyword
        text_upper = text.upper()
        if not any(kw in text_upper for kw in job_keywords):
            continue
        
        dedup = text[:60].lower()
        if dedup in seen:
            continue
        seen.add(dedup)
        
        full_url = href if href.startswith('http') else f"https://www.sarkariresult.com{href}"
        
        jobs.append({
            'title': text[:200],
            'organization': _extract_org(text),
            'category': detect_category(text),
            'qualification': None,
            'advt_no': None,
            'last_date': None,
            'posted_date': None,
            'apply_url': full_url,
            'source': 'sarkariresult',
            'vacancies': extract_vacancies(text),
            'districts': ['All Telangana'],
        })
    
    print(f"   ✅ {len(jobs)} jobs (filtered)")
    return jobs


# ═══════════════════════════════════════════════════════════════════
# 4. EENADU PRATIBHA — Telugu-first job portal
# ═══════════════════════════════════════════════════════════════════

def scrape_eenadu():
    """Scrape Eenadu Pratibha jobs/notifications section."""
    print("\n📰 4. Eenadu Pratibha")
    jobs = []
    
    html = fetch("https://pratibha.eenadu.net/jobs/notifications")
    if not html:
        print("   ❌ Failed")
        return jobs
    
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    
    job_keywords = ['RECRUITMENT', 'NOTIFICATION', 'JOBS', 'VACANCY', 'POSTS',
                    'APPLY', 'ONLINE', 'నోటిఫికేషన్', 'ఉద్యోగాలు', 'నియామకం',
                    'పోలీసు', 'ఉపాధ్యాయ']
    
    for link in soup.find_all('a', href=True):
        text = link.get_text(strip=True)
        if len(text) < 10:
            continue
        if not any(kw in text.upper() for kw in job_keywords):
            continue
        
        dedup = text[:50].lower()
        if dedup in seen:
            continue
        seen.add(dedup)
        
        href = link['href']
        full_url = href if href.startswith('http') else f"https://pratibha.eenadu.net{href}"
        
        jobs.append({
            'title': text[:200],
            'organization': _extract_org(text),
            'category': detect_category(text),
            'qualification': None,
            'advt_no': None,
            'last_date': None,
            'posted_date': None,
            'apply_url': full_url,
            'source': 'eenadu',
            'vacancies': extract_vacancies(text),
            'districts': ['All Telangana'],
        })
    
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════════
# 5. SAKSHI EDUCATION — Telugu-first
# ═══════════════════════════════════════════════════════════════════

def scrape_sakshi():
    """Scrape Sakshi Education notifications."""
    print("\n📰 5. Sakshi Education")
    jobs = []
    
    html = fetch("https://education.sakshi.com/notifications")
    if not html:
        print("   ❌ Failed")
        return jobs
    
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    
    job_keywords = ['RECRUITMENT', 'NOTIFICATION', 'JOBS', 'VACANCY', 'POSTS',
                    'APPLY', 'నోటిఫికేషన్', 'ఉద్యోగాలు', 'నియామకం', 'జాబ్స్']
    
    for link in soup.find_all('a', href=True):
        text = link.get_text(strip=True)
        if len(text) < 15:
            continue
        if not any(kw in text.upper() for kw in job_keywords):
            continue
        
        dedup = text[:50].lower()
        if dedup in seen:
            continue
        seen.add(dedup)
        
        href = link['href']
        full_url = href if href.startswith('http') else f"https://education.sakshi.com{href}"
        
        jobs.append({
            'title': text[:200],
            'organization': _extract_org(text),
            'category': detect_category(text),
            'qualification': None,
            'advt_no': None,
            'last_date': None,
            'posted_date': None,
            'apply_url': full_url,
            'source': 'sakshi',
            'vacancies': extract_vacancies(text),
            'districts': ['All Telangana'],
        })
    
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════════
# HELPER
# ═══════════════════════════════════════════════════════════════════

def _extract_org(text):
    """Try to extract organization from title."""
    orgs = ['TGPSC', 'TSPSC', 'TGLPRB', 'TSLPRB', 'TSGENCO', 'TGGENCO',
            'TSTRANSCO', 'HMWSSB', 'TSRTC', 'TGRTC', 'MHSRB', 'ECIL',
            'NHM', 'DCCB', 'RBI', 'SBI', 'SSC', 'UPSC', 'DRDO', 'ISRO',
            'IIT', 'NIT', 'AIIMS', 'BHEL', 'NTPC', 'CCRUM', 'TIMS',
            'DMHO', 'NABARD', 'NIACL', 'TSRTC']
    for org in orgs:
        if org in text.upper():
            return org
    return 'Telangana Govt'


# ═══════════════════════════════════════════════════════════════════
# MAIN ORCHESTRATOR
# ═══════════════════════════════════════════════════════════════════

def run_all():
    """Run all scrapers and produce final validation report."""
    print("═" * 65)
    print("🚀 TJS FINAL SCRAPER — curl_cffi + Chrome TLS Impersonation")
    print(f"   Run: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("═" * 65)
    
    start = time.time()
    
    all_jobs = []
    results = {}
    
    scrapers = [
        ('freejobalert', scrape_freejobalert),
        ('tgpsc', scrape_tgpsc),
        ('sarkariresult', scrape_sarkariresult),
        ('eenadu', scrape_eenadu),
        ('sakshi', scrape_sakshi),
    ]
    
    for name, fn in scrapers:
        s = time.time()
        try:
            jobs = fn()
            elapsed = int((time.time() - s) * 1000)
            results[name] = {'count': len(jobs), 'ms': elapsed, 'status': 'OK'}
            all_jobs.extend(jobs)
        except Exception as e:
            elapsed = int((time.time() - s) * 1000)
            results[name] = {'count': 0, 'ms': elapsed, 'status': f'ERROR: {e}'}
            print(f"   ❌ {name}: {e}")
    
    total_time = int((time.time() - start) * 1000)
    
    # ─── SUMMARY ───
    print(f"\n{'═' * 65}")
    print("📊 FINAL RESULTS")
    print(f"{'═' * 65}")
    print(f"{'Source':<18} {'Jobs':>5} {'Time':>7} {'Status'}")
    print(f"{'─'*18} {'─'*5} {'─'*7} {'─'*20}")
    for name, r in results.items():
        emoji = "✅" if r['status'] == 'OK' and r['count'] > 0 else "❌"
        print(f"{emoji} {name:<16} {r['count']:>5} {r['ms']:>5}ms  {r['status']}")
    
    print(f"\n{'─' * 65}")
    print(f"📋 GRAND TOTAL: {len(all_jobs)} jobs in {total_time}ms")
    
    # Category breakdown
    cats = {}
    for j in all_jobs:
        cats[j['category']] = cats.get(j['category'], 0) + 1
    print(f"\n📊 BY CATEGORY:")
    for cat, count in sorted(cats.items(), key=lambda x: -x[1]):
        print(f"   {cat:<15}: {count}")
    
    # Org breakdown (top 10)
    orgs = {}
    for j in all_jobs:
        orgs[j['organization']] = orgs.get(j['organization'], 0) + 1
    print(f"\n📊 TOP ORGANIZATIONS:")
    for org, count in sorted(orgs.items(), key=lambda x: -x[1])[:10]:
        print(f"   {org:<20}: {count}")
    
    # Save results
    output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'final_results.json')
    output = {
        'run_date': datetime.now().isoformat(),
        'total_jobs': len(all_jobs),
        'total_time_ms': total_time,
        'source_results': results,
        'jobs': all_jobs,
    }
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False, default=str)
    
    print(f"\n💾 All {len(all_jobs)} jobs saved to: final_results.json")
    print(f"✅ Done!")
    
    return all_jobs, results


if __name__ == '__main__':
    run_all()
