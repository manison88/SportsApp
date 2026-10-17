#!/usr/bin/env python3
"""Re-fetches the CURRENT season of every ESPN league that has schedule files, so published packs stay up to date
(scores of games just played, newly scheduled games, postponements). Reads a rolling window around today, one request per day.

  python3 Tools/packs/refresh_current.py [--season 2026] [--league baseball/mlb ...]

Writes Tools/schedules/<scope>/<leagueSlug>/<season>.json in place for leagues whose current-season file already exists.
Leagues with split files (<season>-<tag>.json) and non-ESPN sources are left to their own scripts.
"""
import argparse, glob, json, os, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = "https://site.api.espn.com/apis/site/v2/sports/"

def get(url, tries=3):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "witness-packs/1.0"}), timeout=30) as r:
                return json.load(r)
        except Exception:
            time.sleep(1.5 * (i + 1))
    return None

def row(e):
    c = (e.get("competitions") or [{}])[0]
    comps = c.get("competitors") or []
    home = next((x for x in comps if x.get("homeAway") == "home"), None)
    away = next((x for x in comps if x.get("homeAway") == "away"), None)
    if not home or not away:
        return None
    st = (e.get("status") or {}).get("type") or {}
    name = st.get("name", "")
    status = "F" if st.get("completed") else "P" if "POSTPONED" in name else "C" if "CANCEL" in name else "S" if st.get("state") == "pre" else "O"
    def score(x):
        try:
            return int(float(x.get("score")))
        except (TypeError, ValueError):
            return None
    final = status == "F"
    v = c.get("venue") or {}
    addr = v.get("address") or {}
    note = ((c.get("notes") or [{}])[0].get("headline") or "") if c.get("notes") else ""
    start = e["date"][:16] + "Z" if len(e["date"]) >= 16 else e["date"]
    return ([str(e["id"]), start, str(home["team"]["id"]), str(away["team"]["id"]),
             score(home) if final else None, score(away) if final else None, str(v["id"]) if v.get("id") else None, status, note],
            {str(home["team"]["id"]): home["team"].get("abbreviation", ""), str(away["team"]["id"]): away["team"].get("abbreviation", "")},
            {str(v["id"]): [v.get("fullName", ""), addr.get("city", ""), addr.get("state", ""), addr.get("country", "")]} if v.get("id") else {})

def refresh(path, league, season, today, back=10, ahead=21):
    """Re-reads one day at a time (ESPN rejects date ranges now): `back` days before today, so results settle, to `ahead` days after."""
    data = json.load(open(path))
    games = {g[0]: g for g in data["games"]}
    teams, venues = dict(data["teams"]), dict(data["venues"])
    days = [today + timedelta(days=d) for d in range(-back, ahead + 1)]

    def fetch(day):
        return get(f"{BASE}{league}/scoreboard?dates={day:%Y%m%d}&limit=1000")

    with ThreadPoolExecutor(max_workers=6) as pool:
        responses = list(pool.map(fetch, days))
    answered = sum(1 for r in responses if r is not None)
    changed = 0
    for j in responses:
        for e in (j or {}).get("events", []):
            r = row(e)
            if not r:
                continue
            g, t, v = r
            if games.get(g[0]) != g:
                games[g[0]] = g
                changed += 1
            teams.update({k: x for k, x in t.items() if x})
            venues.update(v)
    if answered == 0:
        print(f"  {league}: no day answered; file left as it was", file=sys.stderr)
        return 0, 0
    data["games"] = sorted(games.values(), key=lambda g: g[1])
    data["teams"], data["venues"] = teams, venues
    data["fetched"] = date.today().isoformat()
    with open(path, "w") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    return changed, answered

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--season", type=int, default=datetime.now(timezone.utc).year)
    ap.add_argument("--league", action="append")
    args = ap.parse_args()
    today = datetime.now(timezone.utc).date()
    paths = glob.glob(os.path.join(ROOT, "schedules", "*", "*", f"{args.season}.json")) \
        + glob.glob(os.path.join(ROOT, "schedules", "*", "*", f"{args.season - 1}.json"))
    for path in sorted(paths):
        league = json.load(open(path)).get("league", "")
        if args.league and league not in args.league:
            continue
        if json.load(open(path)).get("source", "espn") != "espn":
            continue
        changed, answered = refresh(path, league, int(os.path.basename(path)[:4]), today)
        print(f"{league} {os.path.basename(path)}: {changed} changed ({answered} days answered)")

if __name__ == "__main__":
    main()
