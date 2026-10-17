#!/usr/bin/env python3
"""Validates <scope>-teams.json, <scope>-leagues.json and <scope>-missing-venues.json together. Usage: validate.py <scope>"""
import json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
scope = sys.argv[1]
errors = []
def load(name):
    p = os.path.join(HERE, f"{scope}-{name}.json")
    if not os.path.exists(p):
        errors.append(f"missing file {os.path.basename(p)}"); return []
    return json.load(open(p))
teams, leagues, missing = load("teams"), load("leagues"), load("missing-venues")
venues = json.load(open(os.path.join(ROOT, "Witness/Resources/Catalog/venues.json")))
venues = venues if isinstance(venues, list) else venues["venues"]
venue_ids = {v["id"] for v in venues} | {v.get("id") for v in missing}
existing = json.load(open(os.path.join(ROOT, "Witness/Resources/Catalog/teams.json")))
existing = existing if isinstance(existing, list) else existing.get("teams", existing)
existing_ids = {t["id"] for t in existing}
SPORTS = {"baseball", "football", "basketball", "hockey", "soccer", "motorsport", "handball"}
hexre = re.compile(r"^[0-9A-Fa-f]{6}$")
def lum(h):
    c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def contrast_on_ink(h):
    ink = lum("0B0C10"); l = lum(h)
    return (max(l, ink) + 0.05) / (min(l, ink) + 0.05)
seen, per_league_abbr = set(), {}
for t in teams:
    tid = t.get("id", "?")
    if tid in seen: errors.append(f"duplicate team id {tid}")
    seen.add(tid)
    for f in ("id", "kind", "sport", "league", "leagueKey", "country", "countryCode", "abbreviation", "locationName", "teamName", "monogram", "colors", "homeVenueId", "tier"):
        if t.get(f) in (None, ""): errors.append(f"{tid}: missing {f}")
    if t.get("sport") not in SPORTS: errors.append(f"{tid}: bad sport {t.get('sport')}")
    if t.get("kind") not in ("club", "national"): errors.append(f"{tid}: bad kind")
    ab = t.get("abbreviation", "")
    if not re.fullmatch(r"[A-Za-z0-9]{2,4}", ab): errors.append(f"{tid}: abbreviation '{ab}' must be 2-4 letters/digits")
    k = (t.get("leagueKey"), ab.upper())
    if k in per_league_abbr and per_league_abbr[k] != tid: errors.append(f"{tid}: abbreviation {ab} already used by {per_league_abbr[k]} in {t.get('leagueKey')}")
    per_league_abbr[k] = tid
    cols = t.get("colors") or {}
    for c in ("primary", "secondary", "accent"):
        if not hexre.match(str(cols.get(c, ""))): errors.append(f"{tid}: colors.{c} is not 6-digit hex")
    if hexre.match(str(cols.get("accent", ""))) and contrast_on_ink(cols["accent"]) < 3.0:
        errors.append(f"{tid}: accent {cols['accent']} too dark on the app background (contrast {contrast_on_ink(cols['accent']):.1f})")
    if t.get("homeVenueId") not in venue_ids: errors.append(f"{tid}: homeVenueId {t.get('homeVenueId')} not in venues.json or missing-venues")
    if tid in existing_ids: pass
team_ids = seen
for L in leagues:
    key = L.get("key", "?")
    for f in ("key", "name", "sport", "country", "countryCode", "tier", "teamCount", "teamIds", "passport"):
        if L.get(f) in (None, ""): errors.append(f"league {key}: missing {f}")
    for tid in L.get("teamIds", []):
        if tid not in team_ids: errors.append(f"league {key}: unknown team {tid}")
    for vid in (L.get("passport") or {}).get("venueIds", []):
        if vid not in venue_ids: errors.append(f"league {key}: passport venue {vid} unknown")
    if L.get("teamCount") and len(L.get("teamIds", [])) != L["teamCount"]:
        errors.append(f"league {key}: teamCount {L['teamCount']} but {len(L.get('teamIds', []))} teamIds")
league_keys = {L.get("key") for L in leagues}
for t in teams:
    if t.get("leagueKey") not in league_keys: errors.append(f"{t.get('id')}: league {t.get('leagueKey')} has no league record")
for v in missing:
    for f in ("id", "name", "city", "country", "countryCode", "latitude", "longitude", "sports", "timeZone"):
        if v.get(f) in (None, ""): errors.append(f"missing-venue {v.get('id')}: missing {f}")
print(f"{len(teams)} teams, {len(leagues)} leagues, {len(missing)} missing venues, {len(errors)} errors")
for e in errors[:60]: print(" -", e)
sys.exit(1 if errors else 0)
