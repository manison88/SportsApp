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

venues = load("venues.json") + load("extra-venues.json", os.path.join(ROOT, "Catalog"))
seen = set(); vs = []
for v in venues:
    if v["id"] in seen: continue
    seen.add(v["id"])
    vs.append({k: v.get(k) for k in ("id", "name", "city", "region", "country", "countryCode", "latitude", "longitude", "sports", "timeZone", "capacity", "opened")})
with open(os.path.join(ROOT, "Catalog", "venues.json"), "w") as f:
    json.dump(vs, f, ensure_ascii=False, indent=1)
print(len(out), "games;", len(vs), "venues")

import shutil
shutil.copy(os.path.join(SEED, "teams.json"), os.path.join(ROOT, "Catalog", "teams.json"))
for name in ("trips.json", "people.json", "profile.json"):
    shutil.copy(os.path.join(SEED, name), os.path.join(OUT, name))
