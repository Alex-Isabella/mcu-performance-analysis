-- ============================================================
-- MCU Analysis Project: Correlation Analysis
-- ============================================================
-- Postgres has a built-in CORR() function (Pearson correlation
-- coefficient), so no need for an external stats library.
-- Pearson's r ranges from -1 to 1:
--   close to  1  = strong positive relationship
--   close to  0  = no linear relationship
--   close to -1  = strong negative relationship
-- As a rough rule of thumb for this kind of social/cultural data:
--   |r| > 0.7  -> strong
--   |r| 0.4-0.7 -> moderate
--   |r| < 0.4  -> weak
-- r^2 (just r squared) is also useful to report: it tells you
-- roughly what % of the variance in Y is "explained" by X.


-- ----------------------------------------------------------------
-- 1. Does critic score correlate with ROI?
-- ----------------------------------------------------------------
SELECT
    ROUND(CORR(rotten_tomatoes_clean, roi_multiple)::NUMERIC, 3) AS corr_critic_score_roi,
    ROUND(POWER(CORR(rotten_tomatoes_clean, roi_multiple), 2)::NUMERIC, 3) AS r_squared
FROM v_film_master;


-- ----------------------------------------------------------------
-- 2. Does audience score (IMDb) correlate with ROI?
-- ----------------------------------------------------------------
SELECT
    ROUND(CORR(imdb_rating, roi_multiple)::NUMERIC, 3) AS corr_audience_score_roi,
    ROUND(POWER(CORR(imdb_rating, roi_multiple), 2)::NUMERIC, 3) AS r_squared
FROM v_film_master;


-- ----------------------------------------------------------------
-- 3. Does budget size correlate with reception? (a common confound --
--    do bigger-budget films just get rated better, regardless of phase?)
-- ----------------------------------------------------------------
SELECT
    ROUND(CORR(budget_usd, rotten_tomatoes_clean)::NUMERIC, 3) AS corr_budget_critic_score,
    ROUND(CORR(budget_usd, imdb_rating)::NUMERIC, 3) AS corr_budget_audience_score
FROM v_film_master;


-- ----------------------------------------------------------------
-- 4. All key correlations in one summary table (for the dashboard / writeup)
-- ----------------------------------------------------------------
SELECT
    'Critic Score vs ROI' AS relationship,
    ROUND(CORR(rotten_tomatoes_clean, roi_multiple)::NUMERIC, 3) AS pearson_r
FROM v_film_master
UNION ALL
SELECT
    'Audience Score vs ROI',
    ROUND(CORR(imdb_rating, roi_multiple)::NUMERIC, 3)
FROM v_film_master
UNION ALL
SELECT
    'Budget vs Critic Score',
    ROUND(CORR(budget_usd, rotten_tomatoes_clean)::NUMERIC, 3)
FROM v_film_master
UNION ALL
SELECT
    'Budget vs ROI',
    ROUND(CORR(budget_usd, roi_multiple)::NUMERIC, 3)
FROM v_film_master
UNION ALL
SELECT
    'Critic Score vs Audience Score',
    ROUND(CORR(rotten_tomatoes_clean, imdb_rating)::NUMERIC, 3)
FROM v_film_master;
