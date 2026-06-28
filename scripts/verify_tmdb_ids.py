"""
Step 1: Verify TMDB IDs in our seed list.
This script searches TMDB by title for every row, compares the result to what we have on file, and
writes out a verification report so you can fix anything before building the rest of the pipeline on top of it.

Usage:
    python verify_tmdb_ids.py TMDB_API_KEY
"""
import csv
import sys
import time
import requests

SEED_PATH = "mcu_films_seed.csv"
OUT_PATH = "tmdb_id_verification.csv"
SEARCH_URL = "https://api.themoviedb.org/3/search/movie"


def search_title(api_key: str, title: str, year: int):
    """Search TMDB for a title, optionally narrowed by release year."""
    params = {"api_key": api_key, "query": title, "year": year}
    resp = requests.get(SEARCH_URL, params=params, timeout=10)
    resp.raise_for_status()
    return resp.json().get("results", [])


def main():
    if len(sys.argv) != 2:
        print("Usage: python verify_tmdb_ids.py YOUR_TMDB_API_KEY")
        sys.exit(1)
    api_key = sys.argv[1]

    with open(SEED_PATH, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    report_rows = []
    mismatches = 0

    for row in rows:
        title = row["title"]
        year = int(row["release_date"][:4])
        claimed_id = row["tmdb_id"]

        results = search_title(api_key, title, year)
        time.sleep(0.05)  # well under the ~40 req/sec limit, just being polite

        if not results:
            status = "NO_MATCH_FOUND"
            found_id = ""
            found_title = ""
        else:
            top = results[0]
            found_id = str(top["id"])
            found_title = top["title"]
            status = "OK" if found_id == claimed_id else "MISMATCH"
            if status == "MISMATCH":
                mismatches += 1

        report_rows.append({
            "title": title,
            "claimed_tmdb_id": claimed_id,
            "found_tmdb_id": found_id,
            "found_title": found_title,
            "status": status,
        })
        print(f"{status:16s} {title:50s} claimed={claimed_id:>8s} found={found_id:>8s}")

    with open(OUT_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=report_rows[0].keys())
        writer.writeheader()
        writer.writerows(report_rows)

    print(f"\nDone. {mismatches} mismatch(es) / {len(rows)} films.")
    print(f"Full report written to {OUT_PATH}")
    if mismatches:
        print("Fix the tmdb_id values in mcu_films_seed.csv before proceeding to enrich.py.")


if __name__ == "__main__":
    main()
