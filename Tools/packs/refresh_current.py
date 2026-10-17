#!/usr/bin/env python3
"""Re-fetches the CURRENT season of every ESPN league that has schedule files, so published packs stay up to date
(scores of games just played, newly scheduled games, postponements).

  python3 Tools/packs/refresh_current.py [--season 2026] [--league baseball/mlb ...]

Writes Tools/schedules/<scope>/<leagueSlug>/<season>.json in place for leagues whose current-season file already exists.
Leagues with split files (<season>-<tag>.json) and non-ESPN sources are left to their own scripts.
"""
import argparse, glob, json, os, sys, time, urllib.request
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

def refresh(path, league, season, today):
    data = json.load(open(path))
    games = {g[0]: g for g in data["games"]}
    teams, venues = dict(data["teams"]), dict(data["venues"])
    # Re-read from a month before today (results settle) to the end of the season already on file.
    last = max(g[1][:10] for g in data["games"]) if data["games"] else today.isoformat()
    day = today - timedelta(days=31)
    end = datetime.strptime(last, "%Y-%m-%d").date() + timedelta(days=45)
    changed = 0
    while day <= end:
        stop = min(day + timedelta(days=30), end)
        url = f"{BASE}{league}/scoreboard?dates={day:%Y%m%d}-{stop:%Y%m%d}&limit=1000"
        j = get(url)
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
        day = stop + timedelta(days=1)
    data["games"] = sorted(games.values(), key=lambda g: g[1])
    data["teams"], data["venues"] = teams, venues
    data["fetched"] = date.today().isoformat()
    with open(path, "w") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    return changed

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
        print(f"{league} {os.path.basename(path)}: {refresh(path, league, int(os.path.basename(path)[:4]), today)} changed")

if __name__ == "__main__":
    main()
