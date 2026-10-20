#!/usr/bin/env python3
"""Snapshots ESPN's team lists for the soccer tournaments into Tools/teams/tournaments/espn-soccer.json (build_tournaments.py reads it).
ESPN's site API is on the allowed-sources list (Tools/schedules/SPEC-2.md). usage: python3 Tools/teams/tournaments/fetch_espn.py
"""
import json, os, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
MEN = ["fifa.world", "fifa.worldq.uefa", "fifa.worldq.conmebol", "fifa.worldq.concacaf", "fifa.worldq.afc", "fifa.worldq.caf",
       "fifa.worldq.ofc", "uefa.euro", "uefa.euroq", "uefa.nations", "concacaf.nations.league", "concacaf.gold", "conmebol.america",
       "caf.nations", "afc.asian.cup", "global.finalissima"]
WOMEN = ["fifa.wwc", "uefa.weuro", "fifa.wworldq.uefa", "fifa.wwcq.ply", "fifa.friendly.w", "fifa.shebelieves", "fifa.w.olympics",
         "concacaf.w.gold", "concacaf.womens.championship", "conmebol.america.femenina", "caf.w.nations", "afc.w.asian.cup",
         "uefa.w.nations"]
CLUBS = ["afc.champions", "afc.cup", "caf.champions", "caf.confed", "concacaf.champions", "uefa.wchampions", "uefa.champions", "uefa.europa",
         "uefa.europa.conf", "conmebol.libertadores", "conmebol.sudamericana", "concacaf.leagues.cup", "fifa.cwc"]


def teams(league):
    url = f"https://site.api.espn.com/apis/site/v2/sports/soccer/{league}/teams?limit=500"
    data = json.load(urllib.request.urlopen(url, timeout=40))
    lg = data["sports"][0]["leagues"][0]
    out = []
    for w in lg["teams"]:
        t = w["team"]
        out.append({"id": t["id"], "abbreviation": t.get("abbreviation"), "location": t.get("location") or t.get("displayName"),
                    "name": t.get("name"), "displayName": t.get("displayName"), "color": t.get("color"), "alt": t.get("alternateColor")})
    return {"name": lg.get("name"), "season": (lg.get("season") or {}).get("year"), "teams": out}


snap = {"men": {}, "women": {}, "clubs": {}}
for key, leagues in (("men", MEN), ("women", WOMEN), ("clubs", CLUBS)):
    for lg in leagues:
        try:
            snap[key][lg] = teams(lg)
        except Exception as e:
            print("skip", lg, e)
json.dump(snap, open(os.path.join(HERE, "espn-soccer.json"), "w"), ensure_ascii=False, separators=(",", ":"))
print({k: {l: len(v["teams"]) for l, v in d.items()} for k, d in snap.items()})
