"""
dedup_engine.py — Enhanced Cross-Source Deduplication for TJS App
=================================================================
3-layer deduplication:
  1. Exact match: organization + normalized title → MD5 hash
  2. URL match: same apply_url = same job
  3. Fuzzy match: title similarity > threshold within same org

Source priority (higher = keep when duplicates found):
  FreeJobAlert(10) > TGPSC(9) > TSLPRB(8) > TREIRB(7) > SarkariResult(6)
  > Eenadu(5) > Sakshi(4) > Aggregators(3) > Generic(1)
"""

import re
import hashlib
from difflib import SequenceMatcher


# Source priority — higher = preferred when deduplicating
SOURCE_PRIORITY = {
    'freejobalert': 10,   # Best: structured table, all fields, detail pages
    'tgpsc': 9,           # Official PDFs + notification numbers
    'tslprb': 8,          # Official police source
    'treirb': 7,          # Official education source
    'tgspdcl': 7,         # Official power source
    'tgnpdcl': 7,         # Official power source
    'sarkariresult': 6,   # Good coverage, some structure
    'eenadu': 5,          # Telugu-first
    'eenadu_pratibha': 5, # Telugu HTML version
    'sakshi': 4,          # Telugu-first
    'sakshi_english': 4,  # English version
    'andhrajyothy': 4,    # Telugu newspaper
    'indgovtjobs': 3,     # Aggregator
    'careers247': 3,      # Aggregator
    '20govt': 3,          # Aggregator
    'sarkarijobs': 3,     # Aggregator
    'jobalertshub': 3,    # Aggregator
    'careerpower': 3,     # Aggregator
    'testbook': 2,        # Exam prep site
    'tomcom': 2,          # Overseas
    'deet': 2,            # DEET (limited data)
    'kisce_sat': 1,       # Microsite
}


def normalize_title(title):
    """
    Normalize title for comparison:
    - lowercase, strip special chars
    - remove org prefixes, date suffixes
    - remove 'online form 2026' patterns
    """
    if not title:
        return ''
    t = title.lower().strip()
    # Remove org prefix: "TGPSC – " or "TGPSC - "
    t = re.sub(r'^[\w\s]+\s*[–\-]\s*', '', t)
    # Remove "online form 2024/2025/2026" suffixes
    t = re.sub(r'\s*(online|offline)\s*form\s*\d{4}', '', t)
    # Remove notification numbers
    t = re.sub(r'notification\s*no[.:]?\s*[\d/\w]+', '', t)
    # Remove year patterns at end
    t = re.sub(r'\s*20\d{2}\s*$', '', t)
    # Telugu + English: normalize whitespace and special chars
    t = re.sub(r'[^\w\s\u0C00-\u0C7F]', ' ', t)  # Keep Telugu Unicode block
    t = re.sub(r'\s+', ' ', t).strip()
    return t


def title_hash(title, org):
    """Generate MD5 hash for exact dedup."""
    normalized = f"{(org or '').lower().strip()}|{normalize_title(title)}"
    return hashlib.md5(normalized.encode()).hexdigest()


def title_similarity(title1, title2):
    """Compute similarity ratio between two titles (0.0-1.0)."""
    n1 = normalize_title(title1)
    n2 = normalize_title(title2)
    if not n1 or not n2:
        return 0.0
    return SequenceMatcher(None, n1, n2).ratio()


def merge_job_records(primary, secondary):
    """Merge two job records, keeping primary but filling gaps from secondary."""
    merged = primary.copy()
    fill_fields = ['last_date', 'posted_date', 'qualification', 'advt_no',
                   'vacancies', 'pdf_url', 'apply_url']
    for field in fill_fields:
        primary_val = merged.get(field)
        secondary_val = secondary.get(field)
        if not primary_val and secondary_val:
            merged[field] = secondary_val
        elif field == 'vacancies' and (not primary_val or primary_val == 0) and secondary_val:
            merged[field] = secondary_val
    # Track all sources
    sources = set()
    if 'sources_found' in merged:
        sources.update(merged['sources_found'])
    else:
        sources.add(merged.get('source', ''))
    sources.add(secondary.get('source', ''))
    merged['sources_found'] = list(sources)
    return merged


def deduplicate_jobs(jobs, similarity_threshold=0.82):
    """
    Deduplicate jobs using 3-layer matching.
    Returns deduplicated list (richest record kept).
    """
    if not jobs:
        return []
    
    # Sort by priority (highest first)
    jobs_sorted = sorted(
        jobs,
        key=lambda j: SOURCE_PRIORITY.get(j.get('source', ''), 0),
        reverse=True
    )
    
    hash_index = {}   # hash -> index in deduped
    url_index = {}    # url -> index in deduped
    deduped = []
    
    stats = {'input': len(jobs), 'exact': 0, 'url': 0, 'fuzzy': 0}
    
    for job in jobs_sorted:
        title = job.get('title', '')
        org = job.get('organization', '')
        apply_url = job.get('apply_url', '')
        
        # Layer 1: Exact hash
        h = title_hash(title, org)
        if h in hash_index:
            idx = hash_index[h]
            deduped[idx] = merge_job_records(deduped[idx], job)
            stats['exact'] += 1
            continue
        
        # Layer 2: URL match
        if apply_url and apply_url in url_index:
            idx = url_index[apply_url]
            deduped[idx] = merge_job_records(deduped[idx], job)
            stats['url'] += 1
            continue
        
        # Layer 3: Fuzzy match within same org
        is_dupe = False
        org_lower = org.lower().strip()
        for idx, existing in enumerate(deduped):
            existing_org = existing.get('organization', '').lower().strip()
            # Only fuzzy match within same or similar org
            if org_lower and existing_org and (
                org_lower == existing_org or
                org_lower in existing_org or
                existing_org in org_lower
            ):
                sim = title_similarity(title, existing.get('title', ''))
                if sim >= similarity_threshold:
                    deduped[idx] = merge_job_records(existing, job)
                    stats['fuzzy'] += 1
                    is_dupe = True
                    break
        
        if is_dupe:
            continue
        
        # New unique job
        idx = len(deduped)
        deduped.append(job)
        hash_index[h] = idx
        if apply_url:
            url_index[apply_url] = idx
    
    stats['output'] = len(deduped)
    reduction = (stats['input'] - stats['output']) / max(stats['input'], 1) * 100
    
    print(f"\n   📊 Dedup: {stats['input']} → {stats['output']} "
          f"({reduction:.1f}% reduction)")
    print(f"      Exact: {stats['exact']}, URL: {stats['url']}, "
          f"Fuzzy: {stats['fuzzy']}")
    
    return deduped
