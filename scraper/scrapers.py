"""
scrapers.py — TJS Production Scraper (18 Sources)
===================================================
All Telangana job notification scrapers in one module.

Sources (in priority order):
  Original 5:
    1. FreeJobAlert (structured table — BEST quality)
    2. TGPSC Official (notifications + PDF links)
    3. Sarkari Result (filtered for Telangana)
    4. Eenadu Pratibha (Telugu-first)
    5. Sakshi Education (Telugu-first)

  New 13:
    6. IndGovtJobs (telangana.indgovtjobs.net)
    7. Careers247 (careers247.in)
    8. 20Govt (telangana.20govt.com)
    9. SarkariJobs (telangana.sarkarijobs.com)
    10. JobAlertsHub (jobalertshub.com)
    11. CareerPower (careerpower.in)
    12. Andhra Jyothy (andhrajyothy.com)
    13. Testbook (testbook.com)
    14. TSLPRB (tgprb.in — Police)
    15. TREI-RB (treirb.telangana.gov.in)
    16. TGSPDCL (tgsouthernpower.org)
    17. TOMCOM (tomcom.telangana.gov.in)
    18. DEET (deet.telangana.gov.in)

Method: curl_cffi (Chrome TLS impersonation) primary, requests fallback.
"""

import re
import time
import json
import os
from datetime import datetime
from bs4 import BeautifulSoup

# Try curl_cffi first (preferred), fall back to requests
try:
    from curl_cffi import requests as curl_requests
    HAS_CURL_CFFI = True
except ImportError:
    HAS_CURL_CFFI = False
    import requests as std_requests

try:
    import cloudscraper
    HAS_CLOUDSCRAPER = True
except ImportError:
    HAS_CLOUDSCRAPER = False


# ═══════════════════════════════════════════════════════════════
# CORE UTILITIES
# ═══════════════════════════════════════════════════════════════

def fetch(url, retries=3, timeout=30):
    """Fetch URL with Chrome TLS impersonation. Falls back gracefully."""
    for attempt in range(retries):
        try:
            if HAS_CURL_CFFI:
                resp = curl_requests.get(url, impersonate="chrome", timeout=timeout)
            elif HAS_CLOUDSCRAPER:
                scraper = cloudscraper.create_scraper()
                resp = scraper.get(url, timeout=timeout)
            else:
                resp = std_requests.get(url, timeout=timeout, headers={
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/125.0.0.0 Safari/537.36'
                })
            if resp.status_code == 200:
                return resp.text
            print(f"    [{resp.status_code}] attempt {attempt+1} for {url[:60]}")
        except Exception as e:
            print(f"    [ERROR] attempt {attempt+1}: {str(e)[:60]}")
        time.sleep(1.5 ** attempt)
    return None


def detect_category(text):
    """Auto-categorize job by title keywords."""
    from category_detector import detect_category as _detect
    return _detect(text)


def parse_date(date_str):
    """Parse Indian date formats to ISO."""
    if not date_str or date_str.strip() in ('–', '-', '', 'N/A'):
        return None
    cleaned = date_str.strip()
    for fmt in ['%d-%m-%Y', '%d/%m/%Y', '%d %b %Y', '%d %B %Y', '%d.%m.%Y',
                '%Y-%m-%d', '%b %d, %Y', '%B %d, %Y']:
        try:
            return datetime.strptime(cleaned, fmt).strftime('%Y-%m-%d')
        except ValueError:
            continue
    return None


def extract_vacancies(text):
    """Extract vacancy count from text."""
    if not text:
        return 0
    m = re.search(r'[–\-]\s*(\d+)\s*Posts?', text, re.IGNORECASE)
    if m: return int(m.group(1))
    m = re.search(r'(\d+)\s*(?:Posts?|Vacanc)', text, re.IGNORECASE)
    if m: return int(m.group(1))
    return 0


def is_valid_job_posting(title):
    """Filter out non-job content."""
    if not title or len(title) <= 20:
        return False
    t = title.lower()
    exclude = [
        'how to prepare', 'study material', 'tips for', 'strategy',
        'syllabus explained', 'cut off marks', 'answer key',
        'results declared', 'result out', 'merit list',
        'admit card', 'hall ticket', 'malpractice',
        'government to fill', 'cm announced', 'press release',
        'latest news', 'upcoming vacancies', 'exam pattern',
        'preparation plan', 'previous papers', 'mock test',
    ]
    if any(ex in t for ex in exclude):
        return False
    job_kws = [
        'recruitment', 'notification', 'vacancy', 'vacancies', 'posts',
        'apply', 'online form', 'walk-in', 'walk in', 'bharti', 'jobs',
        'hiring', 'opening', 'contract', 'outsourcing', 'apprentice',
    ]
    return any(kw in t for kw in job_kws)


# ═══════════════════════════════════════════════════════════════
# 1. FREEJOBALERT (BEST structured source)
# ═══════════════════════════════════════════════════════════════

def scrape_freejobalert(skip_details=False):
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
    for row in table.find_all('tr')[1:]:
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
        title = f"{board} – {post_name}"
        if not is_valid_job_posting(title):
            continue
        detail_url = link['href'] if link else None
        apply_url = None
        pdf_url = None
        if detail_url and not skip_details:
            details = _fetch_fja_details(detail_url)
            apply_url = details.get('apply_url')
            pdf_url = details.get('pdf_url')
            time.sleep(0.4)
        jobs.append({
            'title': title, 'organization': board,
            'category': detect_category(post_name),
            'qualification': qualification[:150] if qualification else None,
            'advt_no': advt_no if advt_no != '–' else None,
            'last_date': parse_date(last_date),
            'posted_date': parse_date(post_date),
            'apply_url': apply_url or detail_url,
            'pdf_url': pdf_url,
            'source': 'freejobalert',
            'vacancies': extract_vacancies(post_name),
            'districts': ['All Telangana'],
        })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


def _fetch_fja_details(url):
    """Fetch FreeJobAlert detail page for apply/pdf links."""
    result = {'apply_url': None, 'pdf_url': None}
    html = fetch(url, retries=2, timeout=20)
    if not html:
        return result
    try:
        soup = BeautifulSoup(html, 'html.parser')
        for table in soup.find_all('table'):
            text = table.get_text().lower()
            if 'apply online' in text or 'important link' in text:
                for row in table.find_all('tr'):
                    cells = row.find_all('td')
                    if len(cells) < 2:
                        continue
                    label = cells[0].get_text(strip=True).lower()
                    link = cells[-1].find('a', href=True)
                    if not link:
                        continue
                    href = link['href']
                    if 'apply' in label:
                        result['apply_url'] = href
                    elif 'notification' in label and '.pdf' in href.lower():
                        result['pdf_url'] = href
    except Exception:
        pass
    return result


# ═══════════════════════════════════════════════════════════════
# 2. TGPSC OFFICIAL
# ═══════════════════════════════════════════════════════════════

def scrape_tgpsc():
    """Scrape TGPSC Official — scan links for recruitment keywords."""
    print("\n📰 2. TGPSC Official")
    jobs = []
    html = fetch("https://websitenew.tgpsc.gov.in/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    keywords = ['RECRUITMENT', 'NOTIFICATION', 'VACANCIES', 'TEACHER',
                'GROUP', 'TRT', 'AEE', 'VRO', 'DEO', 'SELECTION']
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 15:
            continue
        dedup_key = text[:80].lower()
        if dedup_key in seen:
            continue
        if any(kw in text.upper() for kw in keywords):
            seen.add(dedup_key)
            pdf_url = href if href.endswith('.pdf') else None
            full_url = href if href.startswith('http') else f"https://websitenew.tgpsc.gov.in{href}"
            jobs.append({
                'title': text[:200], 'organization': 'TGPSC',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None,
                'apply_url': full_url, 'pdf_url': pdf_url,
                'qualification': None, 'source': 'tgpsc',
                'posted_date': None, 'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 3. SARKARI RESULT (filtered for Telangana)
# ═══════════════════════════════════════════════════════════════

def scrape_sarkariresult():
    """Scrape Sarkari Result — aggressive filtering for relevant jobs."""
    print("\n📰 3. Sarkari Result")
    jobs = []
    html = fetch("https://www.sarkariresult.com/telangana/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    skip_patterns = ['youtube', 'android', 'telegram', 'whatsapp',
                     'facebook', 'twitter', 'instagram', 'app']
    job_keywords = ['ONLINE FORM', 'ADMIT CARD', 'RESULT', 'RECRUITMENT',
                    'NOTIFICATION', 'VACANCY', 'APPLY ONLINE', 'WALK-IN']
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 20:
            continue
        if any(s in href.lower() for s in skip_patterns):
            continue
        if not any(kw in text.upper() for kw in job_keywords):
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        seen.add(dedup_key)
        if not is_valid_job_posting(text):
            continue
        full_url = href if href.startswith('http') else f"https://www.sarkariresult.com{href}"
        jobs.append({
            'title': text[:200], 'organization': 'Various',
            'category': detect_category(text),
            'vacancies': extract_vacancies(text),
            'last_date': None,
            'apply_url': full_url, 'pdf_url': None,
            'qualification': None, 'source': 'sarkariresult',
            'posted_date': None, 'districts': ['All Telangana'],
        })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 4. EENADU PRATIBHA (Telugu-first)
# ═══════════════════════════════════════════════════════════════

def scrape_eenadu():
    """Scrape Eenadu Pratibha — Telugu job notifications."""
    print("\n📰 4. Eenadu Pratibha")
    jobs = []
    html = fetch("https://pratibha.eenadu.net/notifications/latestnotifications/government-jobs/1-8-27")
    if not html:
        html = fetch("https://pratibha.eenadu.net/jobs/notifications")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    keywords = ['RECRUITMENT', 'NOTIFICATION', 'నోటిఫికేషన్', 'ఉద్యోగాలు',
                'నియామకం', 'పోలీసు', 'ఉపాధ్యాయ', 'VACANCY', 'POSTS']
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 15:
            continue
        dedup_key = text[:50].lower()
        if dedup_key in seen:
            continue
        if any(kw in text.upper() for kw in keywords):
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://pratibha.eenadu.net{href}"
            jobs.append({
                'title': text[:200], 'organization': 'Various (Eenadu)',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None,
                'apply_url': full_url, 'pdf_url': None,
                'qualification': None, 'source': 'eenadu',
                'posted_date': None, 'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 5. SAKSHI EDUCATION (Telugu-first)
# ═══════════════════════════════════════════════════════════════

def scrape_sakshi():
    """Scrape Sakshi Education — Telugu job notifications."""
    print("\n📰 5. Sakshi Education")
    jobs = []
    html = fetch("https://education.sakshi.com/notifications")
    if not html:
        html = fetch("https://education.sakshi.com/en/telangana-jobs")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    keywords = ['RECRUITMENT', 'NOTIFICATION', 'నోటిఫికేషన్', 'ఉద్యోగాలు',
                'నియామకం', 'జాబ్స్', 'VACANCY', 'POSTS']
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 15:
            continue
        dedup_key = text[:50].lower()
        if dedup_key in seen:
            continue
        if any(kw in text.upper() for kw in keywords):
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://education.sakshi.com{href}"
            jobs.append({
                'title': text[:200], 'organization': 'Various (Sakshi)',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None,
                'apply_url': full_url, 'pdf_url': None,
                'qualification': None, 'source': 'sakshi',
                'posted_date': None, 'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 6. INDGOVTJOBS (Telangana section)
# ═══════════════════════════════════════════════════════════════

def scrape_indgovtjobs():
    """Scrape telangana.indgovtjobs.net — TS-focused aggregator."""
    print("\n📰 6. IndGovtJobs (TS)")
    jobs = []
    html = fetch("https://telangana.indgovtjobs.net/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 20:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if is_valid_job_posting(text) or 'recruitment' in text.lower() or 'posts' in text.lower():
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://telangana.indgovtjobs.net{href}"
            jobs.append({
                'title': text[:200], 'organization': 'Various',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None,
                'apply_url': full_url, 'pdf_url': None,
                'qualification': None, 'source': 'indgovtjobs',
                'posted_date': None, 'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 7. CAREERS247
# ═══════════════════════════════════════════════════════════════

def scrape_careers247():
    """Scrape careers247.in — TS + Central Govt Jobs."""
    print("\n📰 7. Careers247")
    jobs = []
    for url in ["https://www.careers247.in/search/label/Telangana%20Govt%20Jobs",
                "https://www.careers247.in/"]:
        html = fetch(url)
        if html:
            break
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 20:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if is_valid_job_posting(text):
            seen.add(dedup_key)
            jobs.append({
                'title': text[:200], 'organization': 'Various',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': href,
                'pdf_url': None, 'qualification': None,
                'source': 'careers247', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 8. 20GOVT (Telangana section)
# ═══════════════════════════════════════════════════════════════

def scrape_20govt():
    """Scrape telangana.20govt.com — WordPress TS job portal."""
    print("\n📰 8. 20Govt (TS)")
    jobs = []
    html = fetch("https://telangana.20govt.com/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 20:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if is_valid_job_posting(text):
            seen.add(dedup_key)
            jobs.append({
                'title': text[:200], 'organization': 'Various',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': href,
                'pdf_url': None, 'qualification': None,
                'source': '20govt', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 9. SARKARIJOBS (Telangana section)
# ═══════════════════════════════════════════════════════════════

def scrape_sarkarijobs():
    """Scrape telangana.sarkarijobs.com — TS-specific aggregator."""
    print("\n📰 9. SarkariJobs (TS)")
    jobs = []
    html = fetch("https://telangana.sarkarijobs.com/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 20:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if is_valid_job_posting(text) or 'recruitment' in text.lower():
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://telangana.sarkarijobs.com{href}"
            jobs.append({
                'title': text[:200], 'organization': 'Various',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': None, 'qualification': None,
                'source': 'sarkarijobs', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 10. JOBALERTSHUB
# ═══════════════════════════════════════════════════════════════

def scrape_jobalertshub():
    """Scrape jobalertshub.com — national portal, filter for TS."""
    print("\n📰 10. JobAlertsHub")
    jobs = []
    html = fetch("https://jobalertshub.com/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 20:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if is_valid_job_posting(text):
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://jobalertshub.com{href}"
            jobs.append({
                'title': text[:200], 'organization': 'Various',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': None, 'qualification': None,
                'source': 'jobalertshub', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 11. CAREERPOWER (Telangana section)
# ═══════════════════════════════════════════════════════════════

def scrape_careerpower():
    """Scrape careerpower.in Telangana govt jobs."""
    print("\n📰 11. CareerPower (TS)")
    jobs = []
    html = fetch("https://www.careerpower.in/telangana-govt-jobs")
    if not html:
        html = fetch("https://www.careerpower.in/blog/telangana-govt-jobs/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 20:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if is_valid_job_posting(text) or 'recruitment' in text.lower():
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://www.careerpower.in{href}"
            jobs.append({
                'title': text[:200], 'organization': 'Various',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': None, 'qualification': None,
                'source': 'careerpower', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 12. ANDHRA JYOTHY (Telugu newspaper)
# ═══════════════════════════════════════════════════════════════

def scrape_andhrajyothy():
    """Scrape Andhra Jyothy — Telugu newspaper jobs section."""
    print("\n📰 12. Andhra Jyothy")
    jobs = []
    html = fetch("https://www.andhrajyothy.com/jobs")
    if not html:
        html = fetch("https://www.andhrajyothy.com/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    keywords = ['RECRUITMENT', 'NOTIFICATION', 'నోటిఫికేషన్', 'ఉద్యోగాలు',
                'నియామకం', 'VACANCY', 'POSTS', 'ఖాళీలు']
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 15:
            continue
        dedup_key = text[:50].lower()
        if dedup_key in seen:
            continue
        if any(kw in text.upper() for kw in keywords):
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://www.andhrajyothy.com{href}"
            jobs.append({
                'title': text[:200], 'organization': 'Various (Andhra Jyothy)',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': None, 'qualification': None,
                'source': 'andhrajyothy', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 13. TESTBOOK (Telangana section)
# ═══════════════════════════════════════════════════════════════

def scrape_testbook():
    """Scrape testbook.com Telangana govt jobs (may be JS-rendered)."""
    print("\n📰 13. Testbook (TS)")
    jobs = []
    html = fetch("https://testbook.com/govt-jobs-in-telangana")
    if not html:
        print("   ❌ Failed (likely JS-rendered)")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 20:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if is_valid_job_posting(text) or 'recruitment' in text.lower():
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://testbook.com{href}"
            jobs.append({
                'title': text[:200], 'organization': 'Various',
                'category': detect_category(text),
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': None, 'qualification': None,
                'source': 'testbook', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 14. TSLPRB (Police Recruitment Board)
# ═══════════════════════════════════════════════════════════════

def scrape_tslprb():
    """Scrape tgprb.in — TS Police Recruitment Board."""
    print("\n📰 14. TSLPRB")
    jobs = []
    html = fetch("https://www.tgprb.in/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    keywords = ['RECRUITMENT', 'NOTIFICATION', 'CONSTABLE', 'SI',
                'VACANCY', 'POSTS', 'APPLICATION', 'ADMIT']
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 10:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if any(kw in text.upper() for kw in keywords):
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://www.tgprb.in{href}"
            pdf_url = full_url if full_url.endswith('.pdf') else None
            jobs.append({
                'title': text[:200], 'organization': 'TSLPRB',
                'category': 'police',
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': pdf_url, 'qualification': None,
                'source': 'tslprb', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 15. TREI-RB (Residential Education Recruitment)
# ═══════════════════════════════════════════════════════════════

def scrape_treirb():
    """Scrape treirb.telangana.gov.in — TS Residential Ed Recruitment."""
    print("\n📰 15. TREI-RB")
    jobs = []
    html = fetch("https://treirb.telangana.gov.in/")
    if not html:
        html = fetch("https://treirb.cgg.gov.in/home")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    keywords = ['RECRUITMENT', 'NOTIFICATION', 'TEACHER', 'PGT', 'TGT',
                'LECTURER', 'VACANCY', 'POSTS']
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 10:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if any(kw in text.upper() for kw in keywords):
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://treirb.telangana.gov.in{href}"
            pdf_url = full_url if full_url.endswith('.pdf') else None
            jobs.append({
                'title': text[:200], 'organization': 'TREI-RB',
                'category': 'teaching',
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': pdf_url, 'qualification': None,
                'source': 'treirb', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 16. TGSPDCL (Southern Power Distribution)
# ═══════════════════════════════════════════════════════════════

def scrape_tgspdcl():
    """Scrape tgsouthernpower.org — TGSPDCL recruitment."""
    print("\n📰 16. TGSPDCL")
    jobs = []
    html = fetch("https://tgsouthernpower.org/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    keywords = ['RECRUITMENT', 'NOTIFICATION', 'VACANCY', 'ENGINEER',
                'LINEMAN', 'APPLICATION']
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 10:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if any(kw in text.upper() for kw in keywords):
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://tgsouthernpower.org{href}"
            jobs.append({
                'title': text[:200], 'organization': 'TGSPDCL',
                'category': 'engineering',
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': None, 'qualification': None,
                'source': 'tgspdcl', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 17. TOMCOM (Telangana Overseas Manpower)
# ═══════════════════════════════════════════════════════════════

def scrape_tomcom():
    """Scrape tomcom.telangana.gov.in — overseas job opportunities."""
    print("\n📰 17. TOMCOM")
    jobs = []
    html = fetch("https://tomcom.telangana.gov.in/")
    if not html:
        print("   ❌ Failed")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 10:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if any(kw in text.upper() for kw in ['JOB', 'VACANCY', 'RECRUITMENT',
                                              'REGISTRATION', 'OVERSEAS', 'ABROAD']):
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://tomcom.telangana.gov.in{href}"
            jobs.append({
                'title': text[:200], 'organization': 'TOMCOM',
                'category': 'general',
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': None, 'qualification': None,
                'source': 'tomcom', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs")
    return jobs


# ═══════════════════════════════════════════════════════════════
# 18. DEET (Digital Employment Exchange of Telangana)
# ═══════════════════════════════════════════════════════════════

def scrape_deet():
    """Scrape deet.telangana.gov.in — Digital Employment Exchange (JS-rendered)."""
    print("\n📰 18. DEET")
    jobs = []
    html = fetch("https://deet.telangana.gov.in/")
    if not html:
        print("   ❌ Failed (likely JS-rendered SPA)")
        return jobs
    soup = BeautifulSoup(html, 'html.parser')
    # DEET is mostly a JS SPA — extract what we can from initial HTML
    seen = set()
    for a in soup.find_all('a', href=True):
        text = a.get_text(strip=True)
        href = a['href']
        if not text or len(text) < 10:
            continue
        dedup_key = text[:60].lower()
        if dedup_key in seen:
            continue
        if any(kw in text.upper() for kw in ['JOB', 'OPENING', 'HIRING', 'VACANCY']):
            seen.add(dedup_key)
            full_url = href if href.startswith('http') else f"https://deet.telangana.gov.in{href}"
            jobs.append({
                'title': text[:200], 'organization': 'DEET',
                'category': 'general',
                'vacancies': extract_vacancies(text),
                'last_date': None, 'apply_url': full_url,
                'pdf_url': None, 'qualification': None,
                'source': 'deet', 'posted_date': None,
                'districts': ['All Telangana'],
            })
    print(f"   ✅ {len(jobs)} jobs (limited — SPA site)")
    return jobs


# ═══════════════════════════════════════════════════════════════
# REGISTRY: All scrapers accessible by name
# ═══════════════════════════════════════════════════════════════

ALL_SCRAPERS = {
    'freejobalert': scrape_freejobalert,
    'tgpsc': scrape_tgpsc,
    'sarkariresult': scrape_sarkariresult,
    'eenadu': scrape_eenadu,
    'sakshi': scrape_sakshi,
    'indgovtjobs': scrape_indgovtjobs,
    'careers247': scrape_careers247,
    '20govt': scrape_20govt,
    'sarkarijobs': scrape_sarkarijobs,
    'jobalertshub': scrape_jobalertshub,
    'careerpower': scrape_careerpower,
    'andhrajyothy': scrape_andhrajyothy,
    'testbook': scrape_testbook,
    'tslprb': scrape_tslprb,
    'treirb': scrape_treirb,
    'tgspdcl': scrape_tgspdcl,
    'tomcom': scrape_tomcom,
    'deet': scrape_deet,
}
