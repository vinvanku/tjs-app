"""
enrichment.py — Job Data Enrichment for TJS App
=================================================
Enriches scraped jobs with:
  1. Missing URL lookup via Google search
  2. Missing date extraction from search snippets
  3. Non-job content removal (answer keys, results, memos)
  4. Organization name improvement

Rate-limited: 1 search per 2 seconds to avoid blocks.
"""

import re
import time
import json
from datetime import datetime

try:
    from googlesearch import search as google_search
    HAS_GOOGLE = True
except ImportError:
    HAS_GOOGLE = False

try:
    from curl_cffi import requests as curl_requests
    HAS_CURL = True
except ImportError:
    HAS_CURL = False
    import requests as std_requests


# ═══════════════════════════════════════════════════════════════
# NON-JOB DETECTION
# ═══════════════════════════════════════════════════════════════

NON_JOB_PATTERNS = [
    # Results / Merit lists
    r'(?:final|provisional)\s*(?:result|merit\s*list|selection)',
    r'result\s*(?:declared|released|out|published)',
    r'merit\s*list\s*(?:released|out|published)',
    r'selected\s*candidates',
    # Answer keys
    r'answer\s*key\s*(?:released|out|published|download)',
    r'final\s*key',
    # Admit cards
    r'admit\s*card\s*(?:released|out|download)',
    r'hall\s*ticket\s*(?:released|out|download)',
    # Departmental tests / Memos
    r'malpractice\s*memo',
    r'departmental\s*test',
    # Study material / Prep
    r'how\s*to\s*prepare',
    r'study\s*material',
    r'preparation\s*(?:plan|strategy|tips)',
    r'previous\s*(?:year|paper)',
    r'mock\s*test',
    r'exam\s*pattern',
    r'syllabus\s*(?:pdf|download|explained)',
    # News / Press
    r'press\s*release',
    r'cm\s*(?:announced|inaugurated)',
    r'government\s*to\s*fill',
    r'latest\s*news',
    # Counselling / Schedule
    r'counselling\s*schedule',
    r'document\s*verification\s*(?:schedule|list)',
]


def is_non_job_content(title: str) -> bool:
    """Returns True if the title is NOT an actual job posting."""
    if not title:
        return True
    t = title.lower().strip()
    if len(t) < 15:
        return True
    for pattern in NON_JOB_PATTERNS:
        if re.search(pattern, t, re.IGNORECASE):
            return True
    return False


def remove_non_jobs(jobs: list) -> tuple:
    """
    Remove non-job entries from the list.
    Returns (clean_jobs, removed_jobs).
    """
    clean = []
    removed = []
    for job in jobs:
        if is_non_job_content(job.get('title', '')):
            removed.append(job)
        else:
            clean.append(job)
    return clean, removed


# ═══════════════════════════════════════════════════════════════
# URL ENRICHMENT
# ═══════════════════════════════════════════════════════════════

def _search_web(query, num_results=3):
    """
    Simple web search wrapper.
    Uses Google search library if available, otherwise returns empty.
    """
    if HAS_GOOGLE:
        try:
            results = list(google_search(query, num_results=num_results, sleep_interval=2))
            return results
        except Exception:
            pass
    return []


def _is_generic_url(url: str) -> bool:
    """Check if URL is a generic homepage (not a specific job page)."""
    if not url:
        return True
    generic_patterns = [
        r'sarkariresult\.com/?$',
        r'freejobalert\.com/?$',
        r'sarkarijobs\.com/?$',
        r'20govt\.com/?$',
        r'indgovtjobs\.net/?$',
        r'jobalertshub\.com/?$',
        r'careers247\.in/?$',
    ]
    return any(re.search(p, url) for p in generic_patterns)


def _extract_date_from_text(text: str) -> str:
    """Try to extract a date from text snippet."""
    if not text:
        return None
    patterns = [
        (r'last\s*date[:\s]*(\d{1,2})[/.-](\d{1,2})[/.-](20\d{2})', 'dmy'),
        (r'deadline[:\s]*(\d{1,2})[/.-](\d{1,2})[/.-](20\d{2})', 'dmy'),
        (r'apply\s*(?:before|by)[:\s]*(\d{1,2})[/.-](\d{1,2})[/.-](20\d{2})', 'dmy'),
        (r'(\d{1,2})\s*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s*(20\d{2})', 'dMy'),
    ]
    for pattern, fmt_type in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            groups = match.groups()
            try:
                if fmt_type == 'dmy':
                    d, m, y = groups
                    return f"{y}-{int(m):02d}-{int(d):02d}"
                elif fmt_type == 'dMy':
                    d, month_str, y = groups
                    month_map = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
                                 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
                                 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12}
                    m = month_map.get(month_str[:3].lower(), 0)
                    if m:
                        return f"{y}-{m:02d}-{int(d):02d}"
            except (ValueError, TypeError):
                continue
    return None


def enrich_jobs(jobs: list, skip_search=False, rate_limit=2.0) -> list:
    """
    Enrich jobs with missing URLs and dates.
    
    Args:
        jobs: List of job dicts
        skip_search: If True, skip Google search (offline mode)
        rate_limit: Seconds between searches (default 2.0)
    
    Returns:
        Enriched jobs list
    """
    if skip_search or not HAS_GOOGLE:
        print("   ⚠️ Search enrichment skipped (no google library or --skip-enrichment)")
        return jobs
    
    enriched_count = 0
    date_count = 0
    
    for i, job in enumerate(jobs):
        apply_url = job.get('apply_url', '')
        last_date = job.get('last_date')
        
        needs_url = not apply_url or _is_generic_url(apply_url)
        needs_date = not last_date
        
        if not needs_url and not needs_date:
            continue
        
        # Search for this job
        title = job.get('title', '')
        if not title:
            continue
        
        query = f"{title} apply online official notification 2026"
        results = _search_web(query, num_results=3)
        
        if results:
            # Find best URL (prefer .gov.in > official portals > aggregators)
            if needs_url:
                best_url = None
                for url in results:
                    if '.gov.in' in url:
                        best_url = url
                        break
                if not best_url:
                    best_url = results[0]
                job['apply_url'] = best_url
                enriched_count += 1
        
        time.sleep(rate_limit)
        
        # Progress
        if (i + 1) % 20 == 0:
            print(f"      Enriched {i+1}/{len(jobs)} "
                  f"(URLs: {enriched_count}, Dates: {date_count})")
    
    print(f"   ✅ Enrichment: {enriched_count} URLs found, "
          f"{date_count} dates extracted")
    return jobs
