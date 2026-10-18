#!/usr/bin/env python3
"""Trims the F1 research files into what the app bundles: Catalog/f1-circuits.json and Catalog/f1-calendar.json."""
import json, pathlib

root = pathlib.Path(__file__).resolve().parents[2]
out = root / "Witness/Resources/Catalog"

circuits = json.load(open(root / "Tools/f1/circuits.json"))
keep = ["id", "name", "aliases", "city", "region", "country", "countryCode", "latitude", "longitude", "sports", "leagues",
        "homeTeams", "timeZone", "capacity", "opened", "lengthKm", "turns", "lapRecord", "firstGrandPrix", "direction",
        "street", "geofenceMeters", "f1Status", "layoutNote"]
slim = [{k: c[k] for k in keep if k in c and c[k] is not None} for c in circuits]
json.dump(slim, open(out / "f1-circuits.json", "w"), separators=(",", ":"), ensure_ascii=False)

cal = json.load(open(root / "Tools/f1/calendar.json"))
races = []
for r in cal:
    res = r.get("results") or None
    races.append({
        "id": r["id"], "season": r["season"], "round": r["round"], "name": r["name"], "shortName": r.get("shortName") or r["name"],
        "circuitId": r["circuitId"], "status": r["status"], "raceStartUtc": r["raceStartUtc"],
        "raceLocalDate": r["raceLocalDate"], "weekendStartLocalDate": r["weekendStartLocalDate"],
        "sprintWeekend": r.get("sprintWeekend", False), "espnEventId": r.get("espnEventId"),
        "results": None if not res else {
            "winner": res.get("winner"), "podium": res.get("podium", []), "podiumNames": res.get("podiumNames", []),
            "pole": res.get("pole"), "fastestLap": res.get("fastestLap"), "laps": res.get("laps"),
            "winnerTime": res.get("winnerTime"),
        },
        "notes": r.get("notes", []),
    })
json.dump(races, open(out / "f1-calendar.json", "w"), separators=(",", ":"), ensure_ascii=False)
print(len(slim), "circuits", len(races), "races")
