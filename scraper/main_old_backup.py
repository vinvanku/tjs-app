"""
Telangana Jobs Scraper
======================
Scrapes government job notifications from:
  1. TGPSC (Telangana Government Public Service Commission) - tgpsc.gov.in
  2. Sakshi Education - sakshieducation.com

Inserts deduplicated results into Supabase with automatic categorization.

Usage:
    python main.py

Environment Variables:
    SUPABASE_URL  - Your Supabase project URL
    SUPABASE_KEY  - Your Supabase service role key (NOT anon key)
"""

import os
import re
import logging
from datetime import datetime, date
from typing import Optional
from dataclasses import dataclass, asdict

import requests
from bs4 import BeautifulSoup
from supabase import create_client, Client

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")

TGPSC_BASE_URL = "https://www.tgpsc.gov.in"
TGPSC_NEW_URL = "https://websitenew.tgpsc.gov.in"
TGPSC_NOTIFICATIONS_URL = TGPSC_NEW_URL  # Main page lists all notifications

SAKSHI_BASE_URL = "https://education.sakshi.com"
SAKSHI_JOBS_URL = f"{SAKSHI_BASE_URL}/notifications/govt-jobs"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9,te;q=0.8",
}

REQUEST_TIMEOUT = 30  # seconds


# ---------------------------------------------------------------------------
# Data Model
# ---------------------------------------------------------------------------

@dataclass
class JobListing:
    """Represents a scraped job notification."""
    title: str
    organization: str
    vacancies: int
    category: str
    last_date: Optional[str]  # ISO format: YYYY-MM-DD
    source: str
    source_url: Optional[str]
    qualification: Optional[str] = None
    district: Optional[str] = None
    is_free: bool = False
    description: Optional[str] = None

    def to_dict(self) -> dict:
        """Convert to dictionary for Supabase insertion."""
        data = asdict(self)
        # Remove None values to let DB defaults apply
        return {k: v for k, v in data.items() if v is not None}


# ---------------------------------------------------------------------------
# Category Detection
# ---------------------------------------------------------------------------

# Keyword patterns for category detection (order matters - first match wins)
CATEGORY_PATTERNS: list[tuple[str, list[str]]] = [
    ("police", [
        r"\bpolice\b", r"\bconstable\b", r"\bsi\b", r"\bsub.?inspector\b",
        r"\bexcise\b", r"\bfire\b", r"\bjail\b", r"\bwarder\b",
        r"\bsipahi\b", r"\bhavildar\b",
    ]),
    ("teaching", [
        r"\bteacher\b", r"\btgt\b", r"\bpgt\b", r"\bprt\b", r"\blecturer\b",
        r"\bprofessor\b", r"\bgurukulam\b", r"\bvidyalayam\b", r"\bschool\b",
        r"\beducation\b", r"\btet\b", r"\bdsc\b", r"\bfaculty\b",
        r"\bheadmaster\b", r"\bprincipal\b",
    ]),
    ("health", [
        r"\bhealth\b", r"\bmedical\b", r"\bnurse\b", r"\bnursing\b",
        r"\bdoctor\b", r"\bpharmacist\b", r"\blab.?technician\b",
        r"\bano\b", r"\bani\b", r"\bmho\b", r"\bstaff.?nurse\b",
        r"\bmbbs\b", r"\bdmho\b", r"\bparamedic\b", r"\bveterinary\b",
    ]),
    ("engineering", [
        r"\bengineer\b", r"\bengineering\b", r"\bae\b", r"\bdee\b",
        r"\bjunior.?engineer\b", r"\bassistant.?engineer\b",
        r"\btechnical\b", r"\belectrical\b", r"\bcivil\b", r"\bmechanical\b",
        r"\bit\b", r"\bcomputer\b", r"\bsoftware\b",
    ]),
    ("revenue", [
        r"\brevenue\b", r"\bvro\b", r"\bvra\b", r"\btahsildar\b",
        r"\bdeputy.?tahsildar\b", r"\bsurvey\b", r"\bpatwari\b",
        r"\bmro\b", r"\bjunior.?assistant\b", r"\bregistration\b",
    ]),
]


def detect_category(title: str) -> str:
    """
    Detect job category from title using keyword pattern matching.

    Args:
        title: The job notification title.

    Returns:
        Category string: police, teaching, health, engineering, revenue, or general.
    """
    title_lower = title.lower()

    for category, patterns in CATEGORY_PATTERNS:
        for pattern in patterns:
            if re.search(pattern, title_lower):
                return category

    return "general"


# ---------------------------------------------------------------------------
# Date Parsing
# ---------------------------------------------------------------------------

# Indian date formats commonly used in government notifications
DATE_FORMATS = [
    "%d-%m-%Y",       # 25-12-2024
    "%d/%m/%Y",       # 25/12/2024
    "%d.%m.%Y",       # 25.12.2024
    "%d-%m-%y",       # 25-12-24
    "%d/%m/%y",       # 25/12/24
    "%d %b %Y",       # 25 Dec 2024
    "%d %B %Y",       # 25 December 2024
    "%d-%b-%Y",       # 25-Dec-2024
    "%d-%B-%Y",       # 25-December-2024
    "%B %d, %Y",      # December 25, 2024
    "%b %d, %Y",      # Dec 25, 2024
    "%Y-%m-%d",       # 2024-12-25 (ISO)
    "%d %b, %Y",      # 25 Dec, 2024
    "%d %B, %Y",      # 25 December, 2024
]


def parse_date(date_str: str) -> Optional[str]:
    """
    Parse a date string trying multiple Indian date formats.

    Args:
        date_str: Raw date string from the scraped page.

    Returns:
        ISO format date string (YYYY-MM-DD) or None if unparseable.
    """
    if not date_str:
        return None

    # Clean up the string
    cleaned = date_str.strip()
    cleaned = re.sub(r"\s+", " ", cleaned)  # normalize whitespace
    cleaned = re.sub(r"(st|nd|rd|th)\s", " ", cleaned)  # remove ordinals

    for fmt in DATE_FORMATS:
        try:
            parsed = datetime.strptime(cleaned, fmt)
            return parsed.strftime("%Y-%m-%d")
        except ValueError:
            continue

    # Try to extract date with regex as fallback
    # Pattern: DD-MM-YYYY or DD/MM/YYYY
    match = re.search(r"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})", cleaned)
    if match:
        day, month, year = match.groups()
        if len(year) == 2:
            year = f"20{year}"
        try:
            parsed = datetime(int(year), int(month), int(day))
            return parsed.strftime("%Y-%m-%d")
        except ValueError:
            pass

    logger.warning(f"Could not parse date: '{date_str}'")
    return None


# ---------------------------------------------------------------------------
# Vacancy Extraction
# ---------------------------------------------------------------------------

def extract_vacancies(text: str) -> int:
    """
    Extract number of vacancies from text.

    Looks for patterns like:
    - "1234 Posts"
    - "Vacancies: 500"
    - "No. of Posts: 100"

    Returns 0 if no number found.
    """
    if not text:
        return 0

    patterns = [
        r"(\d+)\s*(?:posts?|vacancies|vacancy)",
        r"(?:posts?|vacancies|vacancy)\s*[:\-]?\s*(\d+)",
        r"no\.?\s*of\s*(?:posts?|vacancies)\s*[:\-]?\s*(\d+)",
        r"(\d+)\s*(?:nos?\.?)",
    ]

    for pattern in patterns:
        match = re.search(pattern, text.lower())
        if match:
            num = int(match.group(1))
            # Sanity check: vacancies should be reasonable
            if 1 <= num <= 100000:
                return num

    return 0


# ---------------------------------------------------------------------------
# Scraper: TGPSC
# ---------------------------------------------------------------------------

def scrape_tgpsc() -> list[JobListing]:
    """
    Scrape job notifications from TGPSC (Telangana Government Public Service Commission).

    Targets: https://www.tgpsc.gov.in/notifications

    Returns:
        List of JobListing objects.
    """
    jobs: list[JobListing] = []
    logger.info("Scraping TGPSC notifications...")

    try:
        response = requests.get(
            TGPSC_NOTIFICATIONS_URL,
            headers=HEADERS,
            timeout=REQUEST_TIMEOUT,
        )
        response.raise_for_status()
    except requests.RequestException as e:
        logger.error(f"Failed to fetch TGPSC page: {e}")
        return jobs

    soup = BeautifulSoup(response.content, "lxml")

    # TGPSC uses a table-based notification listing
    # Look for notification rows in tables or divs
    notification_rows = soup.select(
        "table.table tbody tr, "
        "div.notification-list .notification-item, "
        "div.content-area table tr, "
        ".views-table tbody tr"
    )

    if not notification_rows:
        # Fallback: try to find any links with notification-like text
        notification_rows = soup.select("table tr")
        logger.info(f"TGPSC fallback: found {len(notification_rows)} table rows")

    for row in notification_rows:
        try:
            # Extract title from link or text content
            link = row.select_one("a")
            if not link:
                continue

            title = link.get_text(strip=True)
            if not title or len(title) < 10:
                continue

            # Skip non-job entries (general notices, circulars)
            skip_keywords = ["circular", "corrigendum", "amendment", "press note"]
            if any(kw in title.lower() for kw in skip_keywords):
                continue

            # Get source URL
            source_url = href if href.startswith("http") else f"{TGPSC_NEW_URL}{href}"

            # Extract cells for date and vacancy info
            cells = row.select("td")
            last_date_str = None
            vacancies = 0

            for cell in cells:
                cell_text = cell.get_text(strip=True)

                # Try to detect date cells
                if re.search(r"\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}", cell_text):
                    parsed = parse_date(cell_text)
                    if parsed:
                        last_date_str = parsed

                # Try to detect vacancy count
                vac = extract_vacancies(cell_text)
                if vac > 0:
                    vacancies = vac

            # If no vacancies from cells, try title
            if vacancies == 0:
                vacancies = extract_vacancies(title)

            # Detect category
            category = detect_category(title)

            # Determine organization
            organization = "TGPSC"

            job = JobListing(
                title=title,
                organization=organization,
                vacancies=vacancies if vacancies > 0 else 1,
                category=category,
                last_date=last_date_str,
                source="tgpsc",
                source_url=source_url,
            )
            jobs.append(job)

        except Exception as e:
            logger.warning(f"Error parsing TGPSC row: {e}")
            continue

    logger.info(f"TGPSC: scraped {len(jobs)} notifications")
    return jobs


# ---------------------------------------------------------------------------
# Scraper: Sakshi Education / Jobs
# ---------------------------------------------------------------------------

def scrape_sakshi_jobs() -> list[JobListing]:
    """
    Scrape job notifications from Sakshi Education jobs section.

    Targets: https://www.sakshieducation.com/jobs/notifications

    Returns:
        List of JobListing objects.
    """
    jobs: list[JobListing] = []
    logger.info("Scraping Sakshi Education jobs...")

    try:
        response = requests.get(
            SAKSHI_JOBS_URL,
            headers=HEADERS,
            timeout=REQUEST_TIMEOUT,
        )
        response.raise_for_status()
    except requests.RequestException as e:
        logger.error(f"Failed to fetch Sakshi page: {e}")
        return jobs

    soup = BeautifulSoup(response.content, "lxml")

    # Sakshi uses article cards / list items for job notifications
    articles = soup.select(
        "article.node, "
        "div.view-content .views-row, "
        "div.job-listing .job-item, "
        ".news-list li, "
        ".article-list .article-item"
    )

    if not articles:
        # Broader fallback
        articles = soup.select("div.view-content div, .content-area article")
        logger.info(f"Sakshi fallback: found {len(articles)} items")

    for article in articles:
        try:
            # Get title link
            title_el = article.select_one("h2 a, h3 a, .title a, a.headline")
            if not title_el:
                title_el = article.select_one("a")
            if not title_el:
                continue

            title = title_el.get_text(strip=True)
            if not title or len(title) < 10:
                continue

            # Filter for Telangana-specific jobs
            telangana_keywords = [
                "telangana", "tgpsc", "tspsc", "ts", "hyderabad", "tslprb",
                "tsgenco", "tstransco", "tsrtc", "hmda", "ghmc",
                "kaleshwaram", "singareni",
            ]
            title_lower = title.lower()

            # We keep all jobs but flag Telangana ones
            is_telangana = any(kw in title_lower for kw in telangana_keywords)

            # Get URL
            href = title_el.get("href", "")
            source_url = href if href.startswith("http") else f"{SAKSHI_BASE_URL}{href}"

            # Get date
            date_el = article.select_one(
                ".date, .post-date, time, .submitted, .field-name-post-date"
            )
            last_date_str = None
            if date_el:
                date_text = date_el.get_text(strip=True)
                last_date_str = parse_date(date_text)

            # Try to get last date from content text
            if not last_date_str:
                content_text = article.get_text()
                last_date_match = re.search(
                    r"(?:last\s*date|closing\s*date)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})",
                    content_text,
                    re.IGNORECASE,
                )
                if last_date_match:
                    last_date_str = parse_date(last_date_match.group(1))

            # Extract vacancies
            content_text = article.get_text()
            vacancies = extract_vacancies(content_text)

            # Detect category
            category = detect_category(title)

            # Try to determine organization from title
            org_patterns = {
                "TGPSC": r"\btgpsc\b|\btspsc\b",
                "TSLPRB (TS Police Recruitment Board)": r"\btslprb\b|\bts\s*police\b",
                "TSGENCO": r"\btsgenco\b",
                "TSTRANSCO": r"\btstransco\b",
                "TSRTC": r"\btsrtc\b",
                "GHMC": r"\bghmc\b",
                "HMDA": r"\bhmda\b",
                "Singareni Collieries": r"\bsingareni\b|\bsccl\b",
                "TS Health Department": r"\bts\s*health\b|\bdmho\b",
            }

            organization = "Government of Telangana"
            for org_name, pattern in org_patterns.items():
                if re.search(pattern, title_lower):
                    organization = org_name
                    break

            job = JobListing(
                title=title,
                organization=organization,
                vacancies=vacancies if vacancies > 0 else 1,
                category=category,
                last_date=last_date_str,
                source="sakshi",
                source_url=source_url,
            )
            jobs.append(job)

        except Exception as e:
            logger.warning(f"Error parsing Sakshi article: {e}")
            continue

    logger.info(f"Sakshi: scraped {len(jobs)} notifications")
    return jobs


# ---------------------------------------------------------------------------
# Database Operations
# ---------------------------------------------------------------------------

def get_supabase_client() -> Client:
    """Create and return Supabase client."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise EnvironmentError(
            "SUPABASE_URL and SUPABASE_KEY environment variables are required."
        )
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def job_exists(client: Client, title: str, source: str) -> bool:
    """
    Check if a job with the same title and source already exists.

    Uses case-insensitive comparison on title for deduplication.

    Args:
        client: Supabase client instance.
        title: Job title to check.
        source: Source identifier (e.g., 'tgpsc', 'sakshi').

    Returns:
        True if job already exists, False otherwise.
    """
    try:
        result = (
            client.table("jobs")
            .select("id")
            .ilike("title", title.strip())
            .eq("source", source)
            .limit(1)
            .execute()
        )
        return len(result.data) > 0
    except Exception as e:
        logger.warning(f"Dedup check failed for '{title[:50]}': {e}")
        # If dedup check fails, assume it doesn't exist to avoid data loss
        return False


def insert_jobs(client: Client, jobs: list[JobListing]) -> tuple[int, int]:
    """
    Insert new jobs into Supabase, skipping duplicates.

    Args:
        client: Supabase client instance.
        jobs: List of JobListing objects to insert.

    Returns:
        Tuple of (inserted_count, skipped_count).
    """
    inserted = 0
    skipped = 0

    for job in jobs:
        try:
            # Check for duplicate
            if job_exists(client, job.title, job.source):
                skipped += 1
                logger.debug(f"Skipped (duplicate): {job.title[:60]}")
                continue

            # Prepare data for insertion
            data = job.to_dict()

            # Add metadata
            data["created_at"] = datetime.utcnow().isoformat()
            data["updated_at"] = datetime.utcnow().isoformat()
            data["is_active"] = True

            # Determine if the job is expired
            if data.get("last_date"):
                try:
                    last_dt = datetime.strptime(data["last_date"], "%Y-%m-%d").date()
                    if last_dt < date.today():
                        data["is_active"] = False
                except ValueError:
                    pass

            # Insert into Supabase
            result = client.table("jobs").insert(data).execute()

            if result.data:
                inserted += 1
                logger.info(f"Inserted: {job.title[:60]}")
            else:
                logger.warning(f"Insert returned no data: {job.title[:60]}")

        except Exception as e:
            logger.error(f"Failed to insert '{job.title[:50]}': {e}")
            continue

    return inserted, skipped


# ---------------------------------------------------------------------------
# Mark Expired Jobs
# ---------------------------------------------------------------------------

def mark_expired_jobs(client: Client) -> int:
    """
    Mark jobs as inactive where the last_date has passed.

    Returns:
        Number of jobs marked as expired.
    """
    today_str = date.today().isoformat()

    try:
        result = (
            client.table("jobs")
            .update({"is_active": False, "updated_at": datetime.utcnow().isoformat()})
            .lt("last_date", today_str)
            .eq("is_active", True)
            .execute()
        )
        count = len(result.data) if result.data else 0
        logger.info(f"Marked {count} expired jobs as inactive")
        return count
    except Exception as e:
        logger.error(f"Failed to mark expired jobs: {e}")
        return 0


# ---------------------------------------------------------------------------
# Main Orchestrator
# ---------------------------------------------------------------------------

def main():
    """
    Main function orchestrating the scraping pipeline.

    1. Scrapes TGPSC notifications
    2. Scrapes Sakshi Education jobs
    3. Deduplicates and inserts new jobs
    4. Marks expired jobs as inactive
    5. Logs summary statistics
    """
    logger.info("=" * 60)
    logger.info("Telangana Jobs Scraper - Starting run")
    logger.info(f"Timestamp: {datetime.utcnow().isoformat()}Z")
    logger.info("=" * 60)

    # Scrape from all sources
    all_jobs: list[JobListing] = []

    # Source 1: TGPSC
    tgpsc_jobs = scrape_tgpsc()
    all_jobs.extend(tgpsc_jobs)

    # Source 2: Sakshi Education
    sakshi_jobs = scrape_sakshi_jobs()
    all_jobs.extend(sakshi_jobs)

    logger.info(f"Total scraped: {len(all_jobs)} jobs "
                f"(TGPSC: {len(tgpsc_jobs)}, Sakshi: {len(sakshi_jobs)})")

    if not all_jobs:
        logger.warning("No jobs scraped from any source. Exiting.")
        return

    # Connect to Supabase
    try:
        client = get_supabase_client()
        logger.info("Connected to Supabase")
    except EnvironmentError as e:
        logger.error(f"Supabase connection failed: {e}")
        # In development, just print the scraped data
        logger.info("\n--- SCRAPED DATA (no DB connection) ---")
        for job in all_jobs[:10]:
            logger.info(f"  [{job.category.upper():12s}] {job.title[:60]}")
            logger.info(f"    Org: {job.organization} | Vacancies: {job.vacancies}")
            logger.info(f"    Last Date: {job.last_date} | Source: {job.source}")
            logger.info("")
        return

    # Insert jobs (with deduplication)
    inserted, skipped = insert_jobs(client, all_jobs)

    # Mark expired jobs
    expired = mark_expired_jobs(client)

    # Summary
    logger.info("=" * 60)
    logger.info("SUMMARY")
    logger.info(f"  Scraped:  {len(all_jobs)} jobs")
    logger.info(f"  Inserted: {inserted} new jobs")
    logger.info(f"  Skipped:  {skipped} duplicates")
    logger.info(f"  Expired:  {expired} marked inactive")
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
