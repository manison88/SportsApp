#!/usr/bin/env python3
"""Builds Witness/Resources/Sample/*.json (the app's sample library) from the
canonical seed data in Witness/Resources/SeedData. Run after editing seed data."""
import json, os

ROOT = os.path.join(os.path.dirname(__file__), "..", "Witness", "Resources")
SEED = os.path.join(ROOT, "SeedData")
OUT = os.path.join(ROOT, "Sample")
os.makedirs(OUT, exist_ok=True)

def load(name, base=SEED):
    with open(os.path.join(base, name)) as f:
        return json.load(f)

games = load("games.json")
profile = load("profile.json")
favorites = set(profile["favoriteTeamIds"])

PHOTOS = {
    "wrigley": ["wrigley-night", "wrigley-scoreboard", "wrigley-bleachers", "wrigley-night-2", "wrigley-scoreboard-wide"],
    "fenway": ["fenway-night", "fenway-day", "fenway-postcard"],
    "lambeau": ["lambeau-concourse", "lambeau-exterior"],
    "soldier": ["soldier-skyline", "soldier-aerial"],
    "united-center": ["united-center-court"],
    "camp-nou": ["camp-nou-aerial"],
}
# Hand-picked heroes for the screens the mockups feature.
HERO = {"mlb-2016-ws5": ["wrigley-night", "wrigley-scoreboard", "wrigley-night-2", "wrigley-bleachers"],
        "nfl-2025-w18-gb": ["lambeau-concourse", "lambeau-exterior"]}

def weather(w, indoor):
    if not w or indoor:
        return None
    code = w["weather_code"]
    if code == 0: cond, sym = "Clear", "sun.max.fill"
    elif code in (1, 2): cond, sym = "Partly cloudy", "cloud.sun.fill"
    elif code == 3: cond, sym = "Overcast", "cloud.fill"
    elif code in (45, 48): cond, sym = "Fog", "cloud.fog.fill"
    elif 51 <= code <= 67 or 80 <= code <= 82: cond, sym = "Rain", "cloud.rain.fill"
    elif 71 <= code <= 77 or code in (85, 86): cond, sym = "Snow", "cloud.snow.fill"
    else: cond, sym = "Storms", "cloud.bolt.rain.fill"
    return {"temperatureF": round(w["temperature_2m"], 1), "condition": cond, "symbol": sym}

def line_score(g):
    labels = [p["label"] for p in g["periods"]]
    home = [0] * len(labels); away = [0] * len(labels)
    ph = pa = 0
    for e in g["events"]:
        if e["period"] not in labels: continue
        i = labels.index(e["period"])
        home[i] += max(0, e["homeScore"] - ph); away[i] += max(0, e["awayScore"] - pa)
        ph, pa = e["homeScore"], e["awayScore"]
    return home, away

def period_label(g, e):
    if g["sport"] == "baseball" and e.get("clock") in ("Top", "Bot"):
        return ("T" if e["clock"] == "Top" else "B") + e["period"]
    return e["period"]

out = []
counters = {}
for g in games:
    h, a = g["home"], g["away"]
    rooting = None
    for side in (h, a):
        if side and side["teamId"] in favorites:
            rooting = side["teamId"]
    if rooting is None and h: rooting = h["teamId"]
    if g["id"] in HERO:
        names = HERO[g["id"]]
    else:
        pool = PHOTOS.get(g["venueId"], [])
        if g["venueId"] == "soldier" and g["sport"] == "soccer":
            pool = ["soldier-soccer", "soldier-skyline"]
        n = counters.get(g["venueId"], 0); counters[g["venueId"]] = n + 1
        names = [pool[(n + k) % len(pool)] for k in range(min(3, len(pool)))] if pool else []
    lh, la = line_score(g) if h else ([], [])
    plays = [{"id": e["id"], "time": e["timestamp"], "period": period_label(g, e), "text": e["description"],
              "homeScore": e["homeScore"], "awayScore": e["awayScore"], "isKey": bool(e["isKeyMoment"])}
             for e in g["events"] if e["isKeyMoment"] or e["kind"] == "final"]
    m = g.get("memory") or {}
    podium = []
    if g.get("race"):
        podium = [f"P{r['position']} {r['driverCode']}" for r in g["race"]["results"][:3]]
    out.append({
        "id": g["id"], "sport": g["sport"], "date": g["startTime"], "venueId": g["venueId"],
        "homeTeamId": h["teamId"] if h else None, "awayTeamId": a["teamId"] if a else None,
        "homeScore": h["score"] if h else None, "awayScore": a["score"] if a else None,
        "rootingForTeamId": rooting, "competition": g.get("competition") or (g["race"]["raceName"] if g.get("race") else None),
        "headline": g.get("headline"), "seat": m.get("seat"), "companionIds": m.get("companionIds") or [],
        "note": m.get("note"), "photos": [{"bundled": {"_0": n}} for n in names], "origin": "sample",
        "tripId": m.get("tripId"), "weather": weather(g.get("weather"), g.get("isIndoor")),
        "attendance": g.get("attendance"), "plays": plays,
        "winProbability": [{"time": p["timestamp"], "home": round(p["homeTeamWinProbability"] / 100, 4)} for p in g.get("winProbability") or []],
        "lineHome": lh, "lineAway": la, "savedMoments": [], "podium": podium,
    })

with open(os.path.join(OUT, "library.json"), "w") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

import glob, math, re, unicodedata

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

def union(a, b):
    return list(dict.fromkeys((a or []) + (b or [])))

def merge_into(base, extra, prefer_coords):
    for k in ("sports", "leagues", "homeTeams", "aliases"):
        base[k] = union(base.get(k), extra.get(k))
    if extra["name"] != base["name"]:
        base["aliases"] = union(base["aliases"], [extra["name"]])
    if prefer_coords:
        base["latitude"], base["longitude"] = extra["latitude"], extra["longitude"]
    for k in ("region", "capacity", "opened"):
        if base.get(k) is None and extra.get(k) is not None: base[k] = extra[k]

# Sample and existing catalog venues keep their ids; research files add to them.
venues = []
for v in load("venues.json") + load("extra-venues.json", os.path.join(ROOT, "Catalog")):
    if any(x["id"] == v["id"] for x in venues): continue
    venues.append({k: v.get(k) for k in FIELDS})
research = sorted(glob.glob(os.path.join(os.path.dirname(__file__), "venues", "*.json")))
merged_dupes = 0
for path in research:
    for v in json.load(open(path)):
        v = {k: v.get(k) for k in FIELDS}
        match = next((x for x in venues if x["id"] == v["id"]), None) or next((x for x in venues if same_place(x, v)), None)
        if match:
            merge_into(match, v, prefer_coords=match["id"] == v["id"])
            merged_dupes += 1
        else:
            venues.append(v)
for v in venues:
    for k in ("aliases", "leagues", "homeTeams"):
        v[k] = v.get(k) or []
vs = sorted(venues, key=lambda v: (v["countryCode"], v["city"], v["name"]))
with open(os.path.join(ROOT, "Catalog", "venues.json"), "w") as f:
    json.dump(vs, f, ensure_ascii=False, indent=1)
print(f"{len(research)} research files, {merged_dupes} merged into existing venues")
print(len(out), "games;", len(vs), "venues")

import shutil
shutil.copy(os.path.join(SEED, "teams.json"), os.path.join(ROOT, "Catalog", "teams.json"))
for name in ("trips.json", "people.json", "profile.json"):
    shutil.copy(os.path.join(SEED, name), os.path.join(OUT, name))
