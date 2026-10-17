#!/usr/bin/env python3
"""Validates countries.json, us-states.json, canada-provinces.json and cross-checks Tools/teams/*.json. Usage: validate.py"""
import glob, json, os, sys
from zoneinfo import available_timezones

HERE = os.path.dirname(os.path.abspath(__file__))
TEAMS = os.path.join(HERE, "..", "teams")
errors, notes = [], []
TZ = available_timezones()
# team files use these for confederation / global rows; they are not countries
PSEUDO_CODES = {"AFC", "CAF", "CONCACAF", "CONMEBOL", "OFC", "UEFA", "EU", "XX"}
PSEUDO_NAMES = {"Africa", "Asia", "Europe", "North America", "South America", "Oceania", "International"}


def load(name):
    p = os.path.join(HERE, name)
    if not os.path.exists(p):
        errors.append(f"missing file {name}")
        return []
    return json.load(open(p))


def num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def in_bbox(bb, lat, lon):
    return bb[0] <= lat <= bb[2] and (bb[1] <= lon <= bb[3] if bb[1] <= bb[3] else (lon >= bb[1] or lon <= bb[3]))


def check_bbox(tag, r):
    bb = r.get("bbox")
    if not (isinstance(bb, list) and len(bb) == 4 and all(num(x) for x in bb)):
        errors.append(f"{tag}: bad bbox"); return
    if not (-90 <= bb[0] <= bb[2] <= 90) or not (-180 <= bb[1] <= 180 and -180 <= bb[3] <= 180):
        errors.append(f"{tag}: bbox out of range {bb}")
    if num(r.get("latitude")) and num(r.get("longitude")) and not in_bbox(bb, r["latitude"], r["longitude"]):
        errors.append(f"{tag}: bbox does not contain centre")


def check_tz(tag, r):
    tz = r.get("timeZones")
    if not isinstance(tz, list) or not tz:
        errors.append(f"{tag}: missing timeZones"); return
    for t in tz:
        if t not in TZ: errors.append(f"{tag}: unknown time zone {t}")


# ---------------- countries ----------------
countries = load("countries.json")
REQ = ["code", "code3", "name", "officialName", "continent", "capital", "latitude", "longitude", "bbox", "population",
       "flag", "uefa", "eu", "schengen", "euro", "currency", "languages", "timeZones"]
seen, seen3, names = set(), set(), {}
for r in countries:
    c = r.get("code", "?")
    if c in seen: errors.append(f"duplicate code {c}")
    seen.add(c)
    if r.get("code3") in seen3: errors.append(f"{c}: duplicate code3 {r.get('code3')}")
    seen3.add(r.get("code3"))
    for f in REQ:
        if f not in r: errors.append(f"{c}: missing field {f}")
    for f in ("name", "officialName", "continent", "flag", "code3"):
        if not r.get(f): errors.append(f"{c}: empty {f}")
    for f in ("uefa", "eu", "schengen", "euro"):
        if not isinstance(r.get(f), bool): errors.append(f"{c}: {f} must be bool")
    if not num(r.get("latitude")) or not -90 <= r["latitude"] <= 90: errors.append(f"{c}: bad latitude")
    if not num(r.get("longitude")) or not -180 <= r["longitude"] <= 180: errors.append(f"{c}: bad longitude")
    if r.get("capital") and not (num(r.get("capitalLatitude")) and num(r.get("capitalLongitude"))):
        notes.append(f"{c}: capital '{r['capital']}' has no coordinates")
    elif num(r.get("capitalLatitude")) and not (-90 <= r["capitalLatitude"] <= 90 and -180 <= r["capitalLongitude"] <= 180):
        errors.append(f"{c}: capital coordinates out of range")
    check_bbox(c, r); check_tz(c, r)
    if r.get("population") is not None and (not isinstance(r["population"], int) or r["population"] < 0):
        errors.append(f"{c}: bad population")
    if r.get("eu") and not r.get("schengen") and c not in ("IE", "CY"): notes.append(f"{c}: EU member outside Schengen")
    if c.startswith("GB-") and r.get("parent") != "GB": errors.append(f"{c}: parent must be GB")
    for key in [r.get("name"), r.get("officialName")] + r.get("aliases", []):
        names.setdefault(key, c)
by = {r["code"]: r for r in countries if "code" in r}

# Europe completeness
uefa = [r for r in countries if r.get("uefa")]
if len(uefa) < 55: errors.append(f"only {len(uefa)} UEFA members (need >= 55)")
for need in ["AD", "SM", "MC", "LI", "VA", "XK", "GI", "FO", "GB-ENG", "GB-SCT", "GB-WLS", "GB-NIR", "GB", "RU", "TR", "IL", "KZ"]:
    if need not in by: errors.append(f"Europe: missing {need}")
for r in uefa:
    for f in ("fifaCode", "footballAssociation", "subregion", "capital", "population"):
        if not r.get(f): errors.append(f"{r['code']}: UEFA member missing {f}")
    if r.get("continent") != "Europe": errors.append(f"{r['code']}: UEFA member should have continent Europe")
for r in countries:
    if r.get("continent") == "Europe":
        for f in ("subregion", "capital", "population", "capitalLatitude"):
            if not r.get(f): errors.append(f"{r['code']}: Europe record missing {f}")
if sum(1 for r in countries if r.get("eu")) != 27: errors.append("EU should have 27 members")
if sum(1 for r in countries if r.get("schengen")) != 29: errors.append("Schengen should have 29 members")

# ---------------- states / provinces ----------------
def check_regions(fname, types, expect):
    rows = load(fname)
    seen = set()
    for r in rows:
        c = r.get("code", "?"); tag = f"{fname}:{c}"
        if c in seen: errors.append(f"{tag}: duplicate code")
        seen.add(c)
        for f in ("code", "name", "type", "capital", "latitude", "longitude", "bbox", "population", "timeZones"):
            if r.get(f) in (None, "", []): errors.append(f"{tag}: missing {f}")
        if r.get("type") not in types: errors.append(f"{tag}: bad type {r.get('type')}")
        if not num(r.get("latitude")) or not -90 <= r["latitude"] <= 90: errors.append(f"{tag}: bad latitude")
        if not num(r.get("longitude")) or not -180 <= r["longitude"] <= 180: errors.append(f"{tag}: bad longitude")
        check_bbox(tag, r); check_tz(tag, r)
    for k, n in expect.items():
        got = sum(1 for r in rows if r.get("type") == k)
        if got != n: errors.append(f"{fname}: expected {n} of type {k}, found {got}")
    return rows

us = check_regions("us-states.json", {"state", "district", "territory"}, {"state": 50, "district": 1, "territory": 5})
ca = check_regions("canada-provinces.json", {"province", "territory"}, {"province": 10, "territory": 3})

# ---------------- team data cross-check ----------------
def walk(x, out):
    if isinstance(x, dict):
        for k, v in x.items():
            if k in ("countryCode", "country") and isinstance(v, str): out.add((k, v))
            else: walk(v, out)
    elif isinstance(x, list):
        for i in x: walk(i, out)

used = set()
files = sorted(glob.glob(os.path.join(TEAMS, "*.json")))
for f in files:
    s = set()
    try: walk(json.load(open(f)), s)
    except Exception as e:
        errors.append(f"cannot read {os.path.basename(f)}: {e}"); continue
    used |= s
missing_codes = sorted(v for k, v in used if k == "countryCode" and v not in by and v not in PSEUDO_CODES)
missing_names = sorted(v for k, v in used if k == "country" and v not in names and v not in PSEUDO_NAMES)
print(f"teams files scanned: {len(files)}; distinct countryCodes: {len({v for k, v in used if k == 'countryCode'})}; "
      f"distinct countries: {len({v for k, v in used if k == 'country'})}")
print(f"team countryCodes missing from countries.json: {missing_codes if missing_codes else 'none'}")
print(f"team country names missing from countries.json: {missing_names if missing_names else 'none'}")
for c in missing_codes: errors.append(f"teams use countryCode {c} missing from countries.json")
for c in missing_names: errors.append(f"teams use country '{c}' missing from countries.json")
aliased = sorted(v for k, v in used if k == "country" and v in names and names[v] and by.get(names[v], {}).get("name") != v)
if aliased: notes.append(f"team country names matched only via officialName/alias: {aliased}")
pseudo = sorted({v for k, v in used if v in PSEUDO_CODES or v in PSEUDO_NAMES})
notes.append(f"non-country team values (allowed): {pseudo}")

for n in notes: print("note:", n)
print(f"countries={len(countries)} uefa={len(uefa)} europe={sum(1 for r in countries if r.get('continent') == 'Europe')} "
      f"us={len(us)} canada={len(ca)}")
for e in errors: print("ERROR:", e)
print(f"{len(errors)} errors")
sys.exit(1 if errors else 0)
