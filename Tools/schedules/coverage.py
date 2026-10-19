#!/usr/bin/env python3
"""Writes Tools/schedules/COVERAGE.md: for every catalog league, how many teams it has and which seasons are in the published packs.
  python3 Tools/packs/build_packs.py --out dist/packs && python3 Tools/schedules/coverage.py dist/packs"""
import collections, json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import espn_lib as L

dist = sys.argv[1]
manifest = json.loads(json.load(open(os.path.join(dist, "manifest.json")))["body"])
seasons = collections.defaultdict(set)
for p in manifest["packs"]:
    if p["kind"] == "schedule":
        seasons[p["league"]].add(p["season"])
SEED = {"MLB": "baseball/mlb", "NFL": "football/nfl", "NBA": "basketball/nba", "NHL": "hockey/nhl", "MLS": "soccer/usa.1",
        "LaLiga": "soccer/esp.1", "Bundesliga": "soccer/ger.1", "Premier League": "soccer/eng.1"}


def parent(key):
    """College conference keys (football/college-football/acc) share their parent league's schedule files."""
    parts = key.split("/")
    return "/".join(parts[:2]) if len(parts) == 3 else key


leagues = collections.defaultdict(lambda: {"teams": 0, "name": ""})
for f in ("teams.json", "teams-more.json", "national-teams.json"):
    for t in json.load(open(os.path.join(L.CATALOG, f))):
        key = t.get("leagueKey") or (t.get("externalIds") or {}).get("espnLeague") or SEED.get(t["league"]) or f"{t['sport']}/{t['league']}"
        key = parent(key)
        leagues[key]["teams"] += 1
        leagues[key]["name"] = t["league"]
rows, teams_total, teams_covered = [], 0, 0
for key, v in sorted(leagues.items()):
    s = sorted(seasons.get(key, []))
    teams_total += v["teams"]
    if s:
        teams_covered += v["teams"]
    rows.append((key, v["name"], v["teams"], s))
out = ["# Schedule coverage in the published packs", "",
       f"{teams_covered} of {teams_total} catalog teams belong to a league with published schedules (2006-2026 target).",
       "A league row says nothing about each team; a few teams in a covered league can still lack games (promoted clubs, new franchises).", "",
       "| League | Teams | Seasons | First | Last |", "|---|---|---|---|---|"]
for key, name, n, s in rows:
    out.append(f"| {name} (`{key}`) | {n} | {len(s)} | {s[0] if s else '-'} | {s[-1] if s else '-'} |")
gaps = [r for r in rows if not r[3]]
out += ["", f"## Leagues with no published schedule ({len(gaps)} leagues, {sum(r[2] for r in gaps)} teams)", ""]
out += [f"- {r[1]} (`{r[0]}`): {r[2]} teams" for r in sorted(gaps, key=lambda r: -r[2])]
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "COVERAGE.md"), "w").write("\n".join(out) + "\n")
print(out[2])
print(f"{len(gaps)} leagues without schedules; {len([r for r in rows if r[3] and len(r[3]) < 15])} leagues with fewer than 15 seasons")
