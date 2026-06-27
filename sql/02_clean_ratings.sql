-- ============================================================
-- MCU Analysis Project: Clean numeric versions of text-formatted columns
-- ============================================================

-- Add new numeric columns to hold cleaned values
ALTER TABLE ratings ADD COLUMN imdb_votes_clean INTEGER;
ALTER TABLE ratings ADD COLUMN rotten_tomatoes_clean INTEGER;
ALTER TABLE ratings ADD COLUMN metascore_clean INTEGER;

-- imdb_votes: strip commas, e.g. '1,223,183' -> 1223183
UPDATE ratings
SET imdb_votes_clean = REPLACE(imdb_votes, ',', '')::INTEGER;

-- rotten_tomatoes_score: strip '%', e.g. '94%' -> 94
UPDATE ratings
SET rotten_tomatoes_clean = REPLACE(rotten_tomatoes_score, '%', '')::INTEGER;

-- metascore: strip '/100', e.g. '79/100' -> 79
UPDATE ratings
SET metascore_clean = SPLIT_PART(metascore, '/', 1)::INTEGER;

-- Quick sanity check: confirm all 36 rows converted with no NULLs introduced
SELECT
    COUNT(*) AS total_rows,
    COUNT(imdb_votes_clean) AS imdb_votes_filled,
    COUNT(rotten_tomatoes_clean) AS rt_filled,
    COUNT(metascore_clean) AS metascore_filled
FROM ratings;
