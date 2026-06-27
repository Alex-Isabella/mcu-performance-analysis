-- ============================================================
-- MCU Analysis Project: Tableau Export Views
-- ============================================================
-- Tableau works best with flat, pre-joined tables rather than
-- forcing it to replicate SQL joins/window functions in its own
-- engine. These views do the heavy lifting in Postgres once;
-- Tableau just reads the result.
--
-- After running this script, connect Tableau directly to Postgres
-- (Tableau has a native PostgreSQL connector) and use these views
-- as your data sources, OR export each view to CSV via DBeaver
-- (right-click view -> Export Data -> CSV) if you'd rather not
-- set up a live DB connection in Tableau.


-- ----------------------------------------------------------------
-- VIEW 1: Master film-level table (one row per film, everything joined)
-- ----------------------------------------------------------------
-- This is your main dashboard data source -- almost every chart
-- (scores over time, ROI over time, budget vs gross scatter, etc.)
-- can be built from this one view.

CREATE OR REPLACE VIEW v_film_master AS
SELECT
    f.title,
    f.release_date,
    f.phase,
    fd.runtime_minutes,
    fd.director,
    fd.genres,
    fd.popularity_tmdb,
    r.imdb_rating,
    r.imdb_votes_clean,
    r.rotten_tomatoes_clean,
    r.metascore_clean,
    r.rotten_tomatoes_clean - (r.imdb_rating * 10) AS critic_audience_gap,
    fin.budget_usd,
    fin.opening_weekend_domestic_usd,
    fin.domestic_gross_usd,
    fin.worldwide_gross_usd,
    ROUND(fin.worldwide_gross_usd::NUMERIC / fin.budget_usd, 2) AS roi_multiple,
    CASE
        WHEN f.phase IN ('Phase One', 'Phase Two', 'Phase Three') THEN 'Phase 1-3 (2008-2019)'
        WHEN f.phase IN ('Phase Four', 'Phase Five') THEN 'Phase 4-5 (2021-2025)'
    END AS era
FROM films f
JOIN film_details fd ON f.title = fd.title
JOIN ratings r        ON f.title = r.title
JOIN financials fin   ON f.title = fin.title;


-- ----------------------------------------------------------------
-- VIEW 2: Phase-level summary (pre-aggregated, matches Query 1/2/4 from earlier)
-- ----------------------------------------------------------------
-- Useful for a clean bar/line chart of "metric by phase" without
-- Tableau needing to do the aggregation itself.

CREATE OR REPLACE VIEW v_phase_summary AS
SELECT
    phase,
    MIN(release_date) AS phase_start_date,
    COUNT(*) AS film_count,
    ROUND(AVG(rotten_tomatoes_clean), 1)   AS avg_critic_score,
    ROUND(AVG(imdb_rating) * 10, 1)        AS avg_audience_score_scaled,
    ROUND(AVG(critic_audience_gap), 1)     AS avg_critic_audience_gap,
    ROUND(AVG(budget_usd))                 AS avg_budget,
    ROUND(AVG(worldwide_gross_usd))        AS avg_worldwide_gross,
    ROUND(AVG(roi_multiple), 2)            AS avg_roi_multiple,
    ROUND(AVG(runtime_minutes))            AS avg_runtime_minutes
FROM v_film_master
GROUP BY phase;


-- ----------------------------------------------------------------
-- VIEW 3: Actor appearance gaps + the film's reception (combines
-- the LAG() window function with score data, as discussed)
-- ----------------------------------------------------------------
-- One row per (actor, film) for top-3-billed actors only. Useful
-- for a scatter plot: days_since_last_appearance (x) vs the film's
-- critic/audience score (y), to visually test the "long gap = worse
-- reception" theory.

CREATE OR REPLACE VIEW v_actor_gap_vs_reception AS
SELECT
    fc.person_name,
    f.title,
    f.release_date,
    f.phase,
    fc.billing_order,
    LAG(f.release_date) OVER (
        PARTITION BY fc.person_name ORDER BY f.release_date
    ) AS previous_mcu_release,
    f.release_date - LAG(f.release_date) OVER (
        PARTITION BY fc.person_name ORDER BY f.release_date
    ) AS days_since_last_appearance,
    r.rotten_tomatoes_clean,
    r.imdb_rating
FROM film_cast fc
JOIN films f   ON fc.film_title = f.title
JOIN ratings r ON f.title = r.title
WHERE fc.billing_order <= 2;


-- Quick checks -- run these after creating the views to confirm they work
SELECT * FROM v_film_master ORDER BY release_date LIMIT 5;
SELECT * FROM v_phase_summary ORDER BY phase_start_date;
SELECT * FROM v_actor_gap_vs_reception WHERE days_since_last_appearance IS NOT NULL ORDER BY days_since_last_appearance DESC LIMIT 10;
