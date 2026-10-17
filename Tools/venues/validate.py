#!/usr/bin/env python3
"""Validates venue research files (Tools/venues/*.json) before they're merged
into the app catalog. Usage: python3 Tools/venues/validate.py [file ...]"""
import json, sys, glob, os, re
from zoneinfo import ZoneInfo

SPORTS = {"baseball", "football", "basketball", "hockey", "soccer", "motorsport", "handball", "volleyball"}
REQUIRED = ["id", "name", "city", "country", "countryCode", "latitude", "longitude", "sports", "timeZone"]

def check(path):
    errors, warnings = [], []
    try:
        data = json.load(open(path))
    except Exception as e:
        return [f"{path}: not valid JSON: {e}"], []
    if not isinstance(data, list):
        return [f"{path}: top level must be an array"], []
    ids = set()
    for i, v in enumerate(data):
        where = f"{os.path.basename(path)}[{i}] {v.get('id', '?')}"
        for k in REQUIRED:
            if v.get(k) in (None, "", []):
                errors.append(f"{where}: missing {k}")
        vid = v.get("id", "")
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", vid or ""):
            errors.append(f"{where}: id must be a lowercase slug")
        if vid in ids:
            errors.append(f"{where}: duplicate id")
        ids.add(vid)
        lat, lon = v.get("latitude"), v.get("longitude")
        if not isinstance(lat, (int, float)) or not -90 <= lat <= 90:
            errors.append(f"{where}: bad latitude")
        if not isinstance(lon, (int, float)) or not -180 <= lon <= 180:
            errors.append(f"{where}: bad longitude")
        if isinstance(lat, float) and len(str(lat).split(".")[-1]) < 3:
            warnings.append(f"{where}: latitude has under 3 decimals; photo matching needs ~100m precision")
        for s in v.get("sports", []):
            if s not in SPORTS:
                errors.append(f"{where}: unknown sport {s}")
        try:
            ZoneInfo(v.get("timeZone", ""))
        except Exception:
            errors.append(f"{where}: bad timeZone {v.get('timeZone')}")
        if not re.fullmatch(r"[A-Z]{2}", v.get("countryCode", "")):
            errors.append(f"{where}: countryCode must be ISO 3166-1 alpha-2")
        for k in ("aliases", "leagues", "homeTeams"):
            if k in v and not isinstance(v[k], list):
                errors.append(f"{where}: {k} must be an array")
        for lg in v.get("leagues", []):
            if not re.fullmatch(r"[a-z]+/[a-z0-9.\-]+", lg):
                errors.append(f"{where}: league '{lg}' must be an ESPN path like soccer/esp.1")
    return errors, warnings

paths = sys.argv[1:] or sorted(glob.glob(os.path.join(os.path.dirname(__file__), "*.json")))
total_e = 0
for p in paths:
    e, w = check(p)
    total_e += len(e)
    n = len(json.load(open(p))) if not e or "JSON" not in e[0] else 0
    print(f"{os.path.basename(p)}: {n} venues, {len(e)} errors, {len(w)} warnings")
    for line in e[:40]: print("  ERROR", line)
    for line in w[:10]: print("  warn ", line)
sys.exit(1 if total_e else 0)
