-- ============================================================
-- MCU Analysis Project: Schema
-- Run this once, inside the mcu_analysis database.
-- ============================================================

-- Core film list with phase metadata (from mcu_films_seed.csv)
CREATE TABLE films (
    title           TEXT PRIMARY KEY,
    release_date    DATE,
    phase           TEXT,
    tmdb_id         INTEGER
);

-- Enrichment from TMDB (from films_tmdb.csv)
CREATE TABLE film_details (
    title               TEXT PRIMARY KEY REFERENCES films(title),
    phase               TEXT,
    tmdb_id             INTEGER,
    release_date        DATE,
    runtime_minutes     INTEGER,
    vote_average_tmdb   NUMERIC(4,2),
    vote_count_tmdb     INTEGER,
    popularity_tmdb     NUMERIC(10,3),
    budget_tmdb         BIGINT,
    revenue_tmdb        BIGINT,
    genres              TEXT,     -- pipe-delimited, e.g. 'Action|Adventure'
    director            TEXT,
    imdb_id             TEXT
);

-- Cast list, one row per (film, cast member) (from cast_tmdb.csv)
CREATE TABLE film_cast (
    film_title      TEXT REFERENCES films(title),
    tmdb_id         INTEGER,
    person_name     TEXT,
    character_name  TEXT,
    billing_order   INTEGER
);

-- Ratings from OMDb (from ratings_omdb.csv)
CREATE TABLE ratings (
    title                   TEXT PRIMARY KEY REFERENCES films(title),
    imdb_id                 TEXT,
    imdb_rating             NUMERIC(3,1),
    imdb_votes              TEXT,     -- stored with commas in source; cast later when needed
    rotten_tomatoes_score   TEXT,     -- stored as '94%' style string; cast later when needed
    metascore               TEXT,
    rated                   TEXT,
    box_office_omdb         TEXT      -- rough cross-check only, not source of truth
);

-- Box office financials (from boxoffice_template.csv)
CREATE TABLE financials (
    title                           TEXT PRIMARY KEY REFERENCES films(title),
    budget_usd                      BIGINT,
    opening_weekend_domestic_usd    BIGINT,
    domestic_gross_usd              BIGINT,
    worldwide_gross_usd             BIGINT,
    budget_source                   TEXT,
    gross_source                    TEXT,
    notes                           TEXT
);
