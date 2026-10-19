"""Shared bits for the ESPN schedule fetcher: what is already on disk, the catalog's leagues, and the row format of SPEC.md."""
import glob, json, os, re, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEDULES = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(SCHEDULES))
CATALOG = os.path.join(REPO, "Witness", "Resources", "Catalog")
HELD = ("sofascore", "hockeytech", "fiba")          # sources the pack builder holds back (terms not cleared)
FIRST, LAST = 2006, 2026
OUT_SCOPE = "sched3-espn"


def slug(league):
    return league.replace("/", "-")


def catalog_leagues():
    """ESPN league paths for every team the app knows: {leaguePath: teamCount}."""
    out = {}
    for name in ("teams.json", "teams-more.json", "national-teams.json"):
        for t in json.load(open(os.path.join(CATALOG, name))):
            key = t.get("leagueKey") or (t.get("externalIds") or {}).get("espnLeague")
            if key:
                out[key] = out.get(key, 0) + 1
    return out


def on_disk():
    """{leagueSlug: {season: (gameCount, source)}} over every schedule scope, so only what is missing is fetched."""
    have = {}
    for path in glob.glob(os.path.join(SCHEDULES, "sched*", "*", "[0-9][0-9][0-9][0-9].json")):
        parts = path.split(os.sep)
        sl, season = parts[-2], int(parts[-1][:4])
        try:
            with open(path) as f:
                head = f.read(400)
            m = re.search(r'"source":\s*"([^"]*)"', head)
            source = (m.group(1) if m else "").lower()
            n = os.path.getsize(path) // 60   # a rough game count, enough to judge a replacement
        except OSError:
            continue
        held = source.startswith(HELD)
        have.setdefault(sl, {})
        if not held or season not in have[sl]:
            have[sl][season] = (0 if held else n, source)
    return have


def missing_seasons(league, have, first=FIRST, last=LAST):
    present = {s for s, (n, src) in have.get(slug(league), {}).items() if n > 0 and not src.startswith(HELD)}
    return [s for s in range(first, last + 1) if s not in present]


def country_codes():
    """country name -> ISO code, from the catalog's venues."""
    out = {}
    for v in json.load(open(os.path.join(CATALOG, "venues.json"))):
        if v.get("country") and v.get("countryCode"):
            out.setdefault(v["country"].lower(), v["countryCode"])
    return out


def fold(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


class CatalogVenues:
    """Matches an ESPN venue to a catalog venue by name or alias and city; coordinates then come from the catalog."""
    def __init__(self):
        self.rows = json.load(open(os.path.join(CATALOG, "venues.json")))
        self.by_name = {}
        for v in self.rows:
            for n in [v["name"]] + (v.get("aliases") or []):
                self.by_name.setdefault(fold(n), []).append(v)

    def match(self, name, city, country_code):
        cands = self.by_name.get(fold(name), [])
        if not cands:
            return None
        for v in cands:
            if country_code and v.get("countryCode") != country_code:
                continue
            if city and fold(v.get("city", "")) and fold(city) not in fold(v.get("city", "")) and fold(v.get("city", "")) not in fold(city):
                continue
            return v
        return None
