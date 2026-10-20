#!/usr/bin/env python3
"""Builds the tournament layer of the catalog: every national team and continental club of the major tournaments, and the
competitions themselves.

  python3 Tools/teams/tournaments/build_tournaments.py && python3 Tools/teams/build_catalog.py

Writes (all generated; edit the tables beside this file, not the output):
  Tools/teams/tournaments-teams.json            research-format teams (Tools/teams/SPEC.md), read by build_catalog.py and build_packs.py
  Tools/teams/tournaments-leagues.json          one league record per competition and per national-team group
  Tools/teams/tournaments-missing-venues.json   arenas the tournaments and clubs need that venues.json lacks (and league patches)
  Witness/Resources/Catalog/competitions.json   the competitions (id, aliases, governing body, cadence, next edition, feed, teamIds)
Inputs: countries.py, sets.py, clubs-basketball.json, legacy-nationals.json (the 64 national teams that shipped before, kept
verbatim), espn-soccer.json (fetch_espn.py), competitions.py.
"""
import json, os, re, sys, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
CAT = os.path.join(ROOT, "Witness/Resources/Catalog")
TEAMS_DIR = os.path.join(ROOT, "Tools/teams")
from countries import COUNTRIES, accent_for
import sets as S
import competitions as K


def load(p):
    return json.load(open(p))


def norm(s):
    return re.sub(r"[^a-z0-9 ]", " ", unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower())


legacy = {t["id"]: t for t in load(f"{HERE}/legacy-nationals.json")}
# What the catalog held before this layer: the output of an earlier run (build_catalog.py puts it into teams-more.json) is not "existing".
_mine = set()
if os.path.exists(f"{TEAMS_DIR}/tournaments-teams.json"):
    _mine = {t["id"] for t in load(f"{TEAMS_DIR}/tournaments-teams.json")}
_mine |= set(legacy)
catalog_teams = {}
for f in ("teams", "teams-more", "national-teams"):
    for t in load(f"{CAT}/{f}.json"):
        if t["id"] not in _mine:
            catalog_teams.setdefault(t["id"], t)
venues = {v["id"]: v for v in load(f"{CAT}/venues.json")}

teams, extra_venues = [], []


def colors_for(code, sport, kind_prefix):
    for t in legacy.values():
        if t["sport"] == sport and t["abbreviation"] == code:
            return t["colors"], t
    c = COUNTRIES[code]
    return {"primary": c["primary"], "secondary": c["secondary"], "accent": accent_for(c["primary"], c["secondary"])}, None


# ---------------------------------------------------------------- national teams (basketball, hockey, handball, baseball)
GROUPS = [
    # id prefix, sport, group league name, leagueKey, codes, "men's"/"women's" noun phrase, sport phrase
    ("fibam", "basketball", "FIBA national teams (men)", "basketball/national", S.MEN_BB, "men's national basketball team"),
    ("fibaw", "basketball", "FIBA national teams (women)", "basketball/national.w", S.WOMEN_BB, "women's national basketball team"),
    ("iihf", "hockey", "IIHF national teams (men)", "hockey/national", S.HK_MEN, "men's national ice hockey team"),
    ("iihfw", "hockey", "IIHF national teams (women)", "hockey/national.w", S.HK_WOMEN, "women's national ice hockey team"),
    ("ehfn", "handball", "Handball national teams (men)", "handball/national", S.HB_MEN, "men's national handball team"),
    ("ehfnw", "handball", "Handball national teams (women)", "handball/national.w", S.HB_WOMEN, "women's national handball team"),
    ("wbsc", "baseball", "WBSC national teams (baseball)", "baseball/national", S.BASEBALL, "national baseball team"),
]
national_ids = {}  # (leagueKey, code) -> id
for prefix, sport, league, key, codes, phrase in GROUPS:
    for code in dict.fromkeys(codes):
        c = COUNTRIES[code]
        tid = f"{prefix}-{code.lower()}"
        national_ids[(key, code)] = tid
        if tid in legacy:
            t = dict(legacy[tid])
            t["gender"] = "men"
            teams.append(t)
            continue
        men_twin = legacy.get({"fibaw": "fibam", "iihfw": "iihf", "ehfnw": "ehfn"}.get(prefix, "") + "-" + code.lower())
        name = men_twin["locationName"] if men_twin else c["name"]
        cols, _ = colors_for(code, sport, prefix)
        teams.append({
            "id": tid, "kind": "national", "sport": sport, "league": league, "leagueKey": key, "country": c["name"],
            "countryCode": c["iso"], "abbreviation": code, "locationName": name, "teamName": f"{name} {phrase}", "monogram": code,
            "colors": cols, "externalIds": {}, "founded": None, "tier": 1,
            "gender": "women" if prefix.endswith("w") else "men"})

# ---------------------------------------------------------------- basketball clubs outside the catalog
CLUB_KEY = {"EC": "basketball/eurocup", "CL": "basketball/fiba.bcl", "EU": "basketball/fiba.europecup", "BAL": "basketball/fiba.bal",
            "IC": "basketball/fiba.intercontinental"}
CLUB_LEAGUE = {"basketball/eurocup": "EuroCup", "basketball/fiba.bcl": "Basketball Champions League",
               "basketball/fiba.europecup": "FIBA Europe Cup", "basketball/fiba.bal": "Basketball Africa League",
               "basketball/fiba.intercontinental": "FIBA Intercontinental Cup"}
club_by_wiki = {}
for c in load(f"{HERE}/clubs-basketball.json"):
    key = c["leagueKey"]
    league = c["league"]
    if not key:
        key = next(CLUB_KEY[x] for x in ("BAL", "CL", "EU", "EC", "IC") if x in c["competitions"])
        league = CLUB_LEAGUE[key]
    home = None
    if c["arena"]:
        a = c["arena"]
        vid = "bbc-" + re.sub(r"[^a-z0-9]+", "-", norm(a["name"])).strip("-") + "-" + c["countryCode"].lower()
        home = vid
        if vid not in {v["id"] for v in extra_venues}:
            extra_venues.append({"id": vid, "name": a["name"], "aliases": [], "city": c["locationName"], "region": None,
                                 "country": c["country"], "countryCode": c["countryCode"], "latitude": a["lat"], "longitude": a["lon"],
                                 "sports": ["basketball"], "leagues": [], "homeTeams": [c["teamName"]],
                                 "timeZone": K.TZ.get(c["countryCode"], "UTC"), "capacity": None, "opened": None})
    t = {"id": c["id"], "kind": "club", "sport": "basketball", "league": league, "leagueKey": key, "country": c["country"],
         "countryCode": c["countryCode"], "abbreviation": c["abbreviation"], "locationName": c["locationName"],
         "teamName": c["teamName"], "monogram": c["locationName"][0].upper(), "colors": c["colors"], "externalIds": {},
         "founded": c["founded"], "tier": 1, "gender": "men"}
    if home:
        t["homeVenueId"] = home
    teams.append(t)
    club_by_wiki[c["wiki"]] = c["id"]
    club_by_wiki["comps:" + c["id"]] = c["competitions"]

# ---------------------------------------------------------------- soccer: women's national teams, Guam, continental clubs
espn = load(f"{HERE}/espn-soccer.json")
men_nat = {t["externalIds"]["espn"]: t["id"] for t in catalog_teams.values() if t["id"].startswith("nat-")}
GUAM = {"id": "nat-10529", "sport": "soccer", "league": "National teams", "abbreviation": "GUM", "locationName": "Guam", "teamName": "Guam",
        "monogram": "GU", "colors": {"primary": "0054A6", "secondary": "D6001C", "accent": "D6001C"},
        "externalIds": {"espn": "10529", "espnLeague": "soccer/fifa.world"}, "leagueKey": "soccer/fifa.world"}
nat_path = f"{CAT}/national-teams.json"
nat_list = load(nat_path)
if not any(t["id"] == GUAM["id"] for t in nat_list):
    nat_list.append(GUAM)
    nat_list.sort(key=lambda t: t["locationName"])
    json.dump(nat_list, open(nat_path, "w"), ensure_ascii=False, indent=1)
men_nat["10529"] = "nat-10529"

women = {}
for lg, d in espn["women"].items():
    for t in d["teams"]:
        if "TBD" in (t["abbreviation"] or "") or not t["location"]:
            continue
        t = dict(t, location=t["location"].strip(), name=(t["name"] or "").strip())
        women.setdefault(t["id"], dict(t, comps=[]))["comps"].append(lg)
used_abbr = {}
for eid, t in sorted(women.items(), key=lambda kv: kv[1]["location"]):
    ab = (t["abbreviation"] or t["location"][:3]).upper()[:4]
    if ab in used_abbr:
        ab = ab[:3] + "W"
    used_abbr[ab] = eid
    p = (t["color"] or "3A4150").upper()
    s2 = (t["alt"] or "FFFFFF").upper()
    teams.append({"id": f"natw-{eid}", "kind": "national", "sport": "soccer", "league": "Women's national teams",
                  "leagueKey": "soccer/fifa.wwc", "country": t["location"], "countryCode": "XX", "abbreviation": ab,
                  "locationName": t["location"], "teamName": t["name"] or t["location"], "monogram": ab[:2],
                  "colors": {"primary": p, "secondary": s2, "accent": accent_for(p, s2)},
                  "externalIds": {"espn": eid, "espnLeague": "soccer/fifa.wwc"}, "founded": None, "tier": 1, "gender": "women"})
women_ids = {eid: f"natw-{eid}" for eid in women}

soccer_names = [(t["id"], set(norm(t["locationName"] + " " + t["teamName"]).split())) for t in catalog_teams.values() if t["sport"] == "soccer"]
STOPW = {"fc", "sc", "cf", "ac", "as", "club", "de", "al", "the", "afc", "sk", "fk"}
CLUB_SKIP = {"LAFC", "Inter Miami CF", "Internazionale", "TBD Home", "TBD Away"}
club_comp_ids = {}   # espn league -> [catalog ids]
UNMATCHED = {}
created_espn = {}
club_abbr = set()
# same short name, different club (ESPN id is the only safe match for these)
NO_NAME_MATCH = {"Red Star Belgrade", "Club Deportivo Olimpia", "Auckland City", "Olimpia"}
CREATE = {"afc.champions", "afc.cup", "caf.champions", "caf.confed", "concacaf.champions", "uefa.wchampions"}
REGION = {"afc": "Asia", "caf": "Africa", "concacaf": "North America", "uefa": "Europe"}
for lg, d in espn["clubs"].items():
    ids = []
    for t in d["teams"]:
        if t["location"] in CLUB_SKIP or (t["abbreviation"] or "").startswith("TBD"):
            continue
        eid = t["id"]
        existing = created_espn.get(eid) or next((tid for tid, c in catalog_teams.items() if c["sport"] == "soccer" and (c.get("externalIds") or {}).get("espn") == eid), None)
        if not existing and lg != "uefa.wchampions" and (t["displayName"] or "") not in NO_NAME_MATCH:
            tok = {w for w in norm(t["displayName"] or t["location"]).split() if w not in STOPW}
            for tid, tt in soccer_names:
                tt2 = {w for w in tt if w not in STOPW}
                if tok and tt2 and (tok <= tt2 or tt2 <= tok) and len(tok & tt2) >= 1 and len(tok) <= 3:
                    existing = tid
                    break
        if existing:
            ids.append(existing)
            continue
        if lg not in CREATE:
            UNMATCHED.setdefault(lg, []).append(t["displayName"] or t["location"])
            continue
        tid = f"scl-{eid}"
        if not any(x["id"] == tid for x in teams):
            ab = re.sub(r"[^A-Z0-9]", "", (t["abbreviation"] or t["location"][:3]).upper())[:4] or "CLB"
            while (f"soccer/{lg}", ab) in club_abbr:
                ab = ab[:3] + "23456789"[len([1 for k in club_abbr if k[0] == f"soccer/{lg}" and k[1][:3] == ab[:3]]) % 8]
            club_abbr.add((f"soccer/{lg}", ab))
            p = (t["color"] or "3A4150").upper()
            s2 = (t["alt"] or "FFFFFF").upper()
            key = "soccer/" + lg
            teams.append({"id": tid, "kind": "club", "sport": "soccer", "league": d["name"], "leagueKey": key, "country": REGION[lg.split(".")[0]], "countryCode": "XX",
                          "abbreviation": ab, "locationName": t["location"], "teamName": t["displayName"] or t["location"],
                          "monogram": t["location"][:2].upper(), "colors": {"primary": p, "secondary": s2, "accent": accent_for(p, s2)},
                          "externalIds": {"espn": eid, "espnLeague": key}, "founded": None, "tier": 1, "gender": "women" if lg == "uefa.wchampions" else "men"})
        created_espn[eid] = tid
        ids.append(tid)
    club_comp_ids[lg] = ids

# ---------------------------------------------------------------- competitions
EXISTING_BB = {  # existing catalog clubs by Wikipedia title (membership only)
    "KK Budućnost": "aba-bud", "Skyliners Frankfurt": "eurbb-ger-fra", "JL Bourg Basket": "lnb-bou", "Bahçeşehir Koleji S.K.": "eurbb-tur-bah",
    "Reyer Venezia": "lba-ven", "PAOK BC": "gbl-paok", "Türk Telekom B.K.": "bsl-ttk", "KK Cedevita Olimpija": "aba-ced", "Aris B.C.": "gbl-aris",
    "Hapoel Jerusalem B.C.": "bsl-il-hjm", "ratiopharm Ulm": "bbl-ulm", "Aquila Basket Trento": "lba-tre", "BC Neptūnas": "lkl-nep",
    "CB Canarias": "acb-ten", "Niners Chemnitz": "eurbb-ger-che", "Le Mans Sarthe Basket": "lnb-msb", "BC Lietkabelis": "lkl-lie",
    "London Lions (basketball)": "eurbb-gbr-lon", "BC Šiauliai": "eurbb-ltu-sia", "Napoli Basket (2016)": "eurbb-ita-nap",
    "Rostock Seawolves": "eurbb-ger-ros", "Śląsk Wrocław (basketball)": "eurbb-pol-wro", "Rīgas Zeļļi": "eurbb-lva-rig", "Tofaş S.K.": "bsl-tof",
    "Joventut Badalona": "acb-jov", "Trabzonspor B.K.": "eurbb-tur-trb", "UCAM Murcia CB": "eurbb-esp-mur", "Bilbao Basket": "acb-bil",
    "Baloncesto Málaga": "acb-uni", "Antwerp Giants": "eurbb-bel-ant", "Nanterre 92": "eurbb-fra-nan", "Hapoel Holon B.C.": "bsl-il-hho",
    "KK Igokea": "eurbb-aba-igo", "Cholet Basket": "lnb-cho", "KK Cibona": "aba-cib", "SIG Strasbourg": "lnb-sig",
    "Pallacanestro Reggiana": "lba-reg", "Falco KC Szombathely": "eurbb-hun-fal", "Alba Berlin": "bbl-alb", "Bamberg Baskets": "bbl-bam",
    "BC Juventus": "eurbb-ltu-juv", "FC Porto (basketball)": "eurbb-por-fcp", "Telekom Baskets Bonn": "bbl-bon", "BC Rytas": "lkl-ryt",
    "Würzburg Baskets": "bbl-wur", "BK VEF Rīga": "eurbb-lva-vef", "SC Rasta Vechta": "eurbb-ger-vec", "Landstede Hammers": "eurbb-ned-rot",
    "AEK Larnaca B.C.": "eurbb-cyp-aek", "CSM Oradea (men's basketball)": "eurbb-rou-csm", "CB Breogán": "eurbb-esp-bre",
    "Manchester Basketball": "eurbb-gbr-man", "Zastal Zielona Góra": "eurbb-pol-zgo", "Wilki Morskie Szczecin": "eurbb-pol-szc",
    "Gladiators Trier": "eurbb-ger-tri", "Sporting CP (basketball)": "eurbb-por-spo", "KK Split": "aba-spl", "Bàsquet Girona": "acb-gir",
    "University of Tartu men's basketball team": "eurbb-est-tar", "Valmiera Glass Via (basketball)": "eurbb-lva-val", "BC Pärnu": "eurbb-est-par"}
EC_WIKI = ["KK Budućnost", "Skyliners Frankfurt", "JL Bourg Basket", "Bahçeşehir Koleji S.K.", "Reyer Venezia", "PAOK BC", "Türk Telekom B.K.",
           "KK Cedevita Olimpija", "Aris B.C.", "Hapoel Jerusalem B.C.", "ratiopharm Ulm", "Aquila Basket Trento", "BC Neptūnas", "CB Canarias",
           "Niners Chemnitz", "Le Mans Sarthe Basket", "BC Lietkabelis", "London Lions (basketball)", "BC Šiauliai", "Napoli Basket (2016)",
           "Rostock Seawolves", "Śląsk Wrocław (basketball)", "Rīgas Zeļļi", "Tofaş S.K."]
CL_WIKI = ["Joventut Badalona", "Trabzonspor B.K.", "UCAM Murcia CB", "Bilbao Basket", "Baloncesto Málaga", "Antwerp Giants", "Nanterre 92",
           "Hapoel Holon B.C.", "KK Igokea", "Cholet Basket", "KK Cibona", "SIG Strasbourg", "Pallacanestro Reggiana", "Falco KC Szombathely",
           "Alba Berlin", "Bamberg Baskets", "BC Juventus", "FC Porto (basketball)", "Telekom Baskets Bonn", "BC Rytas", "Würzburg Baskets",
           "BK VEF Rīga", "SC Rasta Vechta", "Landstede Hammers", "AEK Larnaca B.C.", "CSM Oradea (men's basketball)", "CB Breogán", "Manchester Basketball"]
EU_WIKI = ["Zastal Zielona Góra", "Wilki Morskie Szczecin", "Gladiators Trier", "Sporting CP (basketball)", "KK Split", "Bàsquet Girona",
           "University of Tartu men's basketball team", "Valmiera Glass Via (basketball)", "BC Pärnu", "Würzburg Baskets", "SC Rasta Vechta",
           "Landstede Hammers", "AEK Larnaca B.C.", "CSM Oradea (men's basketball)", "CB Breogán", "Manchester Basketball", "BC Juventus"]
for w in EC_WIKI + CL_WIKI + EU_WIKI:
    club_by_wiki.setdefault(w, EXISTING_BB[w])
    assert club_by_wiki[w] in catalog_teams, (w, club_by_wiki[w])


def clubs_in(comp):
    out = [tid for wiki, tid in club_by_wiki.items() if not wiki.startswith("comps:") and comp in club_by_wiki.get("comps:" + tid, [])]
    base = {"EC": EC_WIKI, "CL": CL_WIKI, "EU": EU_WIKI}.get(comp, [])
    out += [club_by_wiki[w] for w in base]
    return list(dict.fromkeys(out))


def codes_to_ids(key, codes):
    return [national_ids[(key, c)] for c in dict.fromkeys(codes)]


def zone_codes(codes, zones):
    return [c for c in codes if COUNTRIES[c]["zone"] in zones]


def men_nat_ids(lg):
    return [men_nat[t["id"]] for t in espn["men"][lg]["teams"] if t["id"] in men_nat]


def women_nat_ids(lg):
    return [women_ids[t["id"]] for t in espn["women"][lg]["teams"] if t["id"] in women_ids]


def match_names(sport, names):
    """Catalog teams of a sport by name (every word of the short name found in the team's names); (ids, unmatched)."""
    ids, miss = [], []
    pool = [(t["id"], set(norm(t["locationName"] + " " + t["teamName"]).split())) for t in catalog_teams.values() if t["sport"] == sport]
    for n in names:
        w = {x for x in norm(n).split() if x not in {"hc", "ec", "hk", "ik", "sc", "ehc", "the"}}
        hit = [tid for tid, tt in pool if w and w <= tt]
        if len(hit) == 1:
            ids.append(hit[0])
        else:
            miss.append(n)
    return ids, miss


CHL = ["Frölunda", "Skellefteå", "Växjö Lakers", "Rögle", "Fribourg-Gottéron", "Davos", "Genève-Servette", "Tappara", "KooKoo", "SaiPa",
       "Dynamo Pardubice", "Plzeň", "Bílí Tygři Liberec", "Eisbären Berlin", "Kölner Haie", "Adler Mannheim", "Graz 99ers", "KAC",
       "Red Bull Salzburg", "Storhamar", "Bordeaux", "Herning", "Tychy", "Nitra"]
chl_ids, chl_missing = match_names("hockey", CHL)
print("CHL unmatched:", chl_missing)

ctx = {
    "chl": chl_ids, "chl_missing": chl_missing,
    "bb_men": lambda codes: codes_to_ids("basketball/national", codes), "bb_women": lambda codes: codes_to_ids("basketball/national.w", codes),
    "hk_men": lambda codes: codes_to_ids("hockey/national", codes), "hk_women": lambda codes: codes_to_ids("hockey/national.w", codes),
    "hb_men": lambda codes: codes_to_ids("handball/national", codes), "hb_women": lambda codes: codes_to_ids("handball/national.w", codes),
    "bsb": lambda codes: codes_to_ids("baseball/national", codes),
    "zone": zone_codes, "men_nat": men_nat_ids, "women_nat": women_nat_ids, "clubs_in": clubs_in, "club_comp": lambda lg: club_comp_ids[lg],
    "S": S, "catalog": catalog_teams, "teams": teams,
}
S.zone = zone_codes
competitions = K.build(ctx)

# ESPN national-team leagues the lookup always asked about that no tournament table lists (friendlies, and the African and
# CONCACAF Gold Cup qualifying leagues): men's soccer sides with the same ESPN ids as the World Cup. Their teams are those of the
# tournament they feed (friendlies: every men's national side in the catalog).
_by_id = {c["id"]: c for c in competitions}
_men_all = sorted(t["id"] for t in json.load(open(f"{CAT}/national-teams.json")))
for _id, _name, _body, _teams, _alias in [
        ("soccer/fifa.friendly", "International friendlies", "FIFA", _men_all, ["Friendlies", "Friendly"]),
        ("soccer/concacaf.gold_qual", "CONCACAF Gold Cup qualifying", "CONCACAF", _by_id["soccer/concacaf.gold"]["teamIds"], []),
        ("soccer/caf.nations_qual", "Africa Cup of Nations qualifying", "CAF", _by_id["soccer/caf.nations"]["teamIds"], ["AFCON qualifiers"])]:
    competitions.append(K.comp(_id, _name, "soccer", "men", "national", "world" if _body == "FIFA" else "continental", _body,
                               "ongoing" if _body == "FIFA" else "every 2 years", feed={"espn": _id, "pack": None}, aliases=_alias))
    competitions[-1]["teamIds"] = list(_teams)
# "national": the competition is between countries, so its sides are one team per country, merged across competitions by the app.
for _c in competitions:
    _c["national"] = _c["kind"] == "national"

# ---------------------------------------------------------------- venues the tournaments need that the catalog lacks (+ league patches)
for v in K.VENUES:
    if v["id"] in venues:
        # an existing ground: the record only carries what to add (leagues, aliases, sports)
        extra_venues.append(v)
    elif not any(x["id"] == v["id"] for x in extra_venues):
        extra_venues.append(v)

for vid, (sports, leagues) in K.ENRICH.items():
    v = venues[vid]
    extra_venues.append({"id": vid, "name": v["name"], "aliases": [], "city": v["city"], "region": v.get("region"), "country": v["country"],
                         "countryCode": v["countryCode"], "latitude": v["latitude"], "longitude": v["longitude"], "sports": sports or v["sports"],
                         "leagues": leagues, "homeTeams": [], "timeZone": v["timeZone"], "capacity": None, "opened": None})

# Grounds of the national-team windows still to come (games from today on in the FIBA / IIHF / IHF schedule files): exact coordinates only.
SCHED = os.path.join(ROOT, "Tools/schedules/sched-tournaments-other")
if os.path.isdir(SCHED):
    mv = {v["id"]: v for v in load(f"{SCHED}/missing-venues.json")}
    seen = {(x["league"], str(x["sourceVenueId"])): x for x in load(f"{SCHED}/venues-seen.json")}
    import glob
    upcoming = {}
    for folder in glob.glob(f"{SCHED}/basketball-fiba.*q*") + glob.glob(f"{SCHED}/basketball-fiba.*.w") + glob.glob(f"{SCHED}/handball-*") + glob.glob(f"{SCHED}/hockey-iihf.*"):
        for f in glob.glob(folder + "/*.json"):
            j = load(f)
            for g in j["games"]:
                if g[1] >= "2026-10-20" and g[6]:
                    upcoming.setdefault((j["league"], str(g[6])), set()).add(j["league"])
    added = 0
    for (lg, sid), leagues in upcoming.items():
        sv = seen.get((lg, sid))
        if not sv or sv.get("catalogVenueId") or sv.get("approx") or sv.get("latitude") is None:
            continue
        rec = next((m for m in mv.values() if abs(m["latitude"] - sv["latitude"]) < 1e-5 and abs(m["longitude"] - sv["longitude"]) < 1e-5 and m["name"] == sv["name"]), None)
        if not rec or any(x["id"] == rec["id"] for x in extra_venues):
            continue
        rec = dict(rec)
        rec["leagues"] = sorted(set(rec.get("leagues") or []) | leagues)
        rec["sports"] = [x for x in rec["sports"] if x in ("basketball", "hockey", "handball")] or [lg.split("/")[0]]
        extra_venues.append(rec)
        added += 1
    print("upcoming-window venues added:", added)

# ---------------------------------------------------------------- write
all_ids = {t["id"] for t in teams} | set(catalog_teams)
for c in competitions:
    c["teamIds"] = list(dict.fromkeys(c["teamIds"]))
    missing = [i for i in c["teamIds"] if i not in all_ids]
    assert not missing, (c["id"], missing)
    c["teamCount"] = len(c["teamIds"])

research_leagues = []
for prefix, sport, league, key, codes, phrase in GROUPS:
    research_leagues.append({"key": key, "name": league, "sport": sport, "country": "International", "countryCode": "XX", "tier": 1,
                             "teamCount": len(set(codes)), "season": "Year-round", "espnPath": None,
                             "teamIds": codes_to_ids(key, codes), "passport": {"label": league, "venueIds": []}})
research_leagues.append({"key": "soccer/fifa.wwc", "name": "Women's national teams", "sport": "soccer", "country": "International", "countryCode": "XX",
                         "tier": 1, "teamCount": len(women_ids), "season": "Year-round", "espnPath": "soccer/fifa.wwc",
                         "teamIds": sorted(women_ids.values()), "passport": {"label": "Women's national teams", "venueIds": []}})
for c in competitions:
    if c["id"] in {l["key"] for l in research_leagues}:
        continue
    research_leagues.append({"key": c["id"], "name": c["name"], "sport": c["sport"], "country": "International", "countryCode": "XX", "tier": 1,
                             "teamCount": c["teamCount"], "season": c["cadence"], "espnPath": (c["feed"] or {}).get("espn"),
                             "teamIds": c["teamIds"], "passport": {"label": c["name"], "venueIds": []}})
# club leagues the new clubs live in that no other file defines (national groups above already exist)
have_keys = {l["key"] for l in research_leagues}

json.dump(teams, open(f"{TEAMS_DIR}/tournaments-teams.json", "w"), ensure_ascii=False, indent=1)
json.dump(research_leagues, open(f"{TEAMS_DIR}/tournaments-leagues.json", "w"), ensure_ascii=False, indent=1)
json.dump(extra_venues, open(f"{TEAMS_DIR}/tournaments-missing-venues.json", "w"), ensure_ascii=False, indent=1)
for c in competitions:
    lg = c["id"].split("/", 1)[1]
    if c["sport"] == "soccer" and UNMATCHED.get(lg):
        c["unmatchedClubs"] = UNMATCHED[lg]
json.dump(competitions, open(f"{CAT}/competitions.json", "w"), ensure_ascii=False, indent=1)
print({k: v for k, v in UNMATCHED.items()})
print(f"{len(teams)} teams, {len(research_leagues)} leagues, {len(extra_venues)} venues, {len(competitions)} competitions")
