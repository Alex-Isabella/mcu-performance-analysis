"""
Step 2: Pull detailed film + cast/crew data from TMDB.

Run this only after verify_tmdb_ids.py shows all rows as OK

Produces two files:
    data/films_tmdb.csv      -- one row per film (runtime, popularity, vote avg, etc.)
    data/cast_tmdb.csv       -- one row per (film, cast member), for fatigue/
                                 recognizability analysis later

Usage:
    python enrich_tmdb.py YOUR_TMDB_API_KEY
"""
import csv
import sys
import time
import requests

SEED_PATH = "mcu_films_seed.csv"
FILMS_OUT = "films_tmdb.csv"
CAST_OUT = "cast_tmdb.csv"
BASE_URL = "https://api.themoviedb.org/3/movie"

# How many top-billed cast members to keep per film. Past this, you're mostly
# capturing extras, which adds noise without adding analytical value.
MAX_CAST_PER_FILM = 10


def get_movie_details(api_key: str, tmdb_id: str):
    """Fetch core movie details plus appended credits in one call."""
    url = f"{BASE_URL}/{tmdb_id}"
    params = {"api_key": api_key, "append_to_response": "credits"}
    resp = requests.get(url, params=params, timeout=10)
    resp.raise_for_status()
    return resp.json()


def main():
    if len(sys.argv) != 2:
        print("Usage: python enrich_tmdb.py YOUR_TMDB_API_KEY")
        sys.exit(1)
    api_key = sys.argv[1]

    with open(SEED_PATH, newline="", encoding="utf-8") as f:
        seed_rows = list(csv.DictReader(f))

    film_records = []
    cast_records = []

    for row in seed_rows:
        title = row["title"]
        tmdb_id = row["tmdb_id"]
        print(f"Fetching: {title} (tmdb_id={tmdb_id})")

        try:
            data = get_movie_details(api_key, tmdb_id)
        except requests.HTTPError as e:
            print(f"  ERROR fetching {title}: {e}. Skipping -- check this ID manually.")
            continue

        film_records.append({
            "title": title,
            "phase": row["phase"],
            "tmdb_id": tmdb_id,
            "release_date": data.get("release_date", row["release_date"]),
            "runtime_minutes": data.get("runtime"),
            "vote_average_tmdb": data.get("vote_average"),
            "vote_count_tmdb": data.get("vote_count"),
            "popularity_tmdb": data.get("popularity"),
            "budget_tmdb": data.get("budget"),       # often 0/missing -- cross-check vs Box Office Mojo
            "revenue_tmdb": data.get("revenue"),      # same caveat
            "genres": "|".join(g["name"] for g in data.get("genres", [])),
            "director": next(
                (c["name"] for c in data.get("credits", {}).get("crew", [])
                 if c.get("job") == "Director"),
                None,
            ),
            "imdb_id": data.get("imdb_id"),
        })

        cast_list = data.get("credits", {}).get("cast", [])
        for member in cast_list[:MAX_CAST_PER_FILM]:
            cast_records.append({
                "film_title": title,
                "tmdb_id": tmdb_id,
                "person_name": member.get("name"),
                "character_name": member.get("character"),
                "billing_order": member.get("order"),
            })

        time.sleep(0.05)

    with open(FILMS_OUT, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=film_records[0].keys())
        writer.writeheader()
        writer.writerows(film_records)
    print(f"\nWrote {len(film_records)} films to {FILMS_OUT}")

    with open(CAST_OUT, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=cast_records[0].keys())
        writer.writeheader()
        writer.writerows(cast_records)
    print(f"Wrote {len(cast_records)} cast rows to {CAST_OUT}")
    print("\nNote: budget_tmdb/revenue_tmdb are frequently 0 or incomplete on TMDB.")
    print("Treat Box Office Mojo / The Numbers as your source of truth for financials --")
    print("use these TMDB columns only as a sanity-check cross-reference.")


if __name__ == "__main__":
    main()
