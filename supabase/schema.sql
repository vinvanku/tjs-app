-- ============================================================================
-- Telangana Jobs App - Supabase Database Schema
-- ============================================================================
-- Run this in the Supabase SQL Editor to set up the complete database.
-- Includes: tables, indexes, RLS policies, and helper functions.
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For fuzzy text search


-- ============================================================================
-- TABLE: jobs
-- Stores all scraped job notifications from various sources.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.jobs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT NOT NULL,
    organization    TEXT NOT NULL,
    vacancies       INTEGER NOT NULL DEFAULT 1 CHECK (vacancies >= 0),
    category        TEXT NOT NULL DEFAULT 'general'
                        CHECK (category IN (
                            'police', 'teaching', 'health',
                            'engineering', 'revenue', 'general'
                        )),
    last_date       DATE,
    source          TEXT NOT NULL CHECK (source IN ('tspsc', 'sakshi', 'manual')),
    source_url      TEXT,
    qualification   TEXT,
    district        TEXT,
    is_free         BOOLEAN NOT NULL DEFAULT FALSE,
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_jobs_category ON public.jobs (category);
CREATE INDEX IF NOT EXISTS idx_jobs_source ON public.jobs (source);
CREATE INDEX IF NOT EXISTS idx_jobs_last_date ON public.jobs (last_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_jobs_is_active ON public.jobs (is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON public.jobs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_district ON public.jobs (district) WHERE district IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_qualification ON public.jobs (qualification) WHERE qualification IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_is_free ON public.jobs (is_free) WHERE is_free = TRUE;

-- Composite index for the main listing query (active jobs sorted by deadline)
CREATE INDEX IF NOT EXISTS idx_jobs_active_deadline
    ON public.jobs (is_active, last_date DESC NULLS LAST)
    WHERE is_active = TRUE;

-- Full-text search index on title
CREATE INDEX IF NOT EXISTS idx_jobs_title_trgm
    ON public.jobs USING GIN (title gin_trgm_ops);

-- Unique constraint for deduplication (same title + source = duplicate)
CREATE UNIQUE INDEX IF NOT EXISTS idx_jobs_dedup
    ON public.jobs (lower(title), source);

-- Comment on table
COMMENT ON TABLE public.jobs IS 'Scraped government job notifications for Telangana state';


-- ============================================================================
-- TABLE: profiles
-- User profiles linked to Supabase Auth (auth.users).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name       TEXT,
    avatar_url      TEXT,
    phone           TEXT,
    district        TEXT,
    qualification   TEXT,
    preferred_categories TEXT[] DEFAULT '{}',
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    fcm_token       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_profiles_district ON public.profiles (district) WHERE district IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_fcm ON public.profiles (fcm_token) WHERE fcm_token IS NOT NULL;

COMMENT ON TABLE public.profiles IS 'User profile data extending Supabase Auth';


-- ============================================================================
-- TABLE: saved_jobs
-- Many-to-many relation: users can save/bookmark jobs.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.saved_jobs (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    job_id      UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
    saved_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes       TEXT,

    -- Each user can save a job only once
    CONSTRAINT unique_user_job UNIQUE (user_id, job_id)
);

-- Indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_saved_jobs_user ON public.saved_jobs (user_id);
CREATE INDEX IF NOT EXISTS idx_saved_jobs_job ON public.saved_jobs (job_id);
CREATE INDEX IF NOT EXISTS idx_saved_jobs_saved_at ON public.saved_jobs (saved_at DESC);

COMMENT ON TABLE public.saved_jobs IS 'User bookmarked/saved job notifications';


-- ============================================================================
-- AUTO-UPDATE updated_at TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to jobs table
DROP TRIGGER IF EXISTS on_jobs_updated ON public.jobs;
CREATE TRIGGER on_jobs_updated
    BEFORE UPDATE ON public.jobs
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Apply trigger to profiles table
DROP TRIGGER IF EXISTS on_profiles_updated ON public.profiles;
CREATE TRIGGER on_profiles_updated
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();


-- ============================================================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.raw_user_meta_data ->> 'name', ''),
        COALESCE(NEW.raw_user_meta_data ->> 'avatar_url', '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users insert
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();


-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_jobs ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- JOBS: Public read, service-role write
-- ---------------------------------------------------------------------------

-- Anyone (including anonymous) can read active jobs
CREATE POLICY "Jobs are viewable by everyone"
    ON public.jobs
    FOR SELECT
    USING (TRUE);

-- Only service role (scraper) can insert/update/delete
CREATE POLICY "Service role can insert jobs"
    ON public.jobs
    FOR INSERT
    TO service_role
    WITH CHECK (TRUE);

CREATE POLICY "Service role can update jobs"
    ON public.jobs
    FOR UPDATE
    TO service_role
    USING (TRUE)
    WITH CHECK (TRUE);

CREATE POLICY "Service role can delete jobs"
    ON public.jobs
    FOR DELETE
    TO service_role
    USING (TRUE);

-- ---------------------------------------------------------------------------
-- PROFILES: Users can read/update their own profile
-- ---------------------------------------------------------------------------

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Service role has full access (for admin operations)
CREATE POLICY "Service role full access on profiles"
    ON public.profiles
    FOR ALL
    TO service_role
    USING (TRUE)
    WITH CHECK (TRUE);

-- ---------------------------------------------------------------------------
-- SAVED_JOBS: Users can manage their own saved jobs
-- ---------------------------------------------------------------------------

-- Users can view their own saved jobs
CREATE POLICY "Users can view own saved jobs"
    ON public.saved_jobs
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Users can save jobs (insert)
CREATE POLICY "Users can save jobs"
    ON public.saved_jobs
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Users can unsave jobs (delete)
CREATE POLICY "Users can unsave jobs"
    ON public.saved_jobs
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- Users can update their saved job notes
CREATE POLICY "Users can update own saved jobs"
    ON public.saved_jobs
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


-- ============================================================================
-- HELPER VIEWS
-- ============================================================================

-- View: Active jobs with days remaining (for app queries)
CREATE OR REPLACE VIEW public.active_jobs_view AS
SELECT
    j.*,
    CASE
        WHEN j.last_date IS NULL THEN NULL
        WHEN j.last_date < CURRENT_DATE THEN -1
        ELSE (j.last_date - CURRENT_DATE)
    END AS days_remaining
FROM public.jobs j
WHERE j.is_active = TRUE
ORDER BY j.last_date ASC NULLS LAST;

COMMENT ON VIEW public.active_jobs_view IS 'Active jobs with computed days_remaining field';


-- View: Job stats by category (for dashboard)
CREATE OR REPLACE VIEW public.jobs_stats_view AS
SELECT
    category,
    COUNT(*) AS total_jobs,
    COUNT(*) FILTER (WHERE is_active = TRUE) AS active_jobs,
    COUNT(*) FILTER (WHERE last_date >= CURRENT_DATE AND last_date <= CURRENT_DATE + INTERVAL '7 days') AS expiring_soon,
    SUM(vacancies) AS total_vacancies,
    MAX(created_at) AS latest_scraped
FROM public.jobs
GROUP BY category
ORDER BY active_jobs DESC;

COMMENT ON VIEW public.jobs_stats_view IS 'Aggregated job statistics by category';


-- ============================================================================
-- SEED DATA (optional - remove in production)
-- ============================================================================

-- Uncomment below to insert sample data for testing:
/*
INSERT INTO public.jobs (title, organization, vacancies, category, last_date, source, source_url, is_free)
VALUES
    ('Sub Inspector of Police - Civil/AR/TSSP/SPF', 'TSLPRB (TS Police Recruitment Board)', 554, 'police', CURRENT_DATE + INTERVAL '15 days', 'tspsc', 'https://www.tspsc.gov.in/example1', FALSE),
    ('School Assistant (SA) - Mathematics', 'TSPSC (Telangana State Public Service Commission)', 1200, 'teaching', CURRENT_DATE + INTERVAL '5 days', 'tspsc', 'https://www.tspsc.gov.in/example2', FALSE),
    ('Staff Nurse Grade-II in DPH & FW', 'TS Health Department', 800, 'health', CURRENT_DATE + INTERVAL '2 days', 'sakshi', 'https://www.sakshieducation.com/example3', TRUE),
    ('Assistant Engineer (Civil) in R&B Department', 'TSPSC (Telangana State Public Service Commission)', 130, 'engineering', CURRENT_DATE + INTERVAL '20 days', 'tspsc', 'https://www.tspsc.gov.in/example4', FALSE),
    ('Village Revenue Officer (VRO)', 'Government of Telangana', 700, 'revenue', CURRENT_DATE + INTERVAL '10 days', 'sakshi', 'https://www.sakshieducation.com/example5', FALSE),
    ('Junior Assistant / Typist in Various Departments', 'TSPSC (Telangana State Public Service Commission)', 1500, 'general', CURRENT_DATE - INTERVAL '2 days', 'tspsc', 'https://www.tspsc.gov.in/example6', FALSE);
*/
