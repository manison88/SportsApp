#!/usr/bin/env python3
"""Merges the researched team files into the app's catalog.

Writes Witness/Resources/Catalog/teams-more.json (everything not already in teams.json / national-teams.json, in the app's
Team shape) and adds the *-missing-venues.json grounds to Catalog/venues.json, rewriting each team's homeVenueId when a
missing venue turned out to be an existing one. Sports the app does not have yet (volleyball, rugby) are skipped.
Run from anywhere: python3 Tools/teams/build_catalog.py
"""
import glob, json, math, os, re, unicodedata

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CAT = os.path.join(ROOT, "Witness/Resources/Catalog")
APP_SPORTS = {"baseball", "football", "basketball", "hockey", "soccer", "motorsport", "handball"}
FIELDS = ("id", "name", "aliases", "city", "region", "country", "countryCode", "latitude", "longitude",
          "sports", "leagues", "homeTeams", "timeZone", "capacity", "opened")
STOP = {"the", "stadium", "estadio", "stade", "stadio", "stadion", "field", "arena", "park", "center", "centre",
        "de", "del", "la", "el", "at", "do", "da", "di", "of", "and", "y", "e", "municipal"}

def tokens(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()
    return {w for w in re.split(r"[^a-z0-9]+", s) if w and w not in STOP}

def meters(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a["latitude"], a["longitude"], b["latitude"], b["longitude"]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(h))

def same_place(a, b):
    if meters(a, b) > 300: return False
    na = tokens(a["name"]).union(*[tokens(x) for x in a.get("aliases") or []])
    nb = tokens(b["name"]).union(*[tokens(x) for x in b.get("aliases") or []])
    return bool(na & nb) or meters(a, b) < 120

def union(a, b): return list(dict.fromkeys((a or []) + (b or [])))

# ---- venues
venues = json.load(open(f"{CAT}/venues.json"))
remap, added, merged = {}, 0, 0
for path in sorted(glob.glob(os.path.join(ROOT, "Tools/teams/*-missing-venues.json"))):
    for v in json.load(open(path)):
        v = {k: v.get(k) for k in FIELDS}
        if v["latitude"] is None or v["longitude"] is None: continue
        match = next((x for x in venues if x["id"] == v["id"]), None) or next((x for x in venues if same_place(x, v)), None)
        if match:
            remap[v["id"]] = match["id"]
            for k in ("sports", "leagues", "homeTeams", "aliases"): match[k] = union(match.get(k), v.get(k))
            if v["name"] != match["name"]: match["aliases"] = union(match.get("aliases"), [v["name"]])
            for k in ("region", "capacity", "opened"):
                if match.get(k) is None and v.get(k) is not None: match[k] = v[k]
            merged += 1
        else:
            for k in ("aliases", "leagues", "homeTeams"): v[k] = v.get(k) or []
            venues.append(v); added += 1
# The app has no volleyball or rugby yet: keep only the sports it knows, and drop grounds that served nothing else.
for v in venues: v["sports"] = [x for x in v.get("sports") or [] if x in APP_SPORTS]
venues = [v for v in venues if v["sports"]]
venues.sort(key=lambda v: (v["countryCode"], v["city"], v["name"]))
json.dump(venues, open(f"{CAT}/venues.json", "w"), ensure_ascii=False, indent=1)
venue_ids = {v["id"] for v in venues}
print(f"venues: +{added}, {merged} merged, total {len(venues)}")

# ---- teams
seed = json.load(open(f"{CAT}/teams.json"))
have_ids = {t["id"] for t in seed}
norm = lambda x: re.sub(r"[^a-z0-9]", "", unicodedata.normalize("NFKD", x or "").encode("ascii", "ignore").decode().lower())
seed_keys = {(t["sport"], norm(t["league"]), t["abbreviation"]) for t in seed}
SAME_AS_SEED = {"esp2-eib"}   # Eibar: LaLiga in the seed, LaLiga 2 in the research
nationals = json.load(open(f"{CAT}/national-teams.json"))
have_ids |= {t["id"] for t in nationals}
have_nat = {(t["sport"], t["abbreviation"]) for t in nationals}
espn_seen = set()
out, skipped = [], {"sport": 0, "dupe": 0}
for path in sorted(glob.glob(os.path.join(ROOT, "Tools/teams/*-teams.json"))):
    for t in json.load(open(path)):
        if t["sport"] not in APP_SPORTS: skipped["sport"] += 1; continue
        key = (t["sport"], t["abbreviation"])
        if (t["sport"], norm(t["league"]), t["abbreviation"]) in seed_keys or t["id"] in SAME_AS_SEED:
            skipped["dupe"] += 1; continue
        # A women's side shares its country's code with the men's one: only the men's soccer sides in national-teams.json are the same team.
        women = t.get("gender") == "women"
        if t["id"] in have_ids or (t["kind"] == "national" and key in have_nat and not women) \
           or (t["league"].endswith("national teams") and key in have_nat and not women):
            skipped["dupe"] += 1; continue
        have_ids.add(t["id"])
        ext = t.get("externalIds") or {}
        venue = remap.get(t.get("homeVenueId"), t.get("homeVenueId"))
        rec = {"id": t["id"], "sport": t["sport"], "league": t["league"], "abbreviation": t["abbreviation"],
               "locationName": t["locationName"], "teamName": t["teamName"], "monogram": t["monogram"],
               "colors": t["colors"], "leagueKey": t["leagueKey"]}
        if t["countryCode"] != "XX": rec["countryCode"] = t["countryCode"]
        if ext.get("espn"): rec["externalIds"] = {"espn": str(ext["espn"]), "espnLeague": ext.get("espnLeague") or t["leagueKey"]}
        if venue in venue_ids: rec["homeVenueId"] = venue
        out.append(rec)
json.dump(out, open(f"{CAT}/teams-more.json", "w"), ensure_ascii=False, separators=(",", ":"))
print("teams:", len(out), "skipped", skipped, "bytes", os.path.getsize(f"{CAT}/teams-more.json"))
