#!/usr/bin/env python3
"""Builds the downloadable data packs and manifest from the research data in Tools/.

  python3 Tools/packs/build_packs.py [--out dist/packs] [--version-note "text"]

Inputs (all under Tools/): teams/*-teams.json, teams/*-leagues.json, teams/*-missing-venues.json, countries/*.json,
schedules/<scope>/<leagueSlug>/<season>[-tag].json, schedules/<scope>/{venues-seen,missing-venues}.json.
The bundled app catalog (Witness/Resources/Catalog) wins on every id and every same-place venue.

Output (immutable files named by content hash, so a CDN can cache them forever; only manifest.json changes):
  <out>/manifest.json
  <out>/catalog/teams.<sha8>.json, venues, leagues, countries, venue-map
  <out>/schedule/<leagueSlug>/<season>.<sha8>.json
manifest.json is {"body": "<manifest JSON as a string>", "signature": "<base64 Ed25519 over the body's UTF-8 bytes>"}; it is signed
when PACKS_SIGNING_KEY (base64 32-byte Ed25519 seed) is set. The body lists every pack with its sha256 and size.
"""
import argparse, base64, glob, hashlib, json, math, os, re, sys, unicodedata
from datetime import datetime, timezone

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(TOOLS)
CATALOG = os.path.join(REPO, "Witness", "Resources", "Catalog")
SCHEMA = 1

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
    if meters(a, b) > 300:
        return False
    na = tokens(a["name"]).union(*[tokens(x) for x in a.get("aliases") or []])
    nb = tokens(b["name"]).union(*[tokens(x) for x in b.get("aliases") or []])
    return bool(na & nb) or meters(a, b) < 120

class VenueIndex:
    """Venues in ~1 km cells so a same-place check looks at a handful, not thousands."""
    CELL = 0.01
    def __init__(self):
        self.cells, self.by_id = {}, {}
    def _key(self, lat, lon):
        return (math.floor(lat / self.CELL), math.floor(lon / self.CELL))
    def add(self, v):
        self.by_id[v["id"]] = v
        self.cells.setdefault(self._key(v["latitude"], v["longitude"]), []).append(v)
    def match(self, v):
        if v["id"] in self.by_id:
            return self.by_id[v["id"]]
        ci, cj = self._key(v["latitude"], v["longitude"])
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                for x in self.cells.get((ci + di, cj + dj), []):
                    if same_place(x, v):
                        return x
        return None

def load_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception as e:
        print(f"  skip {os.path.relpath(path, REPO)}: {e}", file=sys.stderr)
        return default

def compact(obj):
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode()

# Sports the app's `Sport` enum can decode today; others stay in the research files until the app learns them.
APP_SPORTS = {"baseball", "football", "basketball", "hockey", "soccer", "motorsport", "handball"}

VENUE_FIELDS = ("id", "name", "aliases", "city", "region", "country", "countryCode", "latitude", "longitude",
                "sports", "leagues", "homeTeams", "timeZone", "capacity", "opened")

def build(out_dir, note):
    packs = []

    def write(pack_id, kind, payload, **extra):
        data = payload if isinstance(payload, bytes) else compact(payload)
        sha = hashlib.sha256(data).hexdigest()
        rel = f"{pack_id}.{sha[:8]}.json"
        path = os.path.join(out_dir, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if not os.path.exists(path):
            with open(path, "wb") as f:
                f.write(data)
        packs.append({"id": pack_id, "kind": kind, "version": sha[:8], "path": rel, "bytes": len(data), "sha256": sha, **extra})

    # ---- venues: bundled catalog first, then every research venue that is not already there
    venues_index = VenueIndex()
    for v in load_json(os.path.join(CATALOG, "venues.json"), []):
        venues_index.add(v)
    bundled_venue_ids = set(venues_index.by_id)
    extra_venues, remap = [], {}
    files = sorted(glob.glob(os.path.join(TOOLS, "teams", "*-missing-venues.json"))
                   + glob.glob(os.path.join(TOOLS, "schedules", "*", "missing-venues.json")))
    for path in files:
        for raw in load_json(path, []):
            if raw.get("latitude") is None or raw.get("longitude") is None:
                continue
            v = {k: raw.get(k) for k in VENUE_FIELDS}
            for k in ("aliases", "leagues", "homeTeams", "sports"):
                v[k] = v.get(k) or []
            v["sports"] = [x for x in v["sports"] if x in APP_SPORTS]
            match = venues_index.match(v)
            if match:
                remap[v["id"]] = match["id"]
                if match["id"] not in bundled_venue_ids:   # a research venue seen twice: union its facts
                    for k in ("sports", "leagues", "homeTeams", "aliases"):
                        match[k] = list(dict.fromkeys((match.get(k) or []) + v[k]))
                    if v["name"] != match["name"] and v["name"] not in match["aliases"]:
                        match["aliases"].append(v["name"])
                continue
            venues_index.add(v)
            extra_venues.append(v)
    extra_venues.sort(key=lambda v: (v["countryCode"] or "", v["city"] or "", v["name"]))
    write("catalog/venues", "catalog", extra_venues, items=len(extra_venues))

    # ---- teams
    bundled = {t["id"]: t for t in load_json(os.path.join(CATALOG, "teams.json"), [])}
    seen_ids, seen_espn, teams, overlays, leagues = set(bundled), set(), [], [], {}
    overlaid, skipped_sports = set(), {}
    for path in sorted(glob.glob(os.path.join(TOOLS, "teams", "*-teams.json"))):
        for t in load_json(path, []):
            ext = t.get("externalIds") or {}
            if t["id"] in bundled:
                # The bundled team keeps its values; the research record only adds league key, ESPN ids and the venue.
                if t["id"] not in overlaid:
                    overlaid.add(t["id"])
                    overlays.append({"id": t["id"], "leagueKey": t.get("leagueKey"), "country": t.get("country"),
                                     "countryCode": t.get("countryCode"), "homeVenueId": t.get("homeVenueId"),
                                     "externalIds": {"espn": ext.get("espn"), "espnLeague": ext.get("espnLeague") or t.get("leagueKey")}})
                continue
            if t["id"] in seen_ids:
                continue
            key = (ext.get("espnLeague") or t.get("leagueKey"), ext.get("espn"))
            if key[1] and key in seen_espn:
                continue
            if t.get("sport") not in APP_SPORTS:
                skipped_sports[t.get("sport")] = skipped_sports.get(t.get("sport"), 0) + 1
                continue
            seen_ids.add(t["id"])
            if key[1]:
                seen_espn.add(key)
            home = t.get("homeVenueId")
            teams.append({
                "id": t["id"], "sport": t["sport"], "league": t["league"], "abbreviation": t["abbreviation"],
                "locationName": t["locationName"], "teamName": t["teamName"], "monogram": t["monogram"],
                "colors": t["colors"], "leagueKey": t.get("leagueKey"), "kind": t.get("kind"),
                "country": t.get("country"), "countryCode": t.get("countryCode"),
                "homeVenueId": remap.get(home, home), "tier": t.get("tier"), "founded": t.get("founded"),
                "externalIds": {"espn": ext.get("espn"), "espnLeague": ext.get("espnLeague") or t.get("leagueKey"),
                                "theSportsDb": ext.get("theSportsDb"), "mlbStatsApi": ext.get("mlbStatsApi"),
                                "wikidata": ext.get("wikidata")},
            })
    for o in overlays:
        o["homeVenueId"] = remap.get(o["homeVenueId"], o["homeVenueId"])
    write("catalog/teams", "catalog", {"teams": teams, "overlays": overlays}, items=len(teams) + len(overlays))

    for path in sorted(glob.glob(os.path.join(TOOLS, "teams", "*-leagues.json"))):
        for lg in load_json(path, []):
            cur = leagues.get(lg["key"])
            if cur is None:
                leagues[lg["key"]] = lg
            else:
                cur["teamIds"] = list(dict.fromkeys(cur.get("teamIds", []) + lg.get("teamIds", [])))
                vids = cur.setdefault("passport", {}).setdefault("venueIds", [])
                cur["passport"]["venueIds"] = list(dict.fromkeys(vids + (lg.get("passport") or {}).get("venueIds", [])))
    for lg in leagues.values():
        p = lg.get("passport")
        if p:
            p["venueIds"] = list(dict.fromkeys(remap.get(v, v) for v in p.get("venueIds", [])))
        lg["teamCount"] = len(lg.get("teamIds", []))
    write("catalog/leagues", "catalog", sorted(leagues.values(), key=lambda l: l["key"]), items=len(leagues))

    # ---- countries
    countries = {}
    for name in ("countries", "us-states", "canada-provinces"):
        data = load_json(os.path.join(TOOLS, "countries", name + ".json"))
        if data is not None:
            countries[name] = data
    if countries:
        write("catalog/countries", "catalog", countries, items=sum(len(v) for v in countries.values()))

    # ---- schedules and the venue map (source venue id -> app venue id, per league)
    venue_map = {}
    for scope_dir in sorted(glob.glob(os.path.join(TOOLS, "schedules", "*", ""))):
        seen_path = os.path.join(scope_dir, "venues-seen.json")
        for vs in load_json(seen_path, []) if os.path.exists(seen_path) else []:
            target = vs.get("catalogVenueId")
            if not target:
                probe = {"id": "", "name": vs["name"], "aliases": vs.get("aliases") or [],
                         "latitude": vs["latitude"], "longitude": vs["longitude"]}
                m = venues_index.match(probe)
                target = m["id"] if m else None
            if target:
                venue_map.setdefault(vs["league"], {})[str(vs["sourceVenueId"])] = remap.get(target, target)
        for path in sorted(glob.glob(os.path.join(scope_dir, "*", "*.json"))):
            rel = os.path.relpath(path, scope_dir)
            slug, fname = rel.split(os.sep)
            data = load_json(path)
            if not data or "games" not in data:
                continue
            pack_id = f"schedule/{slug}/{fname[:-5]}"
            data.pop("fetched", None)
            write(pack_id, "schedule", data, league=data.get("league"), season=data.get("season"), items=len(data["games"]))
    write("catalog/venue-map", "catalog", venue_map, items=sum(len(v) for v in venue_map.values()))

    packs.sort(key=lambda p: p["id"])
    manifest = {"schema": SCHEMA, "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "minAppVersion": "1.0", "note": note, "packs": packs}
    # The signed text is the body string itself, so the app verifies exactly these bytes and then decodes them.
    body = compact(manifest).decode()
    envelope = {"body": body, "signature": sign(body.encode())}
    manifest["signature"] = envelope["signature"]
    with open(os.path.join(out_dir, "manifest.json"), "wb") as f:
        f.write(json.dumps(envelope, ensure_ascii=False, separators=(",", ":")).encode())
    total = sum(p["bytes"] for p in packs)
    sched = [p for p in packs if p["kind"] == "schedule"]
    if skipped_sports:
        print("  teams left out (the app has no such sport yet):", skipped_sports)
    print(f"{len(packs)} packs ({len(sched)} schedule), {total / 1e6:.1f} MB raw; {len(teams)} new teams, "
          f"{len(extra_venues)} new venues, {len(leagues)} leagues, {sum(len(v) for v in venue_map.values())} venue mappings"
          f"{'' if manifest['signature'] else '; UNSIGNED (set PACKS_SIGNING_KEY)'}")

def sign(body):
    """Ed25519 over the canonical manifest body (schema, minAppVersion, packs), base64. None when no key is configured."""
    seed = os.environ.get("PACKS_SIGNING_KEY")
    if not seed:
        return None
    try:
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    except ImportError:
        print("PACKS_SIGNING_KEY is set but the `cryptography` package is missing", file=sys.stderr)
        sys.exit(1)
    key = Ed25519PrivateKey.from_private_bytes(base64.b64decode(seed))
    return base64.b64encode(key.sign(body)).decode()

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO, "dist", "packs"))
    ap.add_argument("--version-note", default="")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    build(args.out, args.version_note)
