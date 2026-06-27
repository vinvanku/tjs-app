"""
TJS App — Main Scraper Orchestrator
====================================
Scrapes 5 Telangana govt job sources, deduplicates, and upserts to Supabase.

Sources (in priority order):
  1. FreeJobAlert — structured table, best quality
  2. TGPSC Official — notifications + PDF links
  3. Sarkari Result — broad coverage, filtered for Telangana
  4. Eenadu Pratibha — Telugu-first
  5. Sakshi Education — Telugu-first

Method: curl_cffi (Chrome TLS impersonation) — fastest, no proxy needed.

Usage:
    python main.py              # Scrape all sources + upsert to Supabase
    python main.py --dry-run    # Scrape only, don't write to DB (prints results)
    python main.py --source freejobalert  # Scrape single source

Environment Variables:
    SUPABASE_URL  - Your Supabase project URL
    SUPABASE_KEY  - Your Supabase service role key (NOT anon key)
"""

import os
import sys
import json
import logging
import argparse
from datetime import datetime, date
from pathlib import Path

# Load .env if present (for local runs)
from dotenv import load_dotenv
env_path = Path(__file__).parent / '.env'
load_dotenv(env_path)

from supabase import create_client, Client

# Local imports
from scrapers import (
    scrape_freejobalert,
    scrape_tgpsc,
    scrape_sarkariresult,
    scrape_eenadu,
    scrape_sakshi,
)
from dedup_engine import deduplicate_jobs

# ─────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")


# ─────────────────────────────────────────────────────────
# Supabase Operations
# ─────────────────────────────────────────────────────────

def get_supabase_client() -> Client:
    """Create and return Supabase client."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise EnvironmentError(
            "SUPABASE_URL and SUPABASE_KEY environment variables are required.\n"
            "Set them before running:\n"
            "  export SUPABASE_URL='https://your-project.supabase.co'\n"
            "  export SUPABASE_KEY='your-service-role-key'"
        )
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def upsert_jobs(client: Client, jobs: list[dict]) -> dict:
    """
    Upsert jobs to Supabase `jobs` table.
    Uses title+organization as the dedup key.
    
    Returns:
        dict with counts: inserted, updated, skipped, errors
    """
    stats = {'inserted': 0, 'updated': 0, 'skipped': 0, 'errors': 0}
    
    for job in jobs:
        try:
            # Map our scraper fields to Supabase schema
            record = {
                'title': job.get('title', '')[:200],
                'organization': job.get('organization', 'Telangana Govt')[:100],
                'category': job.get('category', 'general'),
                'vacancies': job.get('vacancies', 0) or 0,
                'last_date': job.get('last_date'),
                'apply_start_date': job.get('posted_date'),
                'qualification': job.get('qualification', '')[:200] if job.get('qualification') else None,
                'apply_url': job.get('apply_url'),
                'pdf_url': job.get('pdf_url'),
                'source': job.get('source', 'manual'),
                'districts': job.get('districts', ['All Telangana']),
                'fee_general': job.get('fee_general', 0) or 0,
                'fee_sc_st': job.get('fee_sc_st', 0) or 0,
                'is_active': True,
                'updated_at': datetime.now().isoformat(),
            }
            
            # Remove None values
            record = {k: v for k, v in record.items() if v is not None}
            
            # Check if job already exists (by title + org)
            existing = client.table('jobs').select('id')\
                .eq('title', record['title'])\
                .eq('organization', record['organization'])\
                .execute()
            
            if existing.data:
                # Update existing record
                client.table('jobs').update(record)\
                    .eq('id', existing.data[0]['id'])\
                    .execute()
                stats['updated'] += 1
            else:
                # Insert new record
                record['posted_date'] = datetime.now().isoformat()
                client.table('jobs').insert(record).execute()
                stats['inserted'] += 1
                
        except Exception as e:
            logger.warning(f"Error upserting job '{job.get('title', '')[:50]}': {e}")
            stats['errors'] += 1
    
    return stats


def mark_expired_jobs(client: Client) -> int:
    """Mark jobs with past last_date as inactive. Returns count."""
    today = date.today().isoformat()
    try:
        result = client.table('jobs')\
            .update({'is_active': False})\
            .lt('last_date', today)\
            .eq('is_active', True)\
            .execute()
        count = len(result.data) if result.data else 0
        logger.info(f"Marked {count} expired jobs as inactive")
        return count
    except Exception as e:
        logger.warning(f"Error marking expired jobs: {e}")
        return 0


# ─────────────────────────────────────────────────────────
# Main Orchestrator
# ─────────────────────────────────────────────────────────

def run(dry_run: bool = False, single_source: str = None):
    """
    Main scraping pipeline:
    1. Scrape all sources (or single source)
    2. Deduplicate across sources
    3. Upsert to Supabase (unless dry_run)
    4. Mark expired jobs
    """
    print("═" * 65)
    print("🚀 TJS SCRAPER — Production Run")
    print(f"   Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"   Mode: {'DRY RUN (no DB writes)' if dry_run else 'LIVE (writing to Supabase)'}")
    if single_source:
        print(f"   Source: {single_source} only")
    print("═" * 65)
    
    # ─── Step 1: Scrape ───
    all_scrapers = {
        'freejobalert': scrape_freejobalert,
        'tgpsc': scrape_tgpsc,
        'sarkariresult': scrape_sarkariresult,
        'eenadu': scrape_eenadu,
        'sakshi': scrape_sakshi,
    }
    
    if single_source:
        if single_source not in all_scrapers:
            print(f"❌ Unknown source: {single_source}")
            print(f"   Available: {', '.join(all_scrapers.keys())}")
            sys.exit(1)
        scrapers_to_run = {single_source: all_scrapers[single_source]}
    else:
        scrapers_to_run = all_scrapers
    
    all_jobs = []
    for name, fn in scrapers_to_run.items():
        try:
            jobs = fn()
            all_jobs.extend(jobs)
        except Exception as e:
            logger.error(f"❌ {name} crashed: {e}")
    
    print(f"\n   📋 Raw total: {len(all_jobs)} jobs from {len(scrapers_to_run)} sources")
    
    # ─── Step 2: Deduplicate ───
    unique_jobs = deduplicate_jobs(all_jobs)
    
    # ─── Step 3: Upsert to Supabase ───
    if dry_run:
        print(f"\n   🏁 DRY RUN complete. {len(unique_jobs)} unique jobs ready.")
        print(f"   Would upsert to: {SUPABASE_URL or '(not configured)'}")
        
        # Show sample
        print(f"\n   📝 Sample jobs (first 5):")
        for j in unique_jobs[:5]:
            print(f"      • [{j['category']:12s}] {j['title'][:60]}")
            print(f"        Last: {j.get('last_date', 'N/A')} | Src: {j['source']}")
    else:
        print(f"\n   📤 Upserting {len(unique_jobs)} jobs to Supabase...")
        try:
            client = get_supabase_client()
            stats = upsert_jobs(client, unique_jobs)
            print(f"\n   ✅ UPSERT COMPLETE:")
            print(f"      New:     {stats['inserted']}")
            print(f"      Updated: {stats['updated']}")
            print(f"      Errors:  {stats['errors']}")
            
            # Mark expired
            expired = mark_expired_jobs(client)
            print(f"      Expired: {expired} marked inactive")
            
        except EnvironmentError as e:
            print(f"\n   ❌ {e}")
            sys.exit(1)
        except Exception as e:
            logger.error(f"Supabase error: {e}")
            sys.exit(1)
    
    # ─── Summary ───
    print(f"\n{'═' * 65}")
    print(f"✅ Done! {len(unique_jobs)} unique jobs processed.")
    print(f"{'═' * 65}")
    
    return unique_jobs


# ─────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='TJS App Scraper')
    parser.add_argument('--dry-run', action='store_true',
                        help='Scrape without writing to database')
    parser.add_argument('--source', type=str, default=None,
                        help='Scrape single source (freejobalert/tgpsc/sarkariresult/eenadu/sakshi)')
    args = parser.parse_args()
    
    run(dry_run=args.dry_run, single_source=args.source)
