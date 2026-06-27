"""
dedup_engine.py — Cross-source deduplication for TJS App
Handles: Same job posted on FreeJobAlert + Sarkari Result + Eenadu etc.

Strategy (3-layer):
1. Exact match: organization + normalized title hash
2. Fuzzy match: title similarity > 85% within same org
3. URL match: same apply_url or pdf_url = same job

Priority order (when duplicates found, keep the richest record):
  FreeJobAlert > TGPSC > Sarkari Result > Eenadu > Sakshi
  (FreeJobAlert has structured dates/qualification; TGPSC has official PDFs)
"""
import re
import hashlib
from difflib import SequenceMatcher


# Source priority — higher = preferred when deduplicating
SOURCE_PRIORITY = {
    'freejobalert': 5,  # Best: structured table, all fields
    'tgpsc': 4,         # Official PDFs + notification numbers
    'sarkariresult': 3, # Good coverage, some structure
    'eenadu': 2,        # Telugu-first
    'sakshi': 1,        # Telugu-first
}


def normalize_title(title):
    """
    Normalize title for comparison:
    - lowercase
    - remove special chars, extra spaces
    - remove common prefixes/suffixes
    - strip org names (they're in a separate field)
    """
    if not title:
        return ''
    t = title.lower().strip()
    # Remove org prefix pattern: "TGPSC – " or "TGPSC - "
    t = re.sub(r'^[\w\s]+\s*[–\-]\s*', '', t)
    # Remove "online form 2026", "offline form 2026" suffixes
    t = re.sub(r'\s*(online|offline)\s*form\s*\d{4}', '', t)
    # Remove notification numbers
    t = re.sub(r'notification\s*no[.:]?\s*[\d/\w]+', '', t)
    # Normalize whitespace and special chars
    t = re.sub(r'[^a-z0-9\s]', ' ', t)
    t = re.sub(r'\s+', ' ', t).strip()
    return t


def title_hash(title, org):
    """Generate a hash key for exact dedup matching."""
    normalized = f"{org.lower().strip()}|{normalize_title(title)}"
    return hashlib.md5(normalized.encode()).hexdigest()


def title_similarity(title1, title2):
    """Compute similarity ratio between two titles (0.0 - 1.0)."""
    n1 = normalize_title(title1)
    n2 = normalize_title(title2)
    if not n1 or not n2:
        return 0.0
    return SequenceMatcher(None, n1, n2).ratio()


def merge_job_records(primary, secondary):
    """
    Merge two job records, keeping primary's values but filling
    gaps from secondary (e.g., primary has no last_date but secondary does).
    """
    merged = primary.copy()
    
    # Fields to fill from secondary if primary is empty/None
    fill_fields = ['last_date', 'posted_date', 'qualification', 'advt_no',
                   'vacancies', 'pdf_url', 'apply_url']
    
    for field in fill_fields:
        primary_val = merged.get(field)
        secondary_val = secondary.get(field)
        
        if not primary_val and secondary_val:
            merged[field] = secondary_val
        elif field == 'vacancies' and (not primary_val or primary_val == 0) and secondary_val:
            merged[field] = secondary_val
    
    # Track all sources this job was found on
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
    Deduplicate jobs across all sources using 3-layer matching.
    
    Args:
        jobs: List of job dicts from all scrapers
        similarity_threshold: Fuzzy match threshold (0.0-1.0, default 0.82)
    
    Returns:
        Deduplicated list of jobs (richest record kept for each unique job)
    
    Stats:
        Prints dedup statistics
    """
    if not jobs:
        return []
    
    # Sort by source priority (highest first — so best record is "primary")
    jobs_sorted = sorted(jobs, 
                         key=lambda j: SOURCE_PRIORITY.get(j.get('source', ''), 0), 
                         reverse=True)
    
    # Layer 1: Exact hash match
    hash_index = {}       # hash -> job index in deduped list
    url_index = {}        # url -> job index in deduped list
    deduped = []
    
    stats = {
        'input': len(jobs),
        'exact_dupes': 0,
        'fuzzy_dupes': 0,
        'url_dupes': 0,
        'output': 0,
    }
    
    for job in jobs_sorted:
        title = job.get('title', '')
        org = job.get('organization', '')
        apply_url = job.get('apply_url', '')
        
        # ─── Layer 1: Exact title+org hash ───
        h = title_hash(title, org)
        if h in hash_index:
            # Merge into existing record
            idx = hash_index[h]
            deduped[idx] = merge_job_records(deduped[idx], job)
            stats['exact_dupes'] += 1
            continue
        
        # ─── Layer 2: URL match ───
        if apply_url and apply_url in url_index:
            idx = url_index[apply_url]
            deduped[idx] = merge_job_records(deduped[idx], job)
            stats['url_dupes'] += 1
            continue
        
        # ─── Layer 3: Fuzzy title match within same org ───
        is_dupe = False
        for idx, existing in enumerate(deduped):
            # Only fuzzy-match within same or similar org
            existing_org = existing.get('organization', '').upper()
            job_org = org.upper()
            
            # Orgs must match or both be generic
            org_match = (existing_org == job_org or 
                        existing_org in job_org or 
                        job_org in existing_org or
                        (existing_org in ('TELANGANA GOVT', 'VARIOUS', 'VARIOUS (TELANGANA)') and
                         job_org in ('TELANGANA GOVT', 'VARIOUS', 'VARIOUS (TELANGANA)')))
            
            if not org_match:
                continue
            
            sim = title_similarity(existing.get('title', ''), title)
            if sim >= similarity_threshold:
                deduped[idx] = merge_job_records(deduped[idx], job)
                stats['fuzzy_dupes'] += 1
                is_dupe = True
                break
        
        if is_dupe:
            continue
        
        # ─── New unique job — add to deduped list ───
        job['sources_found'] = [job.get('source', '')]
        deduped.append(job)
        idx = len(deduped) - 1
        hash_index[h] = idx
        if apply_url:
            url_index[apply_url] = idx
    
    stats['output'] = len(deduped)
    
    # Print stats
    print(f"\n   📊 DEDUP STATS:")
    print(f"      Input:        {stats['input']} jobs")
    print(f"      Exact dupes:  {stats['exact_dupes']} removed")
    print(f"      URL dupes:    {stats['url_dupes']} removed")
    print(f"      Fuzzy dupes:  {stats['fuzzy_dupes']} removed (threshold: {similarity_threshold})")
    print(f"      Output:       {stats['output']} unique jobs")
    print(f"      Reduction:    {stats['input'] - stats['output']} removed ({(1 - stats['output']/stats['input'])*100:.1f}%)")
    
    # Show multi-source jobs
    multi_source = [j for j in deduped if len(j.get('sources_found', [])) > 1]
    if multi_source:
        print(f"\n   🔗 Jobs found on MULTIPLE sources ({len(multi_source)}):")
        for j in multi_source[:5]:
            print(f"      • {j['title'][:60]} → {j['sources_found']}")
    
    return deduped


# ─── STANDALONE TEST ───
if __name__ == '__main__':
    import json
    import os
    
    print("=" * 65)
    print("🧪 DEDUP ENGINE TEST")
    print("=" * 65)
    
    # Load the final_results.json from previous run
    results_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'final_results.json')
    
    if not os.path.exists(results_path):
        print(f"❌ final_results.json not found. Run tjs_scraper_final.py first.")
        exit(1)
    
    with open(results_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    jobs = data['jobs']
    print(f"\n   Loaded {len(jobs)} jobs from final_results.json")
    print(f"   Sources: {set(j['source'] for j in jobs)}")
    
    # Run dedup
    unique_jobs = deduplicate_jobs(jobs)
    
    # Category breakdown after dedup
    print(f"\n   📊 AFTER DEDUP — BY CATEGORY:")
    cats = {}
    for j in unique_jobs:
        cats[j['category']] = cats.get(j['category'], 0) + 1
    for cat, count in sorted(cats.items(), key=lambda x: -x[1]):
        print(f"      {cat:<15}: {count}")
    
    # Source breakdown after dedup
    print(f"\n   📊 AFTER DEDUP — BY PRIMARY SOURCE:")
    sources = {}
    for j in unique_jobs:
        sources[j['source']] = sources.get(j['source'], 0) + 1
    for src, count in sorted(sources.items(), key=lambda x: -x[1]):
        print(f"      {src:<15}: {count}")
    
    # Save deduped results
    deduped_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'deduped_results.json')
    with open(deduped_path, 'w', encoding='utf-8') as f:
        json.dump({
            'run_date': data['run_date'],
            'total_before_dedup': len(jobs),
            'total_after_dedup': len(unique_jobs),
            'jobs': unique_jobs,
        }, f, indent=2, ensure_ascii=False, default=str)
    
    print(f"\n   💾 Saved {len(unique_jobs)} unique jobs to: deduped_results.json")
    print("   ✅ Done!")
