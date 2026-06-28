-- ============================================================
-- MCU Analysis Project: Core Analysis Queries
-- ============================================================


-- ----------------------------------------------------------------
-- QUERY 1: Critic-vs-audience score gap by phase
-- ----------------------------------------------------------------
-- imdb_rating is on a 0-10 scale; rotten_tomatoes_clean is 0-100.
-- I put imdb_rating on the same 0-100 scale (x10) so the "gap" is a meaningful number.
-- A widening gap (critics liked it more than audiences) is the classic fatigue/backlash signal.

SELECT
    f.phase,
    COUNT(*) AS film_count,
    ROUND(AVG(r.rotten_tomatoes_clean), 1)      AS avg_critic_score,
    ROUND(AVG(r.imdb_rating) * 10, 1)           AS avg_audience_score_scaled,
    ROUND(AVG(r.rotten_tomatoes_clean) - AVG(r.imdb_rating) * 10, 1) AS avg_critic_audience_gap
FROM films f
JOIN ratings r ON f.title = r.title
GROUP BY f.phase
ORDER BY MIN(f.release_date);


-- ----------------------------------------------------------------
-- QUERY 2: Box office performance by phase, adjusted for budget (ROI)
-- ----------------------------------------------------------------
-- ROI here = worldwide gross / budget. A common industry rule of
-- thumb is a film needs to gross ~2-2.5x its budget to break even
-- once marketing/distribution costs are factored in (those costs
-- aren't in this dataset, so treat this as a relative comparison
-- across phases, not a literal profit calculation).

SELECT
    f.phase,
    COUNT(*) AS film_count,
    ROUND(AVG(fin.budget_usd)) AS avg_budget,
    ROUND(AVG(fin.worldwide_gross_usd)) AS avg_worldwide_gross,
    ROUND(AVG(fin.worldwide_gross_usd::NUMERIC / fin.budget_usd), 2) AS avg_roi_multiple
FROM films f
JOIN financials fin ON f.title = fin.title
GROUP BY f.phase
ORDER BY MIN(f.release_date);


-- ----------------------------------------------------------------
-- QUERY 3: Time since top billed actor's last MCU appearance (lead-fatigue signal)
-- ----------------------------------------------------------------
-- For each lead/top-billed actor,
-- this calculates the gap in days since that same actor's top billed previous MCU
-- film, using LAG() partitioned by person and ordered by release date.
-- A long gap before a film with declining reception could support a
-- "the audience needed a reintroduction" reading; a short gap (frequent
-- appearances) supports a "we're tired of seeing this character" reading.

SELECT
    fc.person_name,
    f.title,
    f.release_date,
    fc.billing_order,
    LAG(f.release_date) OVER (
        PARTITION BY fc.person_name ORDER BY f.release_date
    ) AS previous_mcu_release,
    f.release_date - LAG(f.release_date) OVER (
        PARTITION BY fc.person_name ORDER BY f.release_date
    ) AS days_since_last_appearance
FROM film_cast fc
JOIN films f ON fc.film_title = f.title
WHERE fc.billing_order <= 2   -- top 3 billed only; extending this would mostly add noise
ORDER BY fc.person_name, f.release_date;


-- ----------------------------------------------------------------
-- QUERY 4: Headline comparison — Phase 1-3 vs Phase 4-5 cohorts
-- ----------------------------------------------------------------
-- This is the single summary table for the write-up: two eras,
-- side by side, across rating, ROI, and runtime. Phase Six excluded
-- since it currently has 0 films in our dataset.

SELECT
    CASE
        WHEN f.phase IN ('Phase One', 'Phase Two', 'Phase Three') THEN 'Phase 1-3 (2008-2019)'
        WHEN f.phase IN ('Phase Four', 'Phase Five') THEN 'Phase 4-5 (2021-2025)'
    END AS era,
    COUNT(*) AS film_count,
    ROUND(AVG(r.rotten_tomatoes_clean), 1)                        AS avg_critic_score,
    ROUND(AVG(r.imdb_rating), 2)                                  AS avg_audience_score_10pt,
    ROUND(AVG(fin.worldwide_gross_usd::NUMERIC / fin.budget_usd), 2) AS avg_roi_multiple,
    ROUND(AVG(fd.runtime_minutes))                                AS avg_runtime_minutes
FROM films f
JOIN ratings r       ON f.title = r.title
JOIN financials fin  ON f.title = fin.title
JOIN film_details fd ON f.title = fd.title
WHERE f.phase IN ('Phase One', 'Phase Two', 'Phase Three', 'Phase Four', 'Phase Five')
GROUP BY era
ORDER BY era;
