"""
TJS App — Production Scraper Orchestrator (v2.0)
==================================================
Scrapes 18 Telangana job sources, filters, deduplicates, enriches,
and upserts to Supabase.

Usage:
    python main.py                    # Full run → Supabase
    python main.py --dry-run          # Scrape only → CSV + JSON output
    python main.py --source tgpsc     # Single source only
    python main.py --skip-details     # Skip detail page fetching
    python main.py --skip-enrichment  # Skip Google search enrichment

Environment Variables:
    SUPABASE_URL  - Your Supabase project URL
    SUPABASE_KEY  - Your Supabase service role key
"""

import os
import sys
import json
import csv
import time
import logging
import argparse
from datetime import datetime, date
from pathlib import Path

# Load .env if present
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / '.env')

from supabase import create_client, Client

# Local imports
from scrapers import ALL_SCRAPERS
from dedup_engine import deduplicate_jobs
from telangana_filter import filter_telangana_jobs
from category_detector import detect_category, normalize_category
from enrichment import remove_non_jobs, enrich_jobs

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")

OUTPUT_DIR = Path(__file__).parent / "output"
OUTPUT_DIR.mkdir(exist_ok=True)


# ═══════════════════════════════════════════════════════════════
# Supabase Operations
# ═══════════════════════════════════════════════════════════════

def get_supabase_client() -> Client:
    """Create Supabase client."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise EnvironmentError(
            "SUPABASE_URL and SUPABASE_KEY required.\n"
            "Set in .env or environment variables."
        )
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def upsert_jobs(client: Client, jobs: list) -> dict:
    """Upsert jobs to Supabase `jobs` table."""
    stats = {'inserted': 0, 'updated': 0, 'errors': 0}
    
    for job in jobs:
        try:
            best_url = job.get('apply_url') or job.get('pdf_url') or ''
            description = None
            pdf = job.get('pdf_url')
            if pdf and pdf != best_url:
                description = f"[📄 Notification PDF]({pdf})"
            
            record = {
                'title': job.get('title', '')[:200],
                'organization': job.get('organization', 'Telangana Govt')[:100],
                'category': normalize_category(job.get('category', 'general')),
                'vacancies': job.get('vacancies', 0) or 0,
                'last_date': job.get('last_date'),
                'qualification': (job.get('qualification', '')[:200]
                                  if job.get('qualification') else None),
                'source_url': best_url,
                'source': job.get('source', 'manual'),
                'district': (job.get('districts', ['All Telangana']) or ['All Telangana'])[0]
                            if isinstance(job.get('districts'), list)
                            else job.get('districts', 'All Telangana'),
                'is_active': True,
                'updated_at': datetime.now().isoformat(),
            }
            if description:
                record['description'] = description
            
            record = {k: v for k, v in record.items() if v is not None}
            
            # Check if exists
            existing = client.table('jobs').select('id')\
                .eq('title', record['title'])\
                .eq('organization', record['organization'])\
                .execute()
            
            if existing.data:
                client.table('jobs').update(record)\
                    .eq('id', existing.data[0]['id']).execute()
                stats['updated'] += 1
            else:
                client.table('jobs').insert(record).execute()
                stats['inserted'] += 1
                
        except Exception as e:
            logger.warning(f"Upsert error: '{job.get('title', '')[:40]}': {e}")
            stats['errors'] += 1
    
    return stats


def mark_expired_jobs(client: Client) -> int:
    """Mark jobs with past last_date as inactive."""
    today = date.today().isoformat()
    try:
        result = client.table('jobs')\
            .update({'is_active': False})\
            .lt('last_date', today)\
            .eq('is_active', True)\
            .execute()
        return len(result.data) if result.data else 0
    except Exception as e:
        logger.warning(f"Error marking expired: {e}")
        return 0


# ═══════════════════════════════════════════════════════════════
# Main Orchestrator
# ═══════════════════════════════════════════════════════════════

def run(dry_run=False, single_source=None, skip_details=False,
        skip_enrichment=False):
    """
    Main pipeline:
    1. Scrape all sources
    2. Remove non-job content
    3. Apply Telangana filter
    4. Deduplicate
    5. Normalize categories
    6. Enrich missing data
    7. Export / Upsert
    """
    start_time = time.time()
    
    print("═" * 70)
    print("🚀 TJS SCRAPER v2.0 — Production Run")
    print(f"   Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"   Mode: {'DRY RUN' if dry_run else 'LIVE (Supabase)'}")
    print(f"   Sources: {single_source or 'ALL 18'}")
    print(f"   Skip details: {skip_details}")
    print(f"   Skip enrichment: {skip_enrichment}")
    print("═" * 70)
    
    # ─── Step 1: Scrape ───
    print("\n📡 STEP 1: SCRAPING")
    print("─" * 50)
    
    if single_source:
        if single_source not in ALL_SCRAPERS:
            print(f"❌ Unknown source: {single_source}")
            print(f"   Available: {', '.join(ALL_SCRAPERS.keys())}")
            sys.exit(1)
        scrapers_to_run = {single_source: ALL_SCRAPERS[single_source]}
    else:
        scrapers_to_run = ALL_SCRAPERS
    
    all_jobs = []
    source_stats = {}
    
    for name, fn in scrapers_to_run.items():
        try:
            t0 = time.time()
            if name == 'freejobalert':
                jobs = fn(skip_details=skip_details)
            else:
                jobs = fn()
            elapsed = time.time() - t0
            all_jobs.extend(jobs)
            source_stats[name] = {'count': len(jobs), 'time': f"{elapsed:.1f}s"}
        except Exception as e:
            logger.error(f"❌ {name} crashed: {e}")
            source_stats[name] = {'count': 0, 'time': 'FAILED', 'error': str(e)}
    
    print(f"\n   📋 Raw total: {len(all_jobs)} jobs from {len(scrapers_to_run)} sources")
    
    # ─── Step 2: Remove non-jobs ───
    print("\n🧹 STEP 2: REMOVING NON-JOB CONTENT")
    print("─" * 50)
    
    all_jobs, removed_non_jobs = remove_non_jobs(all_jobs)
    print(f"   Removed: {len(removed_non_jobs)} non-job entries")
    print(f"   Remaining: {len(all_jobs)} jobs")
    
    # ─── Step 3: Telangana filter ───
    print("\n🔍 STEP 3: TELANGANA FILTER")
    print("─" * 50)
    
    all_jobs, rejected_jobs = filter_telangana_jobs(all_jobs)
    print(f"   Rejected (non-TS): {len(rejected_jobs)}")
    print(f"   Remaining: {len(all_jobs)} Telangana-relevant jobs")
    
    # ─── Step 4: Deduplicate ───
    print("\n🔄 STEP 4: DEDUPLICATION (3-layer)")
    print("─" * 50)
    
    unique_jobs = deduplicate_jobs(all_jobs)
    
    # ─── Step 5: Normalize categories ───
    print("\n🏷️ STEP 5: CATEGORY NORMALIZATION")
    print("─" * 50)
    
    for job in unique_jobs:
        raw_cat = job.get('category', 'general')
        job['category'] = normalize_category(raw_cat)
        # Also try detecting from title if still 'general'
        if job['category'] == 'general':
            job['category'] = detect_category(job.get('title', ''))
    
    from collections import Counter
    cat_counts = Counter(j['category'] for j in unique_jobs)
    print(f"   Categories: {dict(cat_counts.most_common(10))}")
    
    # ─── Step 6: Enrich ───
    print("\n🔗 STEP 6: ENRICHMENT")
    print("─" * 50)
    
    unique_jobs = enrich_jobs(unique_jobs, skip_search=skip_enrichment)
    
    # ─── Step 7: Output ───
    elapsed_total = time.time() - start_time
    
    print(f"\n{'═' * 70}")
    print(f"🏁 PIPELINE COMPLETE")
    print(f"{'═' * 70}")
    print(f"   Total time: {elapsed_total:.1f}s")
    print(f"   Final count: {len(unique_jobs)} unique Telangana jobs")
    print(f"\n   Source breakdown:")
    for src, stat in sorted(source_stats.items(), key=lambda x: -x[1].get('count', 0)):
        print(f"     {src:20s}: {stat['count']:3d} jobs ({stat['time']})")
    
    if dry_run:
        # Export to CSV + JSON
        timestamp = datetime.now().strftime('%Y%m%d_%H%M')
        
        csv_path = OUTPUT_DIR / f"tjs_jobs_{timestamp}.csv"
        json_path = OUTPUT_DIR / f"tjs_jobs_{timestamp}.json"
        
        columns = ['title', 'organization', 'category', 'vacancies',
                   'last_date', 'apply_url', 'pdf_url', 'qualification',
                   'source', 'posted_date', 'districts']
        
        with open(csv_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=columns, extrasaction='ignore')
            writer.writeheader()
            for job in unique_jobs:
                row = dict(job)
                if isinstance(row.get('districts'), list):
                    row['districts'] = ', '.join(row['districts'])
                writer.writerow(row)
        
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(unique_jobs, f, ensure_ascii=False, indent=2)
        
        print(f"\n   📁 CSV: {csv_path}")
        print(f"   📁 JSON: {json_path}")
        print(f"\n   🏁 DRY RUN complete. No DB writes.")
        
    else:
        # Upsert to Supabase
        print(f"\n   💾 Upserting to Supabase...")
        client = get_supabase_client()
        stats = upsert_jobs(client, unique_jobs)
        expired = mark_expired_jobs(client)
        
        print(f"   ✅ Inserted: {stats['inserted']}")
        print(f"   ♻️ Updated: {stats['updated']}")
        print(f"   ❌ Errors: {stats['errors']}")
        print(f"   ⏰ Expired: {expired}")
    
    return unique_jobs


# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='TJS Scraper v2.0')
    parser.add_argument('--dry-run', action='store_true',
                        help='Scrape only, output to CSV/JSON (no DB)')
    parser.add_argument('--source', type=str, default=None,
                        help='Scrape single source only')
    parser.add_argument('--skip-details', action='store_true',
                        help='Skip detail page fetching (faster)')
    parser.add_argument('--skip-enrichment', action='store_true',
                        help='Skip Google search enrichment')
    args = parser.parse_args()
    
    run(
        dry_run=args.dry_run,
        single_source=args.source,
        skip_details=args.skip_details,
        skip_enrichment=args.skip_enrichment,
    )
