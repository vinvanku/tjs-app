# TJS App — Production Scraper v2.0

> Telangana Government Jobs Scraper — 18 sources, Telangana-filtered, deduplicated, enriched.

## 🚀 Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Dry run (outputs to CSV/JSON, no DB writes)
python main.py --dry-run

# Full run (scrape + upsert to Supabase)
python main.py

# Single source only
python main.py --source freejobalert --dry-run

# Fast mode (skip detail pages + enrichment)
python main.py --dry-run --skip-details --skip-enrichment
```

## 📊 Sources (18 active)

| # | Source | URL | Type | Jobs |
|---|--------|-----|------|------|
| 1 | **FreeJobAlert** | freejobalert.com/telangana-government-jobs/ | Structured table | ~22 |
| 2 | **TGPSC Official** | websitenew.tgpsc.gov.in | Govt notifications | ~17 |
| 3 | **Sarkari Result** | sarkariresult.com/telangana/ | Aggregator | ~70 |
| 4 | **Eenadu Pratibha** | pratibha.eenadu.net | Telugu newspaper | ~14 |
| 5 | **Sakshi Education** | education.sakshi.com | Telugu newspaper | ~16 |
| 6 | **IndGovtJobs** | telangana.indgovtjobs.net | TS aggregator | ~77 |
| 7 | **Careers247** | careers247.in | TS + Central | ~42 |
| 8 | **20Govt** | telangana.20govt.com | WordPress portal | ~32 |
| 9 | **SarkariJobs** | telangana.sarkarijobs.com | TS aggregator | ~17 |
| 10 | **JobAlertsHub** | jobalertshub.com | National | ~23 |
| 11 | **CareerPower** | careerpower.in/telangana-govt-jobs | Exam prep | ~18 |
| 12 | **Andhra Jyothy** | andhrajyothy.com | Telugu newspaper | ~13 |
| 13 | **Testbook** | testbook.com/govt-jobs-in-telangana | Exam prep | ~14 |
| 14 | **TSLPRB** | tgprb.in | Police Board (Official) | ~4 |
| 15 | **TREI-RB** | treirb.telangana.gov.in | Education Board (Official) | ~9 |
| 16 | **TGSPDCL** | tgsouthernpower.org | Power Distribution | ~5 |
| 17 | **TOMCOM** | tomcom.telangana.gov.in | Overseas Jobs | ~22 |
| 18 | **DEET** | deet.telangana.gov.in | Employment Exchange | Limited (SPA) |

**Expected output**: 300-400 unique jobs per run.

## 🔧 Pipeline Architecture

```
Scrape (18 sources) → Remove Non-Jobs → Telangana Filter → 3-Layer Dedup → Normalize Categories → Enrich URLs → Upsert/Export
```

### Pipeline Steps:
1. **Scrape**: curl_cffi with Chrome TLS impersonation (fastest, bypasses anti-bot)
2. **Remove Non-Jobs**: Filters answer keys, results, memos, study material
3. **Telangana Filter**: Rejects other state jobs (UP, MP, Bihar...), keeps national-level (SSC, RRB)
4. **Deduplication**: Hash match → URL match → Fuzzy match (82% threshold)
5. **Category Normalize**: 80+ raw labels → 17 standard values
6. **Enrichment** (optional): Google search for missing URLs and dates

## 📁 File Structure

```
production_scraper/
├── main.py              # Orchestrator (CLI entry point)
├── scrapers.py          # All 18 source scrapers
├── dedup_engine.py      # 3-layer deduplication
├── telangana_filter.py  # State-level job filter
├── category_detector.py # Category normalization (17 values)
├── enrichment.py        # URL lookup + non-job removal
├── requirements.txt     # Python dependencies
├── .env                 # Environment variables (create this)
└── output/              # CSV/JSON exports (dry-run mode)
```

## ⚙️ Environment Variables

Create a `.env` file:

```env
SUPABASE_URL=https://bkjkcdsvezviuytdwlzg.supabase.co
SUPABASE_KEY=your-service-role-key-here
```

## 🗄️ Supabase Schema

Table: `jobs`

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | auto |
| title | text | max 200 chars |
| organization | text | max 100 chars |
| vacancies | integer | default 0 |
| category | text | CHECK constraint (17 values) |
| last_date | date | ISO format |
| source | text | CHECK constraint |
| source_url | text | Best URL (apply > pdf > listing) |
| qualification | text | max 200 chars |
| district | text | default 'All Telangana' |
| is_free | boolean | default false |
| description | text | PDF link as markdown |
| is_active | boolean | default true |
| created_at | timestamptz | auto |
| updated_at | timestamptz | auto |

**Category values**: `general`, `police`, `health`, `engineering`, `revenue`, `teaching`, `banking`, `railway`, `research`, `education`, `agriculture`, `forest`, `judicial`, `defense`, `postal`, `insurance`, `staff_selection`

## 🤖 GitHub Actions (Automated)

Add to `.github/workflows/scrape.yml`:

```yaml
name: TJS Scraper
on:
  schedule:
    - cron: '30 0 * * *'   # 6:00 AM IST
    - cron: '30 12 * * *'  # 6:00 PM IST
  workflow_dispatch:

jobs:
  scrape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r scraper/requirements.txt
      - run: python scraper/main.py --skip-enrichment
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_KEY: ${{ secrets.SUPABASE_KEY }}
```

## 📈 Performance

| Metric | Value |
|--------|-------|
| Total scrape time | ~15-25 seconds |
| Sources attempted | 18 |
| Raw jobs | ~400-500 |
| After filter + dedup | ~300-400 unique |
| HTTP method | curl_cffi (Chrome TLS) |
| Rate limiting | 0.4s between detail pages |

## 🛡️ Error Handling

- Each source scraper is independent — one failure doesn't crash others
- 3 retries with exponential backoff on each request
- Graceful fallback: curl_cffi → cloudscraper → requests
- Non-zero exit code if ALL sources fail
- Detailed logging to stdout (captured by GitHub Actions)
