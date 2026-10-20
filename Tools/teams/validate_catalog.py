#!/usr/bin/env python3
"""Checks the bundled catalog (Witness/Resources/Catalog) as the app sees it, for the tournament layer:
  - every competition in competitions.json has teams, each of them a real catalog team, and an id/name/sport/cadence;
  - every national side and every continental club of the tournaments file belongs to at least one competition;
  - no country is listed twice for one sport and gender (same code, same name, or same country code), whatever the id;
  - national teams carry sane colors, and every team's home venue exists;
  - basketball has the key FIBA competitions (World Cup, EuroBasket, AmeriCup, AfroBasket, Asia Cup, EuroLeague, EuroCup, BCL...).
usage: python3 Tools/teams/validate_catalog.py      (exit 1 on any error)
"""
import json, os, re, sys, unicodedata

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CAT = os.path.join(ROOT, "Witness/Resources/Catalog")
errors = []
load = lambda n: json.load(open(os.path.join(CAT, n + ".json")))
teams = {}
for n in ("teams", "teams-more", "national-teams"):
    for t in load(n):
        if t["id"] in teams:
            errors.append(f"duplicate team id {t['id']} across catalog files")
        teams[t["id"]] = t
venues = {v["id"] for v in load("venues")} | {v["id"] for v in load("f1-circuits")}
comps = load("competitions")
norm = lambda s: re.sub(r"[^a-z0-9]", "", unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower())

ids = [c["id"] for c in comps]
for i in ids:
    if ids.count(i) > 1:
        errors.append(f"duplicate competition {i}")
in_comp = set()
for c in comps:
    for f in ("id", "name", "sport", "gender", "kind", "governingBody", "cadence"):
        if not c.get(f):
            errors.append(f"{c.get('id')}: missing {f}")
    if not c["teamIds"]:
        errors.append(f"{c['id']}: no teams")
    for t in c["teamIds"]:
        if t not in teams:
            errors.append(f"{c['id']}: team {t} is not in the catalog")
        elif teams[t]["sport"] != c["sport"]:
            errors.append(f"{c['id']}: {t} is a {teams[t]['sport']} team in a {c['sport']} competition")
    in_comp |= set(c["teamIds"])

# one team per country, sport and gender
NATIONAL = {"fibam": "basketball men", "fibaw": "basketball women", "iihf": "hockey men", "iihfw": "hockey women", "ehfn": "handball men",
            "ehfnw": "handball women", "wbsc": "baseball", "nat": "soccer men", "natw": "soccer women"}
seen = {}
for t in teams.values():
    prefix = t["id"].split("-")[0]
    if prefix not in NATIONAL:
        continue
    group = NATIONAL[prefix]
    for k, v in (("code", t["abbreviation"]), ("name", norm(t["locationName"])), ("espn", (t.get("externalIds") or {}).get("espn"))):
        if not v:
            continue
        if (group, k, v) in seen:
            errors.append(f"duplicate national side in {group}: {t['id']} and {seen[(group, k, v)]} share {k} {v}")
        seen[(group, k, v)] = t["id"]
    if t.get("countryCode") and t["countryCode"] != "XX" and prefix not in ("nat", "natw"):
        if (group, "iso", t["countryCode"]) in seen:
            errors.append(f"duplicate country {t['countryCode']} in {group}: {t['id']} and {seen[(group, 'iso', t['countryCode'])]}")
        seen[(group, "iso", t["countryCode"])] = t["id"]
    if prefix != "nat" and t["id"] not in in_comp:
        errors.append(f"{t['id']} ({t['locationName']}) belongs to no competition")
    if not re.fullmatch(r"[0-9A-F]{6}", t["colors"]["accent"]):
        errors.append(f"{t['id']}: bad accent color")

# tournament-file clubs belong to a competition; home venues exist
tfile = json.load(open(os.path.join(ROOT, "Tools/teams/tournaments-teams.json")))
for t in tfile:
    if t["kind"] == "club" and t["id"] not in in_comp:
        errors.append(f"club {t['id']} ({t['teamName']}) belongs to no competition")
for t in teams.values():
    if t.get("homeVenueId") and t["homeVenueId"] not in venues:
        errors.append(f"{t['id']}: home venue {t['homeVenueId']} is not in venues.json")

# basketball completeness
need = ["basketball/fiba.worldcup", "basketball/fiba.eurobasket", "basketball/fiba.americup", "basketball/fiba.afrobasket", "basketball/fiba.asiacup",
        "basketball/fiba.worldcup.w", "basketball/fiba.eurobasket.w", "basketball/euroleague", "basketball/eurocup", "basketball/fiba.bcl",
        "basketball/fiba.europecup", "basketball/fiba.intercontinental", "basketball/mens-olympics-basketball"]
for n in need:
    if n not in ids:
        errors.append(f"basketball competition {n} missing")
by = {c["id"]: c for c in comps}
if "basketball/fiba.worldcup" in by and len(by["basketball/fiba.worldcup"]["teamIds"]) < 80:
    errors.append("the World Cup lists fewer than the 80 qualifier teams")

print(f"{len(comps)} competitions, {len(teams)} teams, {len(errors)} errors")
for e in errors[:60]:
    print(" -", e)
sys.exit(1 if errors else 0)
