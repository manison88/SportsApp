#!/usr/bin/env python3
"""Adds every men's national soccer team ESPN lists in the World Cup, its qualifying, the Euros, Nations Leagues,
continental cups and friendlies to Witness/Resources/Catalog/national-teams.json. Existing records are kept.
usage: python3 Tools/teams/add_national.py
"""
import json, urllib.request, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
path = root / "Witness/Resources/Catalog/national-teams.json"
LEAGUES = ["fifa.world", "fifa.worldq.uefa", "fifa.worldq.conmebol", "fifa.worldq.concacaf", "fifa.worldq.afc",
           "fifa.worldq.caf", "fifa.worldq.ofc", "uefa.euro", "uefa.euroq", "uefa.nations", "concacaf.nations.league",
           "concacaf.gold", "concacaf.gold_qual", "conmebol.america", "caf.nations", "caf.nations_qual",
           "afc.asian.cup", "fifa.friendly"]
have = json.load(open(path))
ids = {t["id"] for t in have}
abbr = {t["abbreviation"] for t in have}
names = {t["locationName"].lower() for t in have}
added = 0
for lg in LEAGUES:
    url = f"https://site.api.espn.com/apis/site/v2/sports/soccer/{lg}/teams?limit=300"
    try:
        data = json.load(urllib.request.urlopen(url, timeout=30))
        teams = data["sports"][0]["leagues"][0]["teams"]
    except Exception as e:
        print("skip", lg, e); continue
    for w in teams:
        t = w["team"]
        tid = f"nat-{t['id']}"
        name = t.get("location") or t.get("displayName")
        if tid in ids or name.lower() in names or t.get("abbreviation") in abbr: continue
        primary = (t.get("color") or "3A4150").upper()
        alt = (t.get("alternateColor") or "FFFFFF").upper()
        have.append({"id": tid, "sport": "soccer", "league": "National teams", "abbreviation": t.get("abbreviation") or name[:3].upper(),
                     "locationName": name, "teamName": t.get("name") or name, "monogram": name[:2].upper(),
                     "colors": {"primary": primary, "secondary": alt, "accent": primary},
                     "externalIds": {"espn": t["id"], "espnLeague": "soccer/fifa.world"}, "leagueKey": "soccer/fifa.world"})
        ids.add(tid); abbr.add(have[-1]["abbreviation"]); names.add(name.lower()); added += 1
have.sort(key=lambda t: t["locationName"])
json.dump(have, open(path, "w"), ensure_ascii=False, indent=1)
print("added", added, "total", len(have))
