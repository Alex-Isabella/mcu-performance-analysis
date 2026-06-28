"""
Step 3: Pull ratings data from OMDb (IMDb rating, Rotten Tomatoes, Metascore).

Depends on data/films_tmdb.csv already existing (run enrich_tmdb.py first) --
Use the imdb_id column from that file to look up each film on OMDb, since
matching by IMDb ID is far more reliable than matching by title string.

Produces:
    data/ratings_omdb.csv   -- one row per film with ratings from multiple sources

Usage:
    python enrich_omdb.py YOUR_OMDB_API_KEY
"""
import csv
import sys
import time
import requests

FILMS_IN = "films_tmdb.csv"
OUT_PATH = "ratings_omdb.csv"
BASE_URL = "https://www.omdbapi.com/"


def get_omdb_data(api_key: str, imdb_id: str):
    params = {"apikey": api_key, "i": imdb_id}
    resp = requests.get(BASE_URL, params=params, timeout=10)
    resp.raise_for_status()
    return resp.json()


def parse_ratings(omdb_json: dict):
    """
    OMDb returns a 'Ratings' list with inconsistent presence of sources --
    not every film has a Rotten Tomatoes entry, for instance. Pull out
    what's there rather than assuming a fixed structure.
    """
    out = {"imdb_rating": omdb_json.get("imdbRating"), "imdb_votes": omdb_json.get("imdbVotes")}
    for r in omdb_json.get("Ratings", []):
        source = r.get("Source", "")
        if source == "Rotten Tomatoes":
            out["rotten_tomatoes_score"] = r.get("Value")
        elif source == "Metacritic":
            out["metascore"] = r.get("Value")
    return out


def main():
    if len(sys.argv) != 2:
        print("Usage: python enrich_omdb.py YOUR_OMDB_API_KEY")
        sys.exit(1)
    api_key = sys.argv[1]

    with open(FILMS_IN, newline="", encoding="utf-8") as f:
        films = list(csv.DictReader(f))

    out_records = []

    for film in films:
        title = film["title"]
        imdb_id = film.get("imdb_id")

        if not imdb_id:
            print(f"SKIP (no imdb_id from TMDB pull): {title}")
            continue

        print(f"Fetching OMDb data: {title} ({imdb_id})")
        try:
            data = get_omdb_data(api_key, imdb_id)
        except requests.HTTPError as e:
            print(f"  ERROR fetching {title}: {e}")
            continue

        if data.get("Response") == "False":
            print(f"  OMDb returned no result for {title}: {data.get('Error')}")
            continue

        ratings = parse_ratings(data)
        out_records.append({
            "title": title,
            "imdb_id": imdb_id,
            "imdb_rating": ratings.get("imdb_rating"),
            "imdb_votes": ratings.get("imdb_votes"),
            "rotten_tomatoes_score": ratings.get("rotten_tomatoes_score"),
            "metascore": ratings.get("metascore"),
            "rated": data.get("Rated"),
            "box_office_omdb": data.get("BoxOffice"),  # cross-check vs Box Office Mojo, often US-only/incomplete
        })

        time.sleep(0.1)  # well under 1000/day limit, no rush needed

    with open(OUT_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=out_records[0].keys())
        writer.writeheader()
        writer.writerows(out_records)

    print(f"\nWrote {len(out_records)} rows to {OUT_PATH}")
    print("Note: not every film has a Rotten Tomatoes entry from OMDb's source list --")
    print("check for blanks and decide whether to backfill manually from rottentomatoes.com")
    print("for any film missing that score, since it's central to your fatigue analysis.")


if __name__ == "__main__":
    main()
